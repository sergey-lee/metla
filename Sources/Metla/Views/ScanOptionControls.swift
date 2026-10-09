import SwiftUI

/// The individual option controls of a section, without any layout of their own.
struct ScanOptionControls: View {
    let kind: SectionKind
    @AppStorage(SettingsKey.duplicateMinKB) private var duplicateMinKB = 1000
    @AppStorage(SettingsKey.largeMinMB) private var largeMinMB = 100
    @AppStorage(SettingsKey.largeIncludeLibrary) private var largeIncludeLibrary = true
    @AppStorage(SettingsKey.oldMonths) private var oldMonths = 12
    @AppStorage(SettingsKey.oldMinMB) private var oldMinMB = 10

    var body: some View {
        switch kind {
        case .duplicates:
            ScopePicker()
            Picker("Размер файла", selection: $duplicateMinKB) {
                Text("от \(Fmt.bytes(100_000))").tag(100)
                Text("от \(Fmt.bytes(1_000_000))").tag(1000)
                Text("от \(Fmt.bytes(10_000_000))").tag(10_000)
                Text("от \(Fmt.bytes(100_000_000))").tag(100_000)
            }
            .fixedSize()
        case .large:
            ScopePicker()
            Picker("Размер файла", selection: $largeMinMB) {
                Text("от \(Fmt.bytes(50_000_000))").tag(50)
                Text("от \(Fmt.bytes(100_000_000))").tag(100)
                Text("от \(Fmt.bytes(500_000_000))").tag(500)
                Text("от \(Fmt.bytes(1_000_000_000))").tag(1000)
            }
            .fixedSize()
            Toggle("Вместе с ~/Library и скрытыми папками", isOn: $largeIncludeLibrary)
                .fixedSize()
        case .old:
            ScopePicker()
            Picker("Не использовались", selection: $oldMonths) {
                Text("больше 6 месяцев").tag(6)
                Text("больше года").tag(12)
                Text("больше 2 лет").tag(24)
                Text("больше 3 лет").tag(36)
            }
            .fixedSize()
            Picker("Размер файла", selection: $oldMinMB) {
                Text("от \(Fmt.bytes(1_000_000))").tag(1)
                Text("от \(Fmt.bytes(10_000_000))").tag(10)
                Text("от \(Fmt.bytes(100_000_000))").tag(100)
            }
            .fixedSize()
        case .overview, .junk, .leftovers, .apps:
            EmptyView()
        }
    }
}
