import AppKit
import Observation

@MainActor
@Observable
final class AppsModel {
    private(set) var rows: [AppRow] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isWorking = false
    var sortOrder = [KeyPathComparator(\AppRow.size, order: .reverse)]
    var query = ""
    var plan: UninstallPlan?
    var notice: String?

    @ObservationIgnored private let environment: ScanEnvironment
    @ObservationIgnored private let access: FolderAccess

    init(environment: ScanEnvironment, access: FolderAccess) {
        self.environment = environment
        self.access = access
    }

    var visibleRows: [AppRow] {
        query.isEmpty ? rows : rows.filter { $0.name.localizedStandardContains(query) }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        let env = environment
        rows = await Self.listApps(env: env)
        sort()

        // Sizes take a while, so fill them in as they arrive.
        await withTaskGroup(of: (String, Int64).self) { group in
            var pending = rows.map(\.app).makeIterator()
            func addNext(_ group: inout TaskGroup<(String, Int64)>) {
                guard let app = pending.next() else { return }
                group.addTask { (app.id, await Self.size(of: app.url)) }
            }
            for _ in 0..<4 {
                addNext(&group)
            }
            for await (id, size) in group {
                if let index = rows.firstIndex(where: { $0.id == id }) {
                    rows[index].size = size
                }
                addNext(&group)
            }
        }
        sort()
    }

    func sort() {
        rows.sort(using: sortOrder)
    }

    func row(with id: String?) -> AppRow? {
        rows.first { $0.id == id }
    }

    func prepareUninstall(_ row: AppRow) async {
        let ownBundleID = Bundle.main.bundleIdentifier
        if row.app.bundleID == ownBundleID {
            notice = String(localized: "Это само приложение «Метла» — удалить себя оно не может.")
            return
        }
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == row.app.bundleID
        }
        if isRunning {
            notice = String(localized: "«\(row.name)» сейчас запущено. Завершите его и повторите удаление.")
            return
        }
        // Related files live in the home folder, and the app itself usually in /Applications.
        guard access.ensureHome() else { return }
        if row.app.url.path.hasPrefix("/Applications/"), !access.ensureApplications() { return }
        isWorking = true
        let env = environment
        let others = rows.map(\.app).filter { $0.id != row.id }
        let related = await Self.relatedFiles(for: row.app, others: others, env: env)
        isWorking = false
        plan = UninstallPlan(row: row, related: related)
    }

    func uninstall(_ plan: UninstallPlan, relatedSelection: Set<String>) async {
        isWorking = true
        let related = plan.related.filter { relatedSelection.contains($0.id) }
        let urls = [plan.row.app.url] + related.map(\.url)
        let outcome = await Trasher.trash(urls, askFinderFor: [plan.row.id])
        isWorking = false

        if outcome.trashed.contains(plan.row.id) {
            rows.removeAll { $0.id == plan.row.id }
            let freed = plan.row.size + related.filter { outcome.trashed.contains($0.id) }.reduce(Int64(0)) { $0 + $1.size }
            var message = [String(localized: "«\(plan.row.name)» перемещено в Корзину вместе со связанными файлами: \(Fmt.bytes(freed)).")]
            if !outcome.failures.isEmpty {
                message.append(String(localized: "Не удалось переместить: \(Fmt.objects(outcome.failures.count))."))
            }
            notice = message.joined(separator: " ")
        } else {
            let reason = outcome.failures.first { $0.path == plan.row.id }?.reason ?? String(localized: "неизвестная ошибка")
            notice = String(localized: "Не удалось удалить «\(plan.row.name)»: \(reason)")
        }
    }

    @concurrent
    private static func listApps(env: ScanEnvironment) async -> [AppRow] {
        InstalledApps.userApps(env: env).map { app in
            AppRow(app: app, size: 0, lastUsed: OldFileScanner.spotlightLastUsed(app.url))
        }
    }

    @concurrent
    private static func size(of url: URL) async -> Int64 {
        DirectorySize.allocated(url)
    }

    @concurrent
    private static func relatedFiles(for app: InstalledApp, others: [InstalledApp], env: ScanEnvironment) async -> [FoundItem] {
        LeftoverScanner.relatedFiles(for: app, others: others, env: env)
    }
}
