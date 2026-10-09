import Foundation

enum NameNormalizer {
    /// Lowercased letters and digits only: "Google Chrome" → "googlechrome".
    static func normalize(_ name: String) -> String {
        String(String.UnicodeScalarView(name.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }))
    }
}
