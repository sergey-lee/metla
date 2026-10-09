import Foundation

/// Formatting helpers. Numbers, sizes and dates follow the language the interface is shown in.
enum Fmt {
    static let locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

    static func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file).locale(locale))
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    // Counted nouns. The plural forms for every language live in the string catalog.

    static func objects(_ count: Int) -> String {
        String(localized: "\(count) объектов")
    }

    static func files(_ count: Int) -> String {
        String(localized: "\(count) файлов")
    }

    static func copies(_ count: Int) -> String {
        String(localized: "\(count) копий")
    }

    static func apps(_ count: Int) -> String {
        String(localized: "\(count) приложений")
    }

    /// The home folder paths are shown relative to: the real one, or the fixture given with `--home`.
    private static let homePath = LaunchOptions().environment.home.path

    /// Replaces the home directory prefix with `~`.
    static func tilde(_ path: String) -> String {
        let home = homePath
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}
