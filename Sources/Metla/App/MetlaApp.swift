import SwiftUI

struct MetlaApp: App {
    @State private var model: AppModel
    private let options: LaunchOptions

    init() {
        let options = LaunchOptions()
        self.options = options
        _model = State(initialValue: AppModel(environment: options.environment, rootOverride: options.root))
    }

    var body: some Scene {
        Window("Метла", id: "main") {
            RootView(app: model)
                .frame(minWidth: 880, minHeight: 540)
                .environment(\.locale, Fmt.locale)
                .task {
                    if let folder = options.snapshotFolder {
                        await SnapshotRunner.run(app: model, folder: folder, windowSize: options.windowSize)
                    }
                }
        }
        .defaultSize(width: 1060, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Сканирование") {
                Button("Сканировать всё", action: model.scanAll)
                    .keyboardShortcut("r")
                Button("Остановить", action: model.cancelAll)
                    .keyboardShortcut(".")
                    .disabled(!model.isScanning)
            }
        }
    }
}
