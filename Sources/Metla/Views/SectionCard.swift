import SwiftUI

struct SectionCard: View {
    let kind: SectionKind
    let model: ScanModel
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kind.symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.headline)
                    switch model.phase {
                    case .idle:
                        Text("Не сканировалось")
                            .foregroundStyle(.secondary)
                    case .scanning:
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Сканирование…")
                                .foregroundStyle(.secondary)
                        }
                    case .finished:
                        Text(model.itemCount == 0 ? String(localized: "Чисто") : "\(Fmt.bytes(model.totalSize)) · \(Fmt.objects(model.itemCount))")
                            .monospacedDigit()
                            .foregroundStyle(model.itemCount == 0 ? .secondary : .primary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
