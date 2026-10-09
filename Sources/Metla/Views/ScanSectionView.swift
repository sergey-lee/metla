import SwiftUI

/// One cleanup section: header with options, results list and the selection bar.
struct ScanSectionView: View {
    let app: AppModel
    let model: ScanModel

    var body: some View {
        VStack(spacing: 0) {
            ScanHeader(model: model) {
                app.scan(model.kind)
            }
            Divider()
            if let notice = model.notice {
                NoticeBanner(text: notice) {
                    model.notice = nil
                }
            }
            ScanContent(model: model)
            if model.phase == .finished, !model.groups.isEmpty {
                Divider()
                SelectionBar(model: model)
            }
        }
        .navigationTitle(model.kind.title)
    }
}
