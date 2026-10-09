import SwiftUI

/// Installed applications with size and last launch date, and an uninstaller that also takes related files.
struct AppsView: View {
    @Bindable var model: AppsModel
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Text(SectionKind.apps.blurb)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.isLoading || model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Удалить…", systemImage: "trash", role: .destructive) {
                    uninstall(selectedID)
                }
                .disabled(selectedID == nil || model.isWorking)
                .fixedSize()
            }
            .padding(16)
            Divider()
            if let notice = model.notice {
                NoticeBanner(text: notice) {
                    model.notice = nil
                }
            }
            Table(model.visibleRows, selection: $selectedID, sortOrder: $model.sortOrder) {
                TableColumn("Приложение", value: \.name) { row in
                    AppNameCell(row: row)
                }
                TableColumn("Размер", value: \.size) { row in
                    Text(row.size > 0 ? Fmt.bytes(row.size) : "—")
                        .monospacedDigit()
                }
                .width(min: 80, ideal: 110, max: 140)
                TableColumn("Последний запуск", value: \.lastUsedKey) { row in
                    LastUsedCell(date: row.lastUsed)
                }
                .width(min: 150, ideal: 220)
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let row = model.row(with: ids.first) {
                    Button("Удалить…", systemImage: "trash", role: .destructive) {
                        uninstall(row.id)
                    }
                    Button("Показать в Finder", systemImage: "magnifyingglass") {
                        FileActions.reveal(row.app.url)
                    }
                }
            }
            .onChange(of: model.sortOrder) {
                model.sort()
            }
        }
        .navigationTitle(SectionKind.apps.title)
        .searchable(text: $model.query, prompt: "Поиск приложений")
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .sheet(item: $model.plan) { plan in
            UninstallSheet(model: model, plan: plan)
        }
    }

    private func uninstall(_ id: String?) {
        guard let row = model.row(with: id) else { return }
        Task {
            await model.prepareUninstall(row)
        }
    }
}
