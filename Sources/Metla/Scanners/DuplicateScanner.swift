import Foundation

/// Finds files with identical content: same size, then same sampled hash, then same full hash.
enum DuplicateScanner {
    private static let maxGroups = 1000
    private static let copyMarkers = [
        " copy", " копия", " copia", " kopie", " copie", " cópia", "副本", "のコピー", " 복사본", " की कॉपी", "نسخة",
        "(1)", "(2)", "(3)", "(4)", "(5)", " 2.", " 3."
    ]

    private struct Candidate: Sendable {
        let file: WalkedFile
        var hash: Data?
    }

    @concurrent
    static func scan(root: URL, env: ScanEnvironment, minSize: Int64, progress: ProgressSink) async -> [ItemGroup] {
        // 1. Collect files and bucket them by exact size.
        let files = await FileWalker.collect(root: root, env: env, options: WalkOptions(), progress: progress) { file in
            file.logicalSize >= minSize && file.logicalSize > 0
        }
        var bySize = Dictionary(grouping: files, by: \.logicalSize)
        if Task.isCancelled { return [] }

        // 2. Drop hard links to the same data and cloud-only files, keep sizes that still repeat.
        var candidates: [WalkedFile] = []
        for (_, files) in bySize where files.count > 1 {
            var seen: Set<FileIdentity> = []
            let unique = files.filter { file in
                guard let identity = FileIdentity(path: file.url.path), !identity.isDataless else { return false }
                return seen.insert(identity).inserted
            }
            if unique.count > 1 {
                candidates += unique
            }
        }
        bySize.removeAll()
        if candidates.isEmpty { return [] }

        // 3. Sampled hash: three small reads per file.
        progress.send(String(localized: "Быстрое сравнение: \(Fmt.files(candidates.count))…"))
        let sampled = await parallelMap(candidates, limit: 8) { file in
            FileHasher.sampleHash(file.url, size: file.logicalSize)
        }
        if Task.isCancelled { return [] }
        let afterSample = regroup(zip(candidates, sampled).compactMap { file, hash in
            hash.flatMap { $0 }.map { Candidate(file: file, hash: $0) }
        })

        // 4. Full hash for files the sample does not cover entirely.
        let needFull = afterSample.filter { $0.file.logicalSize > FileHasher.sampleCoversUpTo }
        let totalBytes = needFull.reduce(Int64(0)) { $0 + $1.file.logicalSize }
        progress.send(String(localized: "Точное сравнение содержимого: \(Fmt.bytes(totalBytes))…"))
        let counter = ProgressCounter(total: needFull.count)
        let full = await parallelMap(needFull, limit: 4) { candidate -> Data? in
            let hash = FileHasher.fullHash(candidate.file.url)
            let done = counter.increment()
            if done % 10 == 0 || done == counter.total {
                progress.send(String(localized: "Точное сравнение содержимого: \(done) из \(counter.total)"))
            }
            return hash
        }
        if Task.isCancelled { return [] }
        let confirmedLarge = regroup(zip(needFull, full).compactMap { candidate, hash in
            hash.flatMap { $0 }.map { Candidate(file: candidate.file, hash: $0) }
        })
        let confirmed = afterSample.filter { $0.file.logicalSize <= FileHasher.sampleCoversUpTo } + confirmedLarge

        // 5. Build groups, biggest savings first.
        var sets: [String: [WalkedFile]] = [:]
        for candidate in confirmed {
            guard let hash = candidate.hash else { continue }
            let key = "\(candidate.file.logicalSize)-\(hash.base64EncodedString())"
            sets[key, default: []].append(candidate.file)
        }
        return sets
            .filter { $0.value.count > 1 }
            .map { key, files in makeGroup(id: key, files: files) }
            .sorted { wasted($0) > wasted($1) }
            .prefix(maxGroups)
            .map { $0 }
    }

    /// Keeps only candidates whose (size, hash) pair occurs more than once.
    private static func regroup(_ candidates: [Candidate]) -> [Candidate] {
        struct Key: Hashable {
            let size: Int64
            let hash: Data
        }
        var counts: [Key: Int] = [:]
        for candidate in candidates {
            if let hash = candidate.hash {
                counts[Key(size: candidate.file.logicalSize, hash: hash), default: 0] += 1
            }
        }
        return candidates.filter { candidate in
            guard let hash = candidate.hash else { return false }
            return counts[Key(size: candidate.file.logicalSize, hash: hash), default: 0] > 1
        }
    }

    private static func makeGroup(id: String, files: [WalkedFile]) -> ItemGroup {
        // The likely original goes first: no "copy" in the name, then the oldest, then the shortest path.
        let ordered = files.sorted { lhs, rhs in
            let lhsCopy = looksLikeCopy(lhs.url), rhsCopy = looksLikeCopy(rhs.url)
            if lhsCopy != rhsCopy { return !lhsCopy }
            let lhsDate = lhs.created ?? .distantFuture, rhsDate = rhs.created ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.url.path.count < rhs.url.path.count
        }
        let items = ordered.enumerated().map { index, file in
            FoundItem(
                url: file.url,
                size: file.allocatedSize,
                date: file.modified,
                note: index == 0 ? String(localized: "Вероятный оригинал") : nil,
                safety: index == 0 ? .safe : .review
            )
        }
        let extra = items.dropFirst().reduce(Int64(0)) { $0 + $1.size }
        return ItemGroup(
            id: id,
            title: ordered[0].url.lastPathComponent,
            subtitle: String(localized: "\(Fmt.copies(files.count)) · лишнее: \(Fmt.bytes(extra))"),
            symbol: "doc.on.doc",
            items: items
        )
    }

    private static func looksLikeCopy(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return copyMarkers.contains { name.contains($0) }
    }

    private static func wasted(_ group: ItemGroup) -> Int64 {
        group.items.dropFirst().reduce(0) { $0 + $1.size }
    }
}
