import SwiftUI

/// Explains why some folders are skipped until the user grants Full Disk Access.
struct AccessBanner: View {
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Нет полного доступа к диску")
                    .font(.headline)
                Text("Без него macOS не показывает Корзину, данные Почты, резервные копии устройств и контейнеры некоторых приложений. Остальное сканируется как обычно. Чтобы включить, добавьте «Метлу» в Системных настройках и перезапустите её.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Открыть настройки", action: openSettings)
                .fixedSize()
        }
        .padding(16)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}
