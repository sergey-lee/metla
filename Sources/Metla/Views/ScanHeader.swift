import SwiftUI

/// Section description, its options and the scan button.
struct ScanHeader: View {
    let model: ScanModel
    let scan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                Text(model.kind.blurb)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.phase == .scanning {
                    Button("Остановить", systemImage: "stop.fill", action: model.cancel)
                        .fixedSize()
                } else {
                    Button(model.phase == .idle ? "Сканировать" : "Сканировать заново", systemImage: "magnifyingglass", action: scan)
                        .buttonStyle(.borderedProminent)
                        .fixedSize()
                }
            }
            ScanOptionsView(kind: model.kind)
        }
        .padding(16)
    }
}
