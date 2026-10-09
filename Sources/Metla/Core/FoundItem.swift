import Foundation

/// A single file or folder that a scanner suggests removing.
struct FoundItem: Identifiable, Hashable, Sendable {
    /// Absolute path; unique within a scan.
    let id: String
    let url: URL
    let title: String
    let size: Int64
    let date: Date?
    let note: String?
    let safety: Safety
    let preselected: Bool

    init(
        url: URL,
        title: String? = nil,
        size: Int64,
        date: Date? = nil,
        note: String? = nil,
        safety: Safety = .review,
        preselected: Bool = false
    ) {
        self.id = url.path
        self.url = url
        self.title = title ?? url.lastPathComponent
        self.size = size
        self.date = date
        self.note = note
        self.safety = safety
        self.preselected = preselected
    }
}
