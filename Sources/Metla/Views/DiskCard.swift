import SwiftUI

struct DiskCard: View {
    let disk: DiskInfo
    let found: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(disk.name, systemImage: "internaldrive")
                    .font(.headline)
                Spacer()
                Text("Свободно \(Fmt.bytes(disk.available)) из \(Fmt.bytes(disk.total))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(disk.used), total: Double(max(disk.total, 1)))
                .tint(fillColor)
                .accessibilityLabel("Занято на диске")
            if found > 0 {
                Text("Найдено для возможной очистки: \(Fmt.bytes(found))")
                    .font(.callout)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
    }

    private var fillColor: Color {
        let share = Double(disk.used) / Double(max(disk.total, 1))
        return share > 0.9 ? .red : share > 0.75 ? .orange : .accentColor
    }
}
