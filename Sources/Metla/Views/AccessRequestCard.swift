import SwiftUI

/// Shown in the App Store build until the user lets the app read their home folder.
struct AccessRequestCard: View {
    let notice: String?
    let grant: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Нужен доступ к домашней папке")
                    .font(.headline)
                Text("macOS разрешает приложениям из App Store читать только те папки, которые вы выбрали сами. Нажмите «Разрешить доступ» и подтвердите домашнюю папку в открывшемся окне. Ничего не удаляется без вашего подтверждения.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let notice {
                    Text(notice)
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Разрешить доступ", action: grant)
                .buttonStyle(.borderedProminent)
                .fixedSize()
        }
        .padding(16)
        .background(.tint.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}
