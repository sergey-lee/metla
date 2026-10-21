import Foundation

/// Lists the places in `~/Library` where applications leave per-app files.
enum LibraryCatalog {
    private struct Location {
        let path: String
        let kind: String
        let suffixes: [String]
        let allowsPlainNames: Bool
        var isLaunchAgents = false
    }

    private static let locations: [Location] = [
        Location(path: "Application Support", kind: String(localized: "Данные приложения"), suffixes: [], allowsPlainNames: true),
        Location(path: "Caches", kind: String(localized: "Кэш"), suffixes: [], allowsPlainNames: true),
        Location(path: "Logs", kind: String(localized: "Журналы"), suffixes: [], allowsPlainNames: true),
        Location(path: "Preferences", kind: String(localized: "Настройки"), suffixes: [".plist"], allowsPlainNames: false),
        Location(path: "Preferences/ByHost", kind: String(localized: "Настройки"), suffixes: [".plist"], allowsPlainNames: false),
        Location(path: "Saved Application State", kind: String(localized: "Сохранённое состояние окон"), suffixes: [".savedState"], allowsPlainNames: false),
        Location(path: "Containers", kind: String(localized: "Контейнер приложения"), suffixes: [], allowsPlainNames: false),
        Location(path: "Group Containers", kind: String(localized: "Общий контейнер"), suffixes: [], allowsPlainNames: false),
        Location(path: "Application Scripts", kind: String(localized: "Скрипты приложения"), suffixes: [], allowsPlainNames: false),
        Location(path: "HTTPStorages", kind: String(localized: "Сетевые данные"), suffixes: [".binarycookies"], allowsPlainNames: false),
        Location(path: "WebKit", kind: String(localized: "Данные веб-движка"), suffixes: [], allowsPlainNames: false),
        Location(path: "Cookies", kind: "Cookies", suffixes: [".binarycookies"], allowsPlainNames: false),
        Location(path: "LaunchAgents", kind: String(localized: "Автозапуск"), suffixes: [".plist"], allowsPlainNames: false, isLaunchAgents: true)
    ]

    private static let topLevelDomains: Set<String> = [
        "com", "org", "net", "io", "app", "co", "me", "dev", "ru", "de", "uk", "fr", "jp", "kr", "cn", "us", "eu",
        "ch", "at", "nl", "se", "it", "es", "pl", "cz", "tv", "ai", "xyz", "im", "cc", "sh", "so", "to", "fm", "be",
        "in", "au", "ca", "br", "edu", "info", "tech", "pro", "one", "is", "fi", "no", "dk", "ua", "by", "kz",
        "software", "studio", "cloud", "design", "tools", "company"
    ]

    /// Identifiers that belong to macOS itself and must never be reported.
    private static let systemMarkers = ["com.apple", "org.cups", "com.openssh", "org.swift", "org.llvm"]

    /// Plain folder names used by macOS itself.
    static let systemPlainNames: Set<String> = [
        "dock", "addressbook", "callhistorydb", "callhistorytransactions", "clouddocs", "crashreporter",
        "knowledge", "mobilesync", "syncservices", "icloud", "icdd", "fileprovider", "diskimages", "quicklook",
        "facetime", "animoji", "differentialprivacy", "accessibility", "identityservices", "networkserviceproxy",
        "diagnosticreports", "assistant", "accounts", "calendars", "mail", "messages", "safari", "photos",
        "homekit", "siri", "spotlight", "finder", "desktop", "keychains", "fonts", "metadata"
    ]

    static func entries(env: ScanEnvironment) -> [LibraryEntry] {
        var result: [LibraryEntry] = []
        for location in locations {
            let directory = env.library.appending(path: location.path)
            let children = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for child in children {
                if let entry = entry(for: child, in: location) {
                    result.append(entry)
                }
            }
        }
        return result
    }

    private static func entry(for url: URL, in location: Location) -> LibraryEntry? {
        var name = url.lastPathComponent
        for suffix in location.suffixes where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        name = stripHostIdentifier(stripGroupPrefix(name))
        let lowered = name.lowercased()
        if systemMarkers.contains(where: { lowered.contains($0) }) || AppleData.owns(name: url.lastPathComponent) { return nil }

        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        if isIdentifier(lowered) {
            return LibraryEntry(
                url: url,
                kind: location.kind,
                identifier: lowered,
                plainName: nil,
                launchTargetMissing: location.isLaunchAgents ? launchTargetMissing(url) : nil,
                modified: modified
            )
        }
        guard location.allowsPlainNames else { return nil }
        let plain = NameNormalizer.normalize(name)
        guard plain.count >= 3, !systemPlainNames.contains(plain) else { return nil }
        return LibraryEntry(
            url: url,
            kind: location.kind,
            identifier: nil,
            plainName: plain,
            launchTargetMissing: nil,
            modified: modified
        )
    }

    /// "group.com.foo.bar" and "ABCDE12345.com.foo.bar" → "com.foo.bar".
    private static func stripGroupPrefix(_ name: String) -> String {
        var result = Substring(name)
        if let dot = result.firstIndex(of: "."), result[..<dot].count == 10,
           result[..<dot].allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }) {
            result = result[result.index(after: dot)...]
        }
        if result.hasPrefix("group.") {
            result = result.dropFirst("group.".count)
        }
        return String(result)
    }

    /// ByHost preferences end with a hardware UUID: "com.foo.bar.0A1B…".
    private static func stripHostIdentifier(_ name: String) -> String {
        guard let dot = name.lastIndex(of: ".") else { return name }
        let tail = name[name.index(after: dot)...]
        let looksLikeUUID = tail.count == 36 && tail.allSatisfy { $0.isHexDigit || $0 == "-" }
        return looksLikeUUID ? String(name[..<dot]) : name
    }

    /// Whether a folder name is a reverse-DNS identifier such as "com.vendor.app".
    static func looksLikeIdentifier(_ name: String) -> Bool {
        isIdentifier(name.lowercased())
    }

    private static func isIdentifier(_ lowered: String) -> Bool {
        guard !lowered.contains(" ") else { return false }
        let parts = lowered.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        return topLevelDomains.contains(String(parts[0]))
    }

    /// A launch agent is dead when the program or an application path it references is gone.
    private static func launchTargetMissing(_ url: URL) -> Bool? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        var paths: [String] = []
        if let program = plist["Program"] as? String {
            paths.append(program)
        }
        if let arguments = plist["ProgramArguments"] as? [String] {
            paths += arguments.filter { $0.hasPrefix("/") }
        }
        guard !paths.isEmpty else { return nil }
        return paths.contains { !FileManager.default.fileExists(atPath: $0) }
    }
}
