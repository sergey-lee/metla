import Foundation

enum FileWalker {
    static let developerFolderNames: Set<String> = [
        "node_modules", "Pods", "venv", ".venv", "__pycache__", "site-packages",
        "bower_components", "DerivedData", ".build", ".git", ".gradle", ".dart_tool"
    ]

    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
        .fileSizeKey, .totalFileAllocatedSizeKey,
        .contentAccessDateKey, .contentModificationDateKey, .creationDateKey, .addedToDirectoryDateKey
    ]
    private static let keySet = Set(keys)

    private static let progressStep = 1024

    /// Walks `root` on several threads and returns the files that `keep` accepts.
    /// The top two folder levels are listed first; every folder below them becomes a separate job.
    @concurrent
    static func collect(
        root: URL,
        env: ScanEnvironment,
        options: WalkOptions,
        progress: ProgressSink,
        keep: @escaping @Sendable (WalkedFile) -> Bool
    ) async -> [WalkedFile] {
        let seen = ProgressCounter()
        let report: @Sendable (URL) -> Void = { url in
            let total = seen.add(progressStep)
            let folder = Fmt.tilde(url.deletingLastPathComponent().path)
            progress.send(String(localized: "Просмотрено файлов: \(Fmt.number(total)) — \(folder)"))
        }

        var kept: [WalkedFile] = []
        var subtrees: [URL] = []
        walk(
            root: root, env: env, options: options, splitAtLevel: 2,
            onSubtree: { subtrees.append($0) },
            progress: { _, url in report(url) },
            visit: { if keep($0) { kept.append($0) } }
        )
        if Task.isCancelled { return [] }

        let parts = await parallelMap(subtrees, limit: 6) { subtree -> [WalkedFile] in
            var local: [WalkedFile] = []
            walk(
                root: subtree, env: env, options: options,
                progress: { _, url in report(url) },
                visit: { if keep($0) { local.append($0) } }
            )
            return local
        }
        if Task.isCancelled { return [] }
        return kept + parts.flatMap { $0 ?? [] }
    }

    /// Walks `root` synchronously. Never follows symlinks and never enters the Trash or cloud-synced storage,
    /// where deleting a local file also deletes it from the cloud.
    /// With `splitAtLevel`, folders at that depth are handed to `onSubtree` instead of being entered.
    static func walk(
        root: URL,
        env: ScanEnvironment,
        options: WalkOptions,
        splitAtLevel: Int? = nil,
        onSubtree: (URL) -> Void = { _ in },
        progress: (Int, URL) -> Void,
        visit: (WalkedFile) -> Void
    ) {
        let home = env.home.path
        var skippedPaths: Set<String> = [
            home + "/.Trash",
            home + "/Library/CloudStorage",
            home + "/Library/Mobile Documents"
        ]
        if !options.includeHiddenAndLibrary {
            skippedPaths.insert(home + "/Library")
        }

        var enumerationOptions: FileManager.DirectoryEnumerationOptions = []
        if !options.includeHiddenAndLibrary {
            enumerationOptions.insert(.skipsHiddenFiles)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: enumerationOptions,
            errorHandler: { _, _ in true }
        ) else { return }

        var counter = 0
        while let url = enumerator.nextObject() as? URL {
            counter += 1
            if counter % progressStep == 0 {
                if Task.isCancelled { return }
                progress(counter, url)
            }
            guard let values = try? url.resourceValues(forKeys: keySet) else { continue }
            if values.isSymbolicLink == true { continue }

            if values.isDirectory == true {
                if skippedPaths.contains(url.path) {
                    enumerator.skipDescendants()
                } else if options.skipDeveloperFolders, developerFolderNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                } else if values.isPackage == true {
                    enumerator.skipDescendants()
                    if options.packagesAsItems {
                        let size = DirectorySize.allocated(url)
                        visit(WalkedFile(
                            url: url,
                            logicalSize: size,
                            allocatedSize: size,
                            modified: values.contentModificationDate,
                            created: values.creationDate,
                            lastActivity: latest(values),
                            isPackage: true
                        ))
                    }
                } else if let splitAtLevel, enumerator.level >= splitAtLevel {
                    enumerator.skipDescendants()
                    onSubtree(url)
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            let logical = Int64(values.fileSize ?? 0)
            visit(WalkedFile(
                url: url,
                logicalSize: logical,
                allocatedSize: Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0),
                modified: values.contentModificationDate,
                created: values.creationDate,
                lastActivity: latest(values),
                isPackage: false
            ))
        }
    }

    private static func latest(_ values: URLResourceValues) -> Date? {
        [values.contentAccessDate, values.contentModificationDate, values.creationDate, values.addedToDirectoryDate]
            .compactMap { $0 }
            .max()
    }
}
