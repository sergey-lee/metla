import Foundation

/// Moves things to the Trash. Nothing in this app deletes files permanently, except emptying the Trash itself.
enum Trasher {
    struct Failure: Sendable {
        let path: String
        let reason: String
    }

    struct Outcome: Sendable {
        var trashed: Set<String> = []
        var failures: [Failure] = []
    }

    @concurrent
    static func trash(_ urls: [URL], askFinderFor finderPaths: Set<String> = []) async -> Outcome {
        var outcome = Outcome()
        // Shorter paths first, so a folder goes before anything selected inside it.
        for url in urls.sorted(by: { $0.path.count < $1.path.count }) {
            let path = url.path
            if isProtected(url) {
                outcome.failures.append(Failure(path: path, reason: String(localized: "Системная папка, удаление запрещено")))
                continue
            }
            guard (try? url.checkResourceIsReachable()) == true || isBrokenSymlink(path) else {
                outcome.trashed.insert(path)
                continue
            }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                outcome.trashed.insert(path)
            } catch {
                if finderPaths.contains(path), trashWithFinder(path) {
                    outcome.trashed.insert(path)
                } else {
                    outcome.failures.append(Failure(path: path, reason: error.localizedDescription))
                }
            }
        }
        return outcome
    }

    /// Guards against ever trashing a top-level system or home folder, whatever a scanner returns.
    static func isProtected(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = Sandbox.realHome.path
        let homeFolders = [
            "", "/Library", "/Desktop", "/Documents", "/Downloads", "/Movies", "/Music", "/Pictures", "/Public",
            "/Applications", "/Library/Application Support", "/Library/Caches", "/Library/Preferences",
            "/Library/Containers", "/Library/Group Containers", "/Library/Logs", "/Library/LaunchAgents",
            "/Library/Developer", "/Library/Mobile Documents", "/Library/CloudStorage", "/.Trash"
        ]
        if homeFolders.contains(where: { home + $0 == path }) { return true }

        let systemFolders = ["/", "/Applications", "/Library", "/System", "/Users", "/Volumes", "/private", "/opt"]
        if systemFolders.contains(path) { return true }

        let systemPrefixes = ["/System/", "/usr/", "/bin/", "/sbin/", "/private/var/db/", "/private/etc/", "/Library/Apple/"]
        return systemPrefixes.contains { path.hasPrefix($0) }
    }

    private static func isBrokenSymlink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    /// Finder can ask for an administrator password, which is needed for apps installed by a package.
    private static func trashWithFinder(_ path: String) -> Bool {
        // Scripting Finder is not available to a sandboxed app.
        if Sandbox.isActive { return false }
        let script = [
            "on run argv",
            "tell application \"Finder\" to delete (POSIX file (item 1 of argv) as alias)",
            "end run"
        ]
        return Shell.run("/usr/bin/osascript", script.flatMap { ["-e", $0] } + [path]).status == 0
    }
}
