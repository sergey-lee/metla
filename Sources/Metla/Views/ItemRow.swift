import SwiftUI

struct ItemRow: View {
    let item: FoundItem
    let isSelected: Bool
    let isIndented: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Checkbox(mark: isSelected ? .on : .off, label: String(localized: "Выбрать \(item.title)"), action: toggle)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.id))
                .resizable()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Fmt.tilde(item.url.deletingLastPathComponent().path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                if let note = item.note {
                    Label(note, systemImage: item.safety.symbol)
                        .font(.caption)
                        .foregroundStyle(item.safety.color)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            if let date = item.date {
                Text(Fmt.date(date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(Fmt.bytes(item.size))
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
            Button("Показать в Finder", systemImage: "magnifyingglass") {
                FileActions.reveal(item.url)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Показать в Finder")
        }
        .padding(.leading, isIndented ? 28 : 0)
        .padding(.vertical, 3)
        .contentShape(.rect)
        .onTapGesture(perform: toggle)
        .contextMenu {
            Button("Показать в Finder", systemImage: "magnifyingglass") {
                FileActions.reveal(item.url)
            }
            Button("Открыть", systemImage: "arrow.up.forward.app") {
                FileActions.open(item.url)
            }
            Button("Скопировать путь", systemImage: "doc.on.clipboard") {
                FileActions.copyPath(item.url)
            }
        }
    }
}
