import SwiftUI

struct GroupHeaderRow: View {
    let group: ItemGroup
    let mark: Checkbox.Mark
    let isExpanded: Bool
    let toggleSelection: () -> Void
    let toggleExpansion: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Checkbox(mark: mark, label: String(localized: "Выбрать всё в «\(group.title)»"), action: toggleSelection)
            Button(isExpanded ? "Свернуть" : "Развернуть", systemImage: "chevron.forward", action: toggleExpansion)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
            Image(systemName: group.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle = group.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            Text(Fmt.objects(group.items.count))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(Fmt.bytes(group.totalSize))
                .font(.headline)
                .monospacedDigit()
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .contentShape(.rect)
        .onTapGesture(perform: toggleExpansion)
    }
}
