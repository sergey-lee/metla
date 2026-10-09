import AppKit
import Observation

/// Folder permissions for the sandboxed build. A sandboxed app may only read folders the user picked
/// in an open panel; the choice is remembered as a security-scoped bookmark. Outside the sandbox
/// everything is already accessible and this type does nothing.
@MainActor
@Observable
final class FolderAccess {
    private enum Key: String {
        case home = "bookmark.home"
        case applications = "bookmark.applications"
        case scanRoot = "bookmark.scanRoot"
    }

    private(set) var hasHomeAccess = !Sandbox.isActive
    private(set) var hasApplicationsAccess = !Sandbox.isActive
    var notice: String?

    init() {
        guard Sandbox.isActive else { return }
        #if DEBUG
        // Automated checks: the Debug entitlements already allow the home folder.
        if CommandLine.arguments.contains("--assume-home-access") {
            hasHomeAccess = true
            hasApplicationsAccess = true
            return
        }
        #endif
        if let home = restore(.home) {
            hasHomeAccess = Self.covers(home, Sandbox.realHome)
        }
        hasApplicationsAccess = restore(.applications) != nil
        _ = restore(.scanRoot)
    }

    /// Asks for the home folder if it has not been granted yet. Returns whether scanning can go ahead.
    func ensureHome() -> Bool {
        if hasHomeAccess { return true }
        let message = String(localized: "Выберите домашнюю папку, чтобы Метла могла искать в ней лишние файлы.")
        guard let url = choose(startingAt: Sandbox.realHome, message: message) else { return false }
        guard Self.covers(url, Sandbox.realHome) else {
            notice = String(localized: "Выбрана другая папка. Для поиска мусора и остатков приложений нужна именно домашняя папка.")
            return false
        }
        keep(url, as: .home)
        hasHomeAccess = true
        notice = nil
        return true
    }

    /// Asks for the Applications folder, which is needed to move an app from there to the Trash.
    func ensureApplications() -> Bool {
        if hasApplicationsAccess { return true }
        let folder = URL(filePath: "/Applications", directoryHint: .isDirectory)
        let message = String(localized: "Чтобы переместить приложение в Корзину, разрешите доступ к папке «Программы».")
        guard let url = choose(startingAt: folder, message: message), Self.covers(url, folder) else { return false }
        keep(url, as: .applications)
        hasApplicationsAccess = true
        return true
    }

    /// Keeps access to a custom scan folder the user picked, across launches.
    func rememberScanRoot(_ url: URL) {
        guard Sandbox.isActive else { return }
        keep(url, as: .scanRoot)
    }

    /// Whether access to `granted` includes `folder`.
    private static func covers(_ granted: URL, _ folder: URL) -> Bool {
        let grantedPath = granted.standardizedFileURL.path
        let folderPath = folder.standardizedFileURL.path
        return folderPath == grantedPath || folderPath.hasPrefix(grantedPath == "/" ? "/" : grantedPath + "/")
    }

    private func choose(startingAt folder: URL, message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = folder
        panel.message = message
        panel.prompt = String(localized: "Разрешить доступ")
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func keep(_ url: URL, as key: Key) {
        _ = url.startAccessingSecurityScopedResource()
        if let bookmark = try? url.bookmarkData(options: [.withSecurityScope]) {
            UserDefaults.standard.set(bookmark, forKey: key.rawValue)
        }
    }

    private func restore(_ key: Key) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: key.rawValue) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &isStale
        ), url.startAccessingSecurityScopedResource() else { return nil }
        if isStale, let fresh = try? url.bookmarkData(options: [.withSecurityScope]) {
            UserDefaults.standard.set(fresh, forKey: key.rawValue)
        }
        return url
    }
}
