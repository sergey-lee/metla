import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    var section: SectionKind? = .overview
    let scans: [SectionKind: ScanModel]
    let apps: AppsModel
    let access: FolderAccess

    private(set) var disk: DiskInfo?
    private(set) var trashSize: Int64?
    private(set) var hasFullDiskAccess = true
    private(set) var isEmptyingTrash = false
    var trashNotice: String?

    @ObservationIgnored let environment: ScanEnvironment
    /// Fixed scan folder for automated checks; normally the folder comes from settings.
    @ObservationIgnored let rootOverride: URL?

    init(environment: ScanEnvironment = .live, rootOverride: URL? = nil) {
        self.environment = environment
        self.rootOverride = rootOverride
        scans = Dictionary(uniqueKeysWithValues: SectionKind.scannable.map { ($0, ScanModel(kind: $0)) })
        let access = FolderAccess()
        self.access = access
        apps = AppsModel(environment: environment, access: access)
    }

    var isScanning: Bool {
        scans.values.contains { $0.phase == .scanning }
    }

    var totalFound: Int64 {
        scans.values.reduce(0) { $0 + $1.totalSize }
    }

    func scan(_ kind: SectionKind) {
        guard let model = scans[kind], access.ensureHome() else { return }
        var current = ScanSettings.current
        if let rootOverride {
            current.root = rootOverride
        }
        let settings = current
        let env = environment
        let running = RunningSnapshot.capture()

        switch kind {
        case .junk:
            model.start { await JunkScanner.scan(env: env, running: running, progress: $0) }
        case .duplicates:
            model.start {
                await DuplicateScanner.scan(root: settings.root, env: env, minSize: settings.duplicateMinSize, progress: $0)
            }
        case .large:
            model.start {
                await LargeFileScanner.scan(
                    root: settings.root, env: env, minSize: settings.largeMinSize,
                    includeLibrary: settings.largeIncludeLibrary, progress: $0
                )
            }
        case .old:
            model.start {
                await OldFileScanner.scan(
                    root: settings.root, env: env, months: settings.oldMonths,
                    minSize: settings.oldMinSize, progress: $0
                )
            }
        case .leftovers:
            model.start { await LeftoverScanner.scan(env: env, running: running, progress: $0) }
        case .overview, .apps:
            break
        }
    }

    func scanAll() {
        guard access.ensureHome() else { return }
        for kind in SectionKind.scannable {
            scan(kind)
        }
    }

    func cancelAll() {
        for model in scans.values where model.phase == .scanning {
            model.cancel()
        }
    }

    func refreshSystemFacts() async {
        let facts = await SystemProbe.facts(env: environment)
        disk = facts.disk
        trashSize = facts.trashSize
        hasFullDiskAccess = facts.hasFullDiskAccess
    }

    func emptyTrash() async {
        guard !isEmptyingTrash else { return }
        isEmptyingTrash = true
        let succeeded = await SystemProbe.emptyTrash()
        if succeeded {
            await waitUntilTrashIsEmpty()
        }
        isEmptyingTrash = false
        trashNotice = succeeded
            ? String(localized: "Корзина очищена.")
            : Sandbox.isActive
            ? String(localized: "Не удалось очистить Корзину. Дайте приложению полный доступ к диску или очистите Корзину в Finder.")
            : String(localized: "Не удалось очистить Корзину. Разрешите приложению управлять Finder в Системных настройках → Конфиденциальность и безопасность → Автоматизация или очистите Корзину вручную.")
        await refreshSystemFacts()
    }

    /// Finder reports success as soon as it starts deleting, so keep re-reading the Trash and the
    /// free space until the Trash is really empty. Gives up after a minute.
    private func waitUntilTrashIsEmpty() async {
        for _ in 0..<120 {
            await refreshSystemFacts()
            guard let trashSize, trashSize > 0 else { break }
            try? await Task.sleep(for: .milliseconds(500))
        }
        // Without Full Disk Access the Trash cannot be read; give Finder a moment before the final read.
        if trashSize == nil {
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
