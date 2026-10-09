import Foundation

/// What uninstalling one application would move to the Trash.
struct UninstallPlan: Identifiable, Sendable {
    let row: AppRow
    let related: [FoundItem]

    var id: String { row.id }
}
