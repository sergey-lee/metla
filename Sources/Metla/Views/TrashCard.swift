import SwiftUI

struct TrashCard: View {
    let size: Int64?
    let isEmptying: Bool
    let empty: () -> Void
    @State private var isConfirming = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trash")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Корзина")
                    .font(.headline)
                Text(sizeText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isEmptying {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Очистить") {
                    isConfirming = true
                }
                .disabled(size == 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        .confirmationDialog("Очистить Корзину?", isPresented: $isConfirming) {
            Button("Очистить Корзину", role: .destructive, action: empty)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Всё содержимое Корзины будет удалено навсегда. Это действие нельзя отменить.")
        }
    }

    private var sizeText: String {
        guard let size else { return String(localized: "Размер скрыт без полного доступа") }
        return size == 0 ? String(localized: "Пусто") : Fmt.bytes(size)
    }
}
