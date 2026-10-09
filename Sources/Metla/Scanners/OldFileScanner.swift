import CoreServices
import Foundation

/// Lists files that have not been opened or changed for a long time.
enum OldFileScanner {
    private static let maxItems = 1000

    @concurrent
    static func scan(
        root: URL, env: ScanEnvironment, months: Int, minSize: Int64, progress: ProgressSink
    ) async -> [ItemGroup] {
        guard let cutoff = Calendar.current.date(byAdding: .month, value: -months, to: .now) else { return [] }

        let found = await FileWalker.collect(root: root, env: env, options: WalkOptions(), progress: progress) { file in
            guard file.allocatedSize >= minSize, let last = file.lastActivity else { return false }
            return last < cutoff
        }
        if Task.isCancelled || found.isEmpty { return [] }

        // File dates miss "opened in an app"; Spotlight remembers that separately.
        progress.send(String(localized: "Уточняю даты последнего открытия…"))
        var items: [FoundItem] = []
        for file in found.sorted(by: { $0.allocatedSize > $1.allocatedSize }) {
            if Task.isCancelled { return [] }
            var last = file.lastActivity ?? cutoff
            if let used = spotlightLastUsed(file.url), used > last {
                last = used
            }
            guard last < cutoff else { continue }
            items.append(FoundItem(url: file.url, size: file.allocatedSize, date: last, safety: .review))
            if items.count == maxItems { break }
        }
        guard !items.isEmpty else { return [] }
        return [ItemGroup(id: "old", title: String(localized: "Давно не использовались"), subtitle: nil, symbol: "clock", items: items)]
    }

    static func spotlightLastUsed(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }
}
