import Foundation

/// A file (or a package treated as one file) seen while walking a folder tree.
struct WalkedFile: Sendable {
    let url: URL
    let logicalSize: Int64
    let allocatedSize: Int64
    let modified: Date?
    let created: Date?
    /// Latest of: opened, modified, created, added to its folder.
    let lastActivity: Date?
    let isPackage: Bool
}
