import SwiftUI

/// The body of a section: a prompt, progress, an empty state or the results.
struct ScanContent: View {
    let model: ScanModel

    var body: some View {
        switch model.phase {
        case .idle:
            ContentUnavailableView {
                Label(model.kind.title, systemImage: model.kind.symbol)
            } description: {
                Text("Нажмите «Сканировать». Ничего не удаляется, пока вы сами не выберете файлы и не подтвердите.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning:
            VStack(spacing: 14) {
                ProgressView()
                Text(model.status)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .finished where model.groups.isEmpty:
            ContentUnavailableView(
                "Ничего не найдено",
                systemImage: "checkmark.circle",
                description: Text("В этом разделе чисто.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .finished:
            ResultsList(model: model)
        }
    }
}
