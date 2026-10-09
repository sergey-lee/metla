import Foundation

/// Finds Library files that belong to applications no longer present on this Mac.
enum LeftoverScanner {
    private static let ignoredTokens: Set<String> = [
        "app", "mac", "macos", "osx", "desktop", "client", "helper", "launcher", "agent", "main", "daemon", "ios"
    ]
    private static let week: TimeInterval = 7 * 86_400

    private struct Orphan {
        var title: String
        var identifiers: Set<String> = []
        var entries: [LibraryEntry] = []
        var vendorApp: String?
        /// The app itself is installed; only its launch agent points nowhere.
        var isInstalled = false
    }

    @concurrent
    static func scan(env: ScanEnvironment, running: RunningSnapshot, progress: ProgressSink) async -> [ItemGroup] {
        progress.send(String(localized: "Составляю список установленных приложений…"))
        let index = OwnershipIndex(apps: InstalledApps.allKnown(env: env), running: running)
        if Task.isCancelled { return [] }

        progress.send(String(localized: "Просматриваю ~/Library…"))
        let entries = LibraryCatalog.entries(env: env)
        var orphans: [String: Orphan] = [:]

        // Pass 1: entries named after a bundle identifier.
        for entry in entries {
            guard let identifier = entry.identifier else { continue }
            if entry.launchTargetMissing == false { continue }
            let verdict = index.verdict(for: identifier)
            if case .installed = verdict, entry.launchTargetMissing != true { continue }

            let key = groupKey(identifier)
            var orphan = orphans[key] ?? Orphan(title: key)
            orphan.identifiers.insert(identifier)
            orphan.entries.append(entry)
            if case .sameVendor(let appName) = verdict {
                orphan.vendorApp = appName
            }
            if case .installed = verdict {
                orphan.isInstalled = true
            }
            orphans[key] = orphan
        }

        // Pass 2: folders named after the app itself ("Slack"), attached only when an orphaned
        // identifier points at the same name and nothing installed could own them.
        for entry in entries {
            guard let name = entry.plainName, !index.ownsName(name) else { continue }
            guard let key = orphans.first(where: { matches(name: name, orphan: $0.value) })?.key else { continue }
            orphans[key]?.entries.append(entry)
            orphans[key]?.title = entry.url.lastPathComponent
        }
        if Task.isCancelled { return [] }

        progress.send(String(localized: "Считаю размеры: \(Fmt.apps(orphans.count))…"))
        let recent = Date.now.addingTimeInterval(-week)
        var groups: [ItemGroup] = []
        for (key, orphan) in orphans {
            if Task.isCancelled { return [] }
            let items = orphan.entries.map { entry in
                let isRecent = (entry.modified ?? .distantPast) > recent
                let note = if entry.launchTargetMissing == true {
                    String(localized: "Автозапуск программы, которой больше нет")
                } else if isRecent {
                    String(localized: "\(entry.kind) · изменялось на этой неделе — возможно, ещё используется")
                } else {
                    entry.kind
                }
                return FoundItem(
                    url: entry.url,
                    size: DirectorySize.allocated(entry.url),
                    date: entry.modified,
                    note: note,
                    safety: isRecent || orphan.vendorApp != nil ? .caution : .review
                )
            }
            let identifier = orphan.identifiers.sorted().first ?? key
            let subtitle = if orphan.isInstalled {
                String(localized: "\(identifier) · приложение установлено, но его автозапуск ссылается на несуществующую программу")
            } else if let vendorApp = orphan.vendorApp {
                String(localized: "\(identifier) · установлено «\(vendorApp)» того же разработчика — файлы могут быть общими")
            } else {
                String(localized: "\(identifier) · приложение не найдено на этом Mac")
            }
            groups.append(ItemGroup(
                id: key,
                title: orphan.title,
                subtitle: subtitle,
                symbol: orphan.vendorApp == nil ? "puzzlepiece.extension" : "questionmark.app.dashed",
                items: items.sorted { $0.size > $1.size }
            ))
        }
        return groups.sorted { $0.totalSize > $1.totalSize }
    }

    /// Library files of one installed application, for uninstalling it together with its data.
    static func relatedFiles(for app: InstalledApp, others: [InstalledApp], env: ScanEnvironment) -> [FoundItem] {
        let sharedIDs = Set(others.flatMap { [$0.bundleID] + $0.helperIDs }.map { $0.lowercased() })
        let ownIDs = Set(([app.bundleID] + app.helperIDs).map { $0.lowercased() }).subtracting(sharedIDs)
        let mainID = app.bundleID.lowercased()
        let appName = NameNormalizer.normalize(app.name)
        let nameIsShared = others.contains { NameNormalizer.normalize($0.name) == appName }

        return LibraryCatalog.entries(env: env).compactMap { entry in
            let isOwn: Bool
            if let identifier = entry.identifier {
                isOwn = ownIDs.contains(identifier)
                    || (identifier.hasPrefix(mainID + ".") && !sharedIDs.contains(identifier))
            } else {
                isOwn = !nameIsShared && appName.count >= 3 && entry.plainName == appName
            }
            guard isOwn else { return nil }
            return FoundItem(
                url: entry.url,
                size: DirectorySize.allocated(entry.url),
                date: entry.modified,
                note: entry.kind,
                safety: .review,
                preselected: true
            )
        }
        .sorted { $0.size > $1.size }
    }

    /// Files of one app share the first three identifier components: "com.vendor.app.helper" → "com.vendor.app".
    private static func groupKey(_ identifier: String) -> String {
        identifier.split(separator: ".").prefix(3).joined(separator: ".")
    }

    private static func matches(name: String, orphan: Orphan) -> Bool {
        for identifier in orphan.identifiers {
            for part in identifier.split(separator: ".").dropFirst() {
                let token = NameNormalizer.normalize(String(part))
                guard token.count >= 3, !ignoredTokens.contains(token) else { continue }
                if token == name { return true }
                if name.count >= 5, token.hasPrefix(name) { return true }
            }
        }
        return false
    }
}
