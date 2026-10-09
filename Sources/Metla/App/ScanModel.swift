import Foundation
import Observation

/// State of one scan section: its results, the user's selection and the trash action.
@MainActor
@Observable
final class ScanModel {
    enum Phase {
        case idle
        case scanning
        case finished
    }

    let kind: SectionKind
    private(set) var phase = Phase.idle
    private(set) var status = ""
    private(set) var groups: [ItemGroup] = []
    private(set) var totalSize: Int64 = 0
    private(set) var itemCount = 0
    private(set) var isTrashing = false
    var selection: Set<String> = []
    var notice: String?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(kind: SectionKind) {
        self.kind = kind
    }

    var selectedItems: [FoundItem] {
        groups.flatMap(\.items).filter { selection.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    /// Duplicate sets in which every copy is selected, so nothing would remain.
    var fullySelectedDuplicateSets: Int {
        guard kind == .duplicates else { return 0 }
        return groups.count { group in group.items.allSatisfy { selection.contains($0.id) } }
    }

    // MARK: - Scanning

    func start(_ work: @escaping @Sendable (ProgressSink) async -> [ItemGroup]) {
        task?.cancel()
        generation += 1
        let current = generation
        apply([])
        phase = .scanning
        status = String(localized: "Подготовка…")
        notice = nil

        let sink = ProgressSink { [weak self] text in
            Task { @MainActor in
                guard let self, self.generation == current, self.phase == .scanning else { return }
                self.status = text
            }
        }
        task = Task {
            let result = await work(sink)
            guard !Task.isCancelled, generation == current else { return }
            apply(result)
            selection = Set(result.flatMap(\.items).filter(\.preselected).map(\.id))
            phase = .finished
        }
    }

    func cancel() {
        task?.cancel()
        generation += 1
        phase = .idle
    }

    func waitUntilFinished() async {
        await task?.value
    }

    // MARK: - Selection

    func toggle(_ item: FoundItem) {
        if !selection.insert(item.id).inserted {
            selection.remove(item.id)
        }
    }

    func isFullySelected(_ group: ItemGroup) -> Bool {
        group.items.allSatisfy { selection.contains($0.id) }
    }

    func isPartlySelected(_ group: ItemGroup) -> Bool {
        group.items.contains { selection.contains($0.id) }
    }

    func toggle(_ group: ItemGroup) {
        let ids = group.items.map(\.id)
        if isFullySelected(group) {
            selection.subtract(ids)
        } else {
            selection.formUnion(ids)
        }
    }

    func selectAll() {
        selection = Set(groups.flatMap(\.items).map(\.id))
    }

    func selectSafe() {
        selection = Set(groups.flatMap(\.items).filter(\.preselected).map(\.id))
    }

    /// In every duplicate set, selects everything except the likely original.
    func selectExtraCopies() {
        selection = Set(groups.flatMap { $0.items.dropFirst() }.map(\.id))
    }

    func clearSelection() {
        selection.removeAll()
    }

    // MARK: - Removal

    func trashSelected() async {
        let items = selectedItems
        guard !items.isEmpty, !isTrashing else { return }
        isTrashing = true
        let outcome = await Trasher.trash(items.map(\.url))
        isTrashing = false

        let freed = items.filter { outcome.trashed.contains($0.id) }.reduce(Int64(0)) { $0 + $1.size }
        var message = [String(localized: "В Корзину перемещено: \(Fmt.objects(outcome.trashed.count)), \(Fmt.bytes(freed)).")]
        if let first = outcome.failures.first {
            let name = URL(filePath: first.path).lastPathComponent
            message.append(String(localized: "Не удалось: \(Fmt.objects(outcome.failures.count)). «\(name)»: \(first.reason)"))
        } else {
            message.append(String(localized: "Место освободится после очистки Корзины."))
        }
        notice = message.joined(separator: " ")

        var remaining = groups
        for index in remaining.indices {
            remaining[index].items.removeAll { outcome.trashed.contains($0.id) }
        }
        // A duplicate set with a single file left is no longer a set of duplicates.
        let minimum = kind == .duplicates ? 2 : 1
        apply(remaining.filter { $0.items.count >= minimum })
        selection.subtract(outcome.trashed)
        selection.formIntersection(groups.flatMap(\.items).map(\.id))
    }

    private func apply(_ newGroups: [ItemGroup]) {
        groups = newGroups
        totalSize = newGroups.reduce(0) { $0 + $1.totalSize }
        itemCount = newGroups.reduce(0) { $0 + $1.items.count }
        if newGroups.isEmpty {
            selection.removeAll()
        }
    }
}
