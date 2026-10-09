import SwiftUI

/// Thresholds for the sections that have any. Changes apply to the next scan.
/// The controls sit in one row when the window is wide enough and stack otherwise.
struct ScanOptionsView: View {
    let kind: SectionKind

    var body: some View {
        if kind == .duplicates || kind == .large || kind == .old {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    ScanOptionControls(kind: kind)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ScanOptionControls(kind: kind)
                }
            }
        }
    }
}
