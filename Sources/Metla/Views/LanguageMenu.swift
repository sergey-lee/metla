import SwiftUI

/// Lets the user pin the interface language for this app, independent of the system language.
struct LanguageMenu: View {
    @State private var selection = AppLanguage.pinned
    @State private var isAskingToRelaunch = false

    var body: some View {
        Menu {
            Picker("Язык", selection: $selection) {
                Text("Как в системе")
                    .tag("")
                ForEach(AppLanguage.options) { option in
                    Text(verbatim: option.name)
                        .tag(option.id)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Язык", systemImage: "globe")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onChange(of: selection) {
            AppLanguage.pin(selection)
            isAskingToRelaunch = true
        }
        .alert("Перезапустить «Метлу»?", isPresented: $isAskingToRelaunch) {
            Button("Перезапустить") {
                Task {
                    await AppLanguage.relaunch()
                }
            }
            Button("Позже", role: .cancel) {}
        } message: {
            Text("Язык интерфейса сменится после перезапуска.")
        }
    }
}
