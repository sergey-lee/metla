import Foundation

/// One file or folder directly inside a per-application area of `~/Library`.
struct LibraryEntry: Sendable {
    let url: URL
    /// Human-readable kind of data, e.g. "Настройки".
    let kind: String
    /// Lowercased reverse-DNS identifier parsed from the name, if the name looks like one.
    let identifier: String?
    /// Normalized plain name, for entries named after the app rather than its identifier.
    let plainName: String?
    /// For launch agents: the program it starts no longer exists.
    let launchTargetMissing: Bool?
    let modified: Date?
}
