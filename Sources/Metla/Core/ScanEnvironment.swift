import Foundation

/// Where scanners look. Tests point this at a fixture instead of the real home folder.
struct ScanEnvironment: Sendable {
    let home: URL
    let isRealHome: Bool

    static let live = ScanEnvironment(home: Sandbox.realHome, isRealHome: true)

    var library: URL { home.appending(path: "Library") }

    /// Folders that hold installed applications.
    var userAppRoots: [URL] {
        var roots = [home.appending(path: "Applications")]
        if isRealHome { roots.insert(URL(filePath: "/Applications"), at: 0) }
        return roots
    }
}
