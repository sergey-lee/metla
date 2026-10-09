import Foundation

/// One installed application in the uninstaller table.
struct AppRow: Identifiable, Sendable {
    let app: InstalledApp
    var size: Int64
    let lastUsed: Date?

    var id: String { app.id }
    var name: String { app.name }
    /// Sort key: apps that were never launched sort as the oldest.
    var lastUsedKey: Date { lastUsed ?? .distantPast }
}
