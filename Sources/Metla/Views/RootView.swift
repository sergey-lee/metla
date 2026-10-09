import SwiftUI

struct RootView: View {
    @Bindable var app: AppModel
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        NavigationSplitView {
            SidebarView(app: app)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            switch app.section ?? .overview {
            case .overview:
                OverviewView(app: app)
            case .apps:
                AppsView(model: app.apps)
            case let kind:
                if let model = app.scans[kind] {
                    ScanSectionView(app: app, model: model)
                        .id(kind)
                }
            }
        }
        .environment(app.access)
        .task {
            await app.refreshSystemFacts()
        }
        .onChange(of: appearsActive) {
            // The Trash and free space change behind our back, for example when Finder empties the Trash.
            if appearsActive {
                Task {
                    await app.refreshSystemFacts()
                }
            }
        }
    }
}
