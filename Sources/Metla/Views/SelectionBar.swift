import SwiftUI

struct SelectionBar: View {
    let model: ScanModel
    @State private var isConfirming = false

    var body: some View {
        let selected = model.selectedItems
        let size = selected.reduce(Int64(0)) { $0 + $1.size }

        HStack(spacing: 12) {
            Menu("Выбор") {
                Button("Выбрать всё", action: model.selectAll)
                if model.kind == .junk {
                    Button("Только безопасное", action: model.selectSafe)
                }
                if model.kind == .duplicates {
                    Button("Все копии, кроме оригинала", action: model.selectExtraCopies)
                }
                Divider()
                Button("Снять выбор", action: model.clearSelection)
            }
            .fixedSize()

            Text(selected.isEmpty ? "Ничего не выбрано" : "Выбрано: \(Fmt.objects(selected.count)), \(Fmt.bytes(size))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            if model.isTrashing {
                ProgressView()
                    .controlSize(.small)
            }
            Button("Переместить в Корзину", systemImage: "trash", role: .destructive) {
                isConfirming = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selected.isEmpty || model.isTrashing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .confirmationDialog(
            "Переместить в Корзину: \(Fmt.objects(selected.count)), \(Fmt.bytes(size))?",
            isPresented: $isConfirming
        ) {
            Button("Переместить в Корзину", role: .destructive) {
                Task {
                    await model.trashSelected()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }

    private var confirmationMessage: String {
        var message = [String(localized: "Файлы останутся в Корзине, и их можно будет вернуть, пока она не очищена.")]
        let emptied = model.fullySelectedDuplicateSets
        if emptied > 0 {
            message.append(String(localized: "Внимание: в \(emptied) наборах дубликатов выбраны все копии — не останется ни одной."))
        }
        return message.joined(separator: " ")
    }
}
