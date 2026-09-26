import SwiftUI

/// Placeholder for a flow step not yet built — replaced as each milestone
/// lands (currently just row 02, "Connect a grocery provider" — milestone 7).
struct ComingSoonView: View {
    var title: String
    var milestone: Int

    var body: some View {
        VStack(spacing: 16) {
            SealMark(size: 52)
            Text(title)
                .font(.mono(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Lands in milestone \(milestone).")
                .font(.mono(14))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationBarHidden(true)
    }
}
