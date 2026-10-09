import SwiftUI

struct OverviewView: View {
    let app: AppModel

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Метла")
                            .font(.largeTitle.bold())
                        Text("Находит лишнее на диске. Всё удаляется только после вашего подтверждения и только в Корзину.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if app.isScanning {
                        Button("Остановить", systemImage: "stop.fill", action: app.cancelAll)
                            .controlSize(.large)
                            .fixedSize()
                    } else {
                        Button("Сканировать всё", systemImage: "sparkle.magnifyingglass", action: app.scanAll)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .fixedSize()
                    }
                }

                if let disk = app.disk {
                    DiskCard(disk: disk, found: app.totalFound)
                }
                if !app.access.hasHomeAccess {
                    AccessRequestCard(notice: app.access.notice) {
                        _ = app.access.ensureHome()
                    }
                }
                if !app.hasFullDiskAccess {
                    AccessBanner(openSettings: app.openFullDiskAccessSettings)
                }
                if let notice = app.trashNotice {
                    NoticeBanner(text: notice) {
                        app.trashNotice = nil
                    }
                    .clipShape(.rect(cornerRadius: 10))
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(SectionKind.scannable) { kind in
                        if let model = app.scans[kind] {
                            SectionCard(kind: kind, model: model) {
                                app.section = kind
                            }
                        }
                    }
                    TrashCard(size: app.trashSize, isEmptying: app.isEmptyingTrash) {
                        Task {
                            await app.emptyTrash()
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Обзор")
        .task {
            await app.refreshSystemFacts()
        }
    }
}
