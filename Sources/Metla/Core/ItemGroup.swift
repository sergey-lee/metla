import Foundation

/// A titled set of found items: a junk category, a set of duplicates, a removed app.
struct ItemGroup: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let symbol: String
    var items: [FoundItem]

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
}
