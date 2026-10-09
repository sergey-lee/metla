import SwiftUI

struct ResultsList: View {
    let model: ScanModel
    /// Groups whose expansion differs from the section's default.
    @State private var toggledGroups: Set<String> = []

    var body: some View {
        List {
            ForEach(model.groups) { group in
                if model.kind.isGrouped {
                    GroupHeaderRow(
                        group: group,
                        mark: mark(for: group),
                        isExpanded: isExpanded(group),
                        toggleSelection: { model.toggle(group) },
                        toggleExpansion: { toggleExpansion(of: group) }
                    )
                }
                if !model.kind.isGrouped || isExpanded(group) {
                    ForEach(group.items) { item in
                        ItemRow(
                            item: item,
                            isSelected: model.selection.contains(item.id),
                            isIndented: model.kind.isGrouped,
                            toggle: { model.toggle(item) }
                        )
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func isExpanded(_ group: ItemGroup) -> Bool {
        toggledGroups.contains(group.id) == model.kind.startsCollapsed
    }

    private func toggleExpansion(of group: ItemGroup) {
        if !toggledGroups.insert(group.id).inserted {
            toggledGroups.remove(group.id)
        }
    }

    private func mark(for group: ItemGroup) -> Checkbox.Mark {
        if model.isFullySelected(group) {
            .on
        } else if model.isPartlySelected(group) {
            .mixed
        } else {
            .off
        }
    }
}
