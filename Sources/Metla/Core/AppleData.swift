import Foundation

/// Data that belongs to macOS or to Apple's own apps and services, Xcode included.
/// Metla never offers it for removal: it can hold sign-in state (Apple ID, Xcode developer
/// accounts, iCloud, App Store Connect sessions) that no amount of reclaimed space is worth.
enum AppleData {
    /// Apple folders in ~/Library that do not carry a com.apple prefix.
    private static let plainNames: Set<String> = [
        "accounts", "akd", "amsdatamigratortool", "animoji", "appleid", "assistant", "authkit",
        "callhistorydb", "callhistorytransactions", "cloudkit", "clouddocs", "cloudstorage", "familycircle",
        "familycircled", "fileprovider", "gamekit", "geoservices", "homekit", "icloud", "icloudmailagent",
        "identityservices", "installer_telemetry", "keychains", "locks", "mail", "mbuseragent", "messages",
        "metadata", "mobile documents", "passes", "passkit", "safari", "sharing", "siri", "siritts",
        "ssu", "suggestions", "temporaryitems", "wallet"
    ]

    /// Whether a single file or folder name is Apple's: "com.apple.dt.Xcode", "ABCDE12345.com.apple.x",
    /// "group.com.apple.x", "GeoServices".
    static func owns(name: String) -> Bool {
        hasAppleIdentifier(name) || isApplePlainName(name)
    }

    private static func hasAppleIdentifier(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered.hasPrefix("com.apple") || lowered.contains(".com.apple")
    }

    private static func isApplePlainName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered.hasPrefix("apple") || plainNames.contains(lowered)
    }

    /// Whether a path lies inside Apple's data in a Library folder (the user's or the system's).
    /// Copies of attachments that Mail saved for viewing are the one exception: they are plain duplicates.
    static func owns(path url: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        guard let library = components.firstIndex(of: "Library") else { return false }
        let inside = components[(library + 1)...]
        if let mailDownloads = inside.firstIndex(of: "Mail Downloads"),
           inside[..<mailDownloads].contains(where: { $0.lowercased() == "com.apple.mail" }),
           mailDownloads < components.count - 1 {
            return false
        }
        // Apple identifiers count at any depth. Plain names only right below Library and one level
        // deeper ("Library/GeoServices", "Library/Caches/GeoServices"), so a project called
        // "AppleWatchDemo" deep inside DerivedData is not mistaken for system data.
        return inside.contains(where: hasAppleIdentifier) || inside.prefix(2).contains(where: isApplePlainName)
    }
}
