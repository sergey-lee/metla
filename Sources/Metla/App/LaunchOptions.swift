import Foundation

/// Command-line switches used by automated checks: `--home`, `--root`, `--snapshot`.
struct LaunchOptions: Sendable {
    var environment = ScanEnvironment.live
    var root: URL?
    var snapshotFolder: URL?
    /// Window size in points for `--snapshot`, e.g. `--window 1280x800`.
    var windowSize: CGSize?

    init(arguments: [String] = Array(CommandLine.arguments.dropFirst())) {
        func value(after flag: String) -> URL? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return URL(filePath: arguments[index + 1])
        }
        if let home = value(after: "--home") {
            // Directory listings return fully resolved paths, so the fixture home must be resolved too.
            let resolved = realpath(home.path, nil).map { pointer in
                defer { free(pointer) }
                return URL(filePath: String(cString: pointer))
            }
            environment = ScanEnvironment(home: resolved ?? home, isRealHome: false)
        }
        root = value(after: "--root") ?? (environment.isRealHome ? nil : environment.home)
        snapshotFolder = value(after: "--snapshot")
        if let index = arguments.firstIndex(of: "--window"), index + 1 < arguments.count {
            let parts = arguments[index + 1].split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 {
                windowSize = CGSize(width: parts[0], height: parts[1])
            }
        }
    }
}
