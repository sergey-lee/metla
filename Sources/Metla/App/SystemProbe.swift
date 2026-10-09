import Foundation

/// Read-only facts about the system that the overview shows.
enum SystemProbe {
    struct Facts: Sendable {
        let disk: DiskInfo?
        let hasFullDiskAccess: Bool
        /// `nil` when the Trash cannot be read without Full Disk Access.
        let trashSize: Int64?
    }

    @concurrent
    static func facts(env: ScanEnvironment) async -> Facts {
        // A test home is fully readable and has its own Trash.
        if !env.isRealHome {
            return Facts(disk: DiskInfo.current(), hasFullDiskAccess: true, trashSize: trashSize(in: env.home))
        }
        // The privacy database is readable only with Full Disk Access, and trying never shows a prompt.
        let privacyDatabase = Sandbox.realHome.appending(path: "Library/Application Support/com.apple.TCC/TCC.db")
        let handle = try? FileHandle(forReadingFrom: privacyDatabase)
        try? handle?.close()
        return Facts(disk: DiskInfo.current(), hasFullDiskAccess: handle != nil, trashSize: trashSize(in: Sandbox.realHome))
    }

    /// Size of what the user sees in the Trash. Finder keeps a hidden `.DS_Store` there even when
    /// the Trash is empty, so hidden files do not count.
    private static func trashSize(in home: URL) -> Int64? {
        let trash = home.appending(path: ".Trash")
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        return items.reduce(0) { $0 + DirectorySize.allocated($1) }
    }

    @concurrent
    static func emptyTrash() async -> Bool {
        if Sandbox.isActive { return emptyTrashDirectly() }
        return Shell.run("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty trash"]).status == 0
    }

    /// The sandboxed build cannot ask Finder, so it deletes what is in the Trash itself.
    /// This is the only place where files are removed permanently, and only after the user confirms.
    private static func emptyTrashDirectly() -> Bool {
        let trash = Sandbox.realHome.appending(path: ".Trash")
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return false }
        var removedEverything = true
        for item in items {
            do {
                try FileManager.default.removeItem(at: item)
            } catch {
                removedEverything = false
            }
        }
        return removedEverything
    }
}
