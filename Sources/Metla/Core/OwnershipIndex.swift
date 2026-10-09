import Foundation

/// Answers "does anything installed own this identifier or folder name?"
struct OwnershipIndex: Sendable {
    enum Verdict: Sendable {
        case installed
        /// Not installed itself, but another app of the same developer is.
        case sameVendor(appName: String)
        case unknown
    }

    private static let genericTokens: Set<String> = [
        "app", "mac", "macos", "osx", "desktop", "client", "helper", "launcher", "agent", "main", "daemon", "ios"
    ]

    /// Identifier prefixes shared by unrelated developers; having one such app installed says nothing about another.
    private static let sharedVendors: Set<String> = [
        "com.electron", "org.electron", "com.github", "io.github", "com.todesktop", "com.example", "com.yourcompany"
    ]

    private let ids: Set<String>
    private let idPrefixes: Set<String>
    private let vendors: [String: String]
    private let nameTokens: Set<String>

    init(apps: [InstalledApp], running: RunningSnapshot) {
        var ids = running.bundleIDs
        var prefixes: Set<String> = []
        var vendors: [String: String] = [:]
        var tokens = running.names

        for app in apps {
            tokens.insert(NameNormalizer.normalize(app.name))
            for identifier in [app.bundleID] + app.helperIDs {
                let lowered = identifier.lowercased()
                ids.insert(lowered)
                let parts = lowered.split(separator: ".").map(String.init)
                if parts.count >= 2 {
                    for length in 2..<parts.count {
                        prefixes.insert(parts[0..<length].joined(separator: "."))
                    }
                }
                if parts.count >= 3, !Self.sharedVendors.contains(parts[0..<2].joined(separator: ".")) {
                    vendors[parts[0..<2].joined(separator: ".")] = app.name
                    tokens.insert(NameNormalizer.normalize(parts[1]))
                }
                if let last = parts.last {
                    tokens.insert(NameNormalizer.normalize(last))
                }
            }
        }
        for identifier in running.bundleIDs {
            let parts = identifier.split(separator: ".").map(String.init)
            if parts.count >= 2 {
                for length in 2..<parts.count {
                    prefixes.insert(parts[0..<length].joined(separator: "."))
                }
            }
        }

        self.ids = ids
        self.idPrefixes = prefixes
        self.vendors = vendors
        self.nameTokens = tokens.filter { $0.count >= 3 && !Self.genericTokens.contains($0) }
    }

    /// `identifier` must be lowercased.
    func verdict(for identifier: String) -> Verdict {
        let parts = identifier.split(separator: ".").map(String.init)
        if parts.count >= 2 {
            for length in stride(from: parts.count, through: 2, by: -1)
            where ids.contains(parts[0..<length].joined(separator: ".")) {
                return .installed
            }
        } else if ids.contains(identifier) {
            return .installed
        }
        if idPrefixes.contains(identifier) { return .installed }
        // "com.unity3d.unityeditor" is owned by an installed "com.unity3d.unityeditor5.x".
        if parts.count >= 3, ids.contains(where: { $0.hasPrefix(identifier) }) { return .installed }
        if parts.count >= 3, let appName = vendors[parts[0..<2].joined(separator: ".")] {
            return .sameVendor(appName: appName)
        }
        return .unknown
    }

    /// `name` must be normalized. Errs on the side of "owned" so that live data is not flagged.
    func ownsName(_ name: String) -> Bool {
        if nameTokens.contains(name) { return true }
        guard name.count >= 4 else { return false }
        return nameTokens.contains { $0.count >= 4 && ($0.contains(name) || name.contains($0)) }
    }
}
