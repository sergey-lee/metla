import Foundation

/// How confident we are that an item can be removed without consequences.
enum Safety: Int, Sendable, Comparable {
    case safe
    case review
    case caution

    static func < (lhs: Safety, rhs: Safety) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var symbol: String {
        switch self {
        case .safe: "checkmark.shield"
        case .review: "eye"
        case .caution: "exclamationmark.triangle"
        }
    }
}
