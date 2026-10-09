import SwiftUI

/// Confirms removing an application and lets the user untick related files to keep.
struct UninstallSheet: View {
    let model: AppsModel
    let plan: UninstallPlan
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String>

    init(model: AppsModel, plan: UninstallPlan) {
        self.model = model
        self.plan = plan
        _selection = State(initialValue: Set(plan.related.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: plan.row.id))
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Удалить «\(plan.row.name)»?")
                        .font(.title3.bold())
                    Text("Приложение (\(Fmt.bytes(plan.row.size))) и отмеченные связанные файлы будут перемещены в Корзину.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if plan.related.isEmpty {
                Text("Связанных файлов в ~/Library не найдено.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(plan.related) { item in
                    ItemRow(item: item, isSelected: selection.contains(item.id), isIndented: false) {
                        toggle(item)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .clipShape(.rect(cornerRadius: 8))
            }

            HStack {
                Text("Освободится: \(Fmt.bytes(totalSize))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Отмена", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Переместить в Корзину", role: .destructive) {
                    let chosen = selection
                    Task {
                        await model.uninstall(plan, relatedSelection: chosen)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 640, height: 480)
    }

    private var totalSize: Int64 {
        plan.row.size + plan.related.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    private func toggle(_ item: FoundItem) {
        if !selection.insert(item.id).inserted {
            selection.remove(item.id)
        }
    }
}
