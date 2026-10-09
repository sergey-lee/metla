import AppKit

/// The interface language. By default the app follows macOS; the user can pin a language for this app only.
@MainActor
enum AppLanguage {
    struct Option: Identifiable, Hashable {
        /// Language code such as "pt-BR"; empty means "follow the system".
        let id: String
        /// The language's own name, e.g. "Deutsch".
        let name: String
    }

    private static let defaultsKey = "AppleLanguages"
    private static let displayOrder = ["en", "ru", "es", "de", "fr", "pt-BR", "it", "zh-Hans", "ja", "ko", "hi", "ar"]

    /// Languages that actually ship in the bundle, each named in itself.
    static let options: [Option] = {
        let shipped = Set(Bundle.main.localizations)
        return displayOrder.filter(shipped.contains).map { code in
            let name = Locale(identifier: code).localizedString(forIdentifier: code) ?? code
            return Option(id: code, name: name.prefix(1).uppercased() + name.dropFirst())
        }
    }()

    /// The pinned language code, or an empty string when the app follows the system.
    static var pinned: String {
        guard let domain = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: domain)?[defaultsKey] as? [String]
        else { return "" }
        return languages.first ?? ""
    }

    static func pin(_ code: String) {
        if code.isEmpty {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } else {
            UserDefaults.standard.set([code], forKey: defaultsKey)
        }
    }

    /// Mirrors the whole interface for right-to-left languages such as Arabic.
    /// AppKit does not do this by itself when the language is chosen for this app only,
    /// so the direction is stored next to the language. Must run before the application object exists.
    static func applyLayoutDirection() {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let isRightToLeft = Locale.Language(identifier: code).characterDirection == .rightToLeft
        for key in ["AppleTextDirection", "NSForceRightToLeftWritingDirection"] {
            if isRightToLeft {
                UserDefaults.standard.set(true, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// macOS picks the language at launch, so a change needs a fresh start.
    static func relaunch() async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        _ = try? await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        NSApp.terminate(nil)
    }
}
