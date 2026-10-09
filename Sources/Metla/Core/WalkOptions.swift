import Foundation

struct WalkOptions: Sendable {
    /// Also descend into hidden folders and `~/Library`.
    var includeHiddenAndLibrary = false
    /// Skip dependency folders such as `node_modules`, where duplicates are expected.
    var skipDeveloperFolders = true
    /// Report packages (`.app`, `.photoslibrary`, …) as single items with their total size.
    var packagesAsItems = false
}
