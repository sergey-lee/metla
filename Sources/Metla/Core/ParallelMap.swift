import Foundation

/// Runs `transform` over `items` with at most `limit` running at once. Results keep the input order;
/// items skipped because of cancellation are `nil`.
@concurrent
func parallelMap<Input: Sendable, Output: Sendable>(
    _ items: [Input],
    limit: Int,
    _ transform: @escaping @Sendable (Input) async -> Output
) async -> [Output?] {
    await withTaskGroup(of: (Int, Output).self) { group in
        var results = [Output?](repeating: nil, count: items.count)
        var next = 0
        while next < min(limit, items.count) {
            let index = next
            group.addTask { (index, await transform(items[index])) }
            next += 1
        }
        while let (index, output) = await group.next() {
            results[index] = output
            if next < items.count, !Task.isCancelled {
                let upcoming = next
                group.addTask { (upcoming, await transform(items[upcoming])) }
                next += 1
            }
        }
        return results
    }
}
