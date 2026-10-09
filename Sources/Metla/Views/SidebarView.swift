import SwiftUI

struct SidebarView: View {
    @Bindable var app: AppModel

    var body: some View {
        List(selection: $app.section) {
            Section {
                SidebarRow(kind: .overview, model: nil)
                    .tag(SectionKind.overview)
            }
            Section("Очистка") {
                ForEach(SectionKind.scannable) { kind in
                    SidebarRow(kind: kind, model: app.scans[kind])
                        .tag(kind)
                }
            }
            Section("Удаление") {
                SidebarRow(kind: .apps, model: nil)
                    .tag(SectionKind.apps)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                if !Sandbox.isActive {
                    CoffeeButton()
                }
                LanguageMenu()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Метла")
    }
}
