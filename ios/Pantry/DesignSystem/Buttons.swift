import SwiftUI

/// The dark filled CTA used on almost every screen: height 54, radius 16,
/// background #3A3A3A, text #F1F2ED.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(16, weight: .medium))
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isEnabled ? Theme.ink : Theme.ink.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The orange CTA used at the two money moments — Review's "Review N items"
/// and Checkout's "Place order".
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(16, weight: .medium))
            .foregroundStyle(Color(hex: 0x1F1F1F))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// The bordered "quiet" option — e.g. "Remove from list", "Try another brand".
struct SecondaryButtonStyle: ButtonStyle {
    var bordered: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(15, weight: .regular))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: bordered ? 50 : 54)
            .background(Theme.card.opacity(bordered ? 0 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(bordered ? Theme.border : .clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var pantryPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func pantryPrimary(enabled: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(isEnabled: enabled) }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static var pantryAccent: AccentButtonStyle { AccentButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var pantrySecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
