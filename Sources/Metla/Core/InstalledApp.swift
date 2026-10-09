import Foundation

struct InstalledApp: Identifiable, Sendable {
    let url: URL
    let name: String
    let bundleID: String
    /// Bundle identifiers of helpers, extensions and login items shipped inside the app.
    let helperIDs: [String]

    var id: String { url.path }
}
