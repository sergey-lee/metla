import SwiftUI
import UniformTypeIdentifiers

/// Chooses the folder that duplicate, large-file and old-file scans look through.
struct ScopePicker: View {
    @Environment(FolderAccess.self) private var access
    @AppStorage(SettingsKey.scanRoot) private var scanRoot = ""
    @State private var isChoosing = false

    var body: some View {
        Menu {
            Button("Домашняя папка") {
                scanRoot = ""
            }
            Button("Выбрать папку…") {
                isChoosing = true
            }
        } label: {
            Label(scanRoot.isEmpty ? String(localized: "Домашняя папка") : Fmt.tilde(scanRoot), systemImage: "folder")
        }
        .fixedSize()
        .help("Где искать")
        .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                access.rememberScanRoot(url)
                scanRoot = url.path
            }
        }
    }
}
