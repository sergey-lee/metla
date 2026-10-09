import Foundation

/// The Mac App Store build runs inside the App Sandbox; the direct build does not.
/// The same code serves both and asks this type which rules apply.
enum Sandbox {
    static let isActive = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    /// The user's real home folder. Inside the sandbox `URL.homeDirectory` is the app's container instead.
    static let realHome: URL = {
        guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return .homeDirectory }
        return URL(filePath: String(cString: directory), directoryHint: .isDirectory)
    }()
}
