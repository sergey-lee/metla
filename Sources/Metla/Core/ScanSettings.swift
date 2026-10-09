import Foundation

enum SettingsKey {
    static let scanRoot = "scanRoot"
    static let duplicateMinKB = "duplicateMinKB"
    static let largeMinMB = "largeMinMB"
    static let largeIncludeLibrary = "largeIncludeLibrary"
    static let oldMonths = "oldMonths"
    static let oldMinMB = "oldMinMB"
}

/// User-tunable scan thresholds, stored in UserDefaults and edited through `@AppStorage`.
struct ScanSettings: Sendable {
    var root: URL
    var duplicateMinSize: Int64
    var largeMinSize: Int64
    var largeIncludeLibrary: Bool
    var oldMonths: Int
    var oldMinSize: Int64

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.scanRoot: "",
            SettingsKey.duplicateMinKB: 1000,
            SettingsKey.largeMinMB: 100,
            SettingsKey.largeIncludeLibrary: true,
            SettingsKey.oldMonths: 12,
            SettingsKey.oldMinMB: 10
        ])
    }

    static var current: ScanSettings {
        let defaults = UserDefaults.standard
        let path = defaults.string(forKey: SettingsKey.scanRoot) ?? ""
        return ScanSettings(
            root: path.isEmpty ? Sandbox.realHome : URL(filePath: path),
            duplicateMinSize: Int64(defaults.integer(forKey: SettingsKey.duplicateMinKB)) * 1000,
            largeMinSize: Int64(defaults.integer(forKey: SettingsKey.largeMinMB)) * 1_000_000,
            largeIncludeLibrary: defaults.bool(forKey: SettingsKey.largeIncludeLibrary),
            oldMonths: defaults.integer(forKey: SettingsKey.oldMonths),
            oldMinSize: Int64(defaults.integer(forKey: SettingsKey.oldMinMB)) * 1_000_000
        )
    }
}
