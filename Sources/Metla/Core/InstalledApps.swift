import Foundation

/// Finds application bundles and reads their identifiers.
enum InstalledApps {
    private static let systemRoots = [
        "/System/Applications",
        "/System/Library/CoreServices",
        "/System/Cryptexes/App/System/Applications"
    ]

    private static let helperFolders = [
        "Contents/PlugIns", "Contents/Extensions", "Contents/XPCServices", "Contents/Helpers",
        "Contents/Frameworks", "Contents/Applications", "Contents/Resources", "Contents/MacOS",
        "Contents/SharedSupport", "Contents/Library/LoginItems", "Contents/Library/SystemExtensions"
    ]
    private static let helperExtensions: Set<String> = ["app", "appex", "xpc", "systemextension"]

    /// Applications the user can uninstall: `/Applications` and `~/Applications`.
    static func userApps(env: ScanEnvironment) -> [InstalledApp] {
        env.userAppRoots
            .flatMap { bundles(in: $0, depth: 4) }
            .compactMap { read($0, withHelpers: true) }
    }

    /// Everything that counts as "still installed" when deciding whether Library files are orphaned.
    static func allKnown(env: ScanEnvironment) -> [InstalledApp] {
        var apps = userApps(env: env)
        guard env.isRealHome else { return apps }
        var seen = Set(apps.map(\.id))
        let elsewhere = systemRoots.flatMap { bundles(in: URL(filePath: $0), depth: 2) } + spotlightBundles()
        for url in elsewhere where seen.insert(url.path).inserted {
            if let app = read(url, withHelpers: false) {
                apps.append(app)
            }
        }
        return apps
    }

    static func read(_ url: URL, withHelpers: Bool) -> InstalledApp? {
        guard let bundleID = bundleIdentifier(of: url) else { return nil }
        var helpers: [String] = []
        if withHelpers {
            for folder in helperFolders {
                for child in children(url.appending(path: folder))
                where helperExtensions.contains(child.pathExtension.lowercased()) {
                    if let helperID = bundleIdentifier(of: child), helperID != bundleID {
                        helpers.append(helperID)
                    }
                }
            }
        }
        return InstalledApp(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            bundleID: bundleID,
            helperIDs: helpers
        )
    }

    private static func bundleIdentifier(of bundle: URL) -> String? {
        // Regular bundles, then iOS apps running on Apple silicon, which wrap the real bundle.
        let candidates = ["Contents/Info.plist", "WrappedBundle/Info.plist", "Info.plist"]
        for candidate in candidates {
            guard let data = try? Data(contentsOf: bundle.appending(path: candidate)),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let identifier = plist["CFBundleIdentifier"] as? String,
                  !identifier.isEmpty
            else { continue }
            return identifier
        }
        return nil
    }

    private static func bundles(in root: URL, depth: Int) -> [URL] {
        var found: [URL] = []
        for child in children(root) {
            if child.pathExtension.lowercased() == "app" {
                found.append(child)
            } else if depth > 1, (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                found += bundles(in: child, depth: depth - 1)
            }
        }
        return found
    }

    private static func children(_ directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    /// Applications that live outside the standard folders, as known to Spotlight.
    private static func spotlightBundles() -> [URL] {
        // A sandboxed app cannot run the Spotlight tool; the standard folders have to do.
        if Sandbox.isActive { return [] }
        return Shell.run("/usr/bin/mdfind", ["kMDItemContentType == 'com.apple.application-bundle'"])
            .output
            .split(separator: "\n")
            .filter { $0.hasPrefix("/") }
            .map { URL(filePath: String($0)) }
    }
}
