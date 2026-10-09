import Foundation

/// Lets a background scanner report what it is doing.
struct ProgressSink: Sendable {
    let send: @Sendable (String) -> Void

    static let silent = ProgressSink { _ in }
}
