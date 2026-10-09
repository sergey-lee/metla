import SwiftUI

/// A checkbox that can also show the "some of the children are selected" state.
struct Checkbox: View {
    enum Mark {
        case off
        case on
        case mixed
    }

    let mark: Mark
    let label: String
    let action: () -> Void

    var body: some View {
        Button(label, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.title3)
            .foregroundStyle(mark == .off ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(.isToggle)
    }

    private var symbol: String {
        switch mark {
        case .off: "square"
        case .on: "checkmark.square.fill"
        case .mixed: "minus.square.fill"
        }
    }

    private var accessibilityValue: String {
        switch mark {
        case .off: String(localized: "не выбрано")
        case .on: String(localized: "выбрано")
        case .mixed: String(localized: "выбрано частично")
        }
    }
}
