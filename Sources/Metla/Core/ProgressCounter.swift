import Synchronization

/// Thread-safe "done so far" counter for parallel work.
final class ProgressCounter: Sendable {
    let total: Int
    private let done = Mutex(0)

    init(total: Int = 0) {
        self.total = total
    }

    /// Returns the new value.
    func increment() -> Int {
        add(1)
    }

    /// Returns the new value.
    func add(_ amount: Int) -> Int {
        done.withLock { value in
            value += amount
            return value
        }
    }
}
