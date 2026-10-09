import SwiftUI

struct SidebarRow: View {
    let kind: SectionKind
    let model: ScanModel?

    var body: some View {
        HStack {
            Label(kind.title, systemImage: kind.symbol)
            Spacer()
            if let model {
                switch model.phase {
                case .scanning:
                    ProgressView()
                        .controlSize(.small)
                case .finished where model.totalSize > 0:
                    Text(Fmt.bytes(model.totalSize))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                case .finished, .idle:
                    EmptyView()
                }
            }
        }
    }
}
