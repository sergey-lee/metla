import SwiftUI

/// "Buy me a coffee": opens the sponsor page in the browser.
/// Not shown in the Mac App Store build, where external payment links are not allowed.
struct CoffeeButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = Links.buyMeACoffee {
                openURL(url)
            }
        } label: {
            Label {
                Text("Угостить кофе")
                    .font(.callout.weight(.semibold))
            } icon: {
                Text(verbatim: "☕")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.22), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(.orange.opacity(0.4))
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
