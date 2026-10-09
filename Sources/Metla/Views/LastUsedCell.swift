import SwiftUI

struct LastUsedCell: View {
    let date: Date?

    var body: some View {
        if let date {
            HStack(spacing: 6) {
                Text(Fmt.date(date))
                if isStale(date) {
                    Text("давно не запускалось")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: .capsule)
                }
            }
        } else {
            Text("нет данных")
                .foregroundStyle(.tertiary)
        }
    }

    private func isStale(_ date: Date) -> Bool {
        date < Date.now.addingTimeInterval(-180 * 86_400)
    }
}
