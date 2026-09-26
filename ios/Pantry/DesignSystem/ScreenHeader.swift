import SwiftUI

/// The back-chevron / small-caps label / spacer row repeated at the top of
/// almost every screen (Phone, Otp, Name, Provider, Authorize, Address,
/// Paste, Matching, Review, Checkout, Tracking...).
struct ScreenHeader: View {
    var label: String
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: { onBack?() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .opacity(onBack == nil ? 0 : 1)
            .disabled(onBack == nil)

            Spacer()
            Text(label.uppercased())
                .font(.mono(13))
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryText)
            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.leading, -10)
        .frame(height: 44)
    }
}

/// A reusable "chip" — the small pill badges used everywhere for counts and
/// statuses ("12 items", "Check match", "Delivered"...).
struct Chip: View {
    var text: String
    var background: Color = Theme.chipNeutral
    var foreground: Color = Theme.ink

    var body: some View {
        Text(text)
            .font(.mono(12, weight: .medium))
            .tracking(0.3)
            .foregroundStyle(foreground)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(background)
            .clipShape(Capsule())
    }
}
