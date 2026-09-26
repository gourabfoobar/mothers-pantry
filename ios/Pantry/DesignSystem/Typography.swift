import SwiftUI

/// JetBrains Mono (variable font, registered as family "JetBrains Mono")
/// for all UI text, Shippori Mincho Bold for the 母 seal only.
extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }

    static let sealGlyph = Font.custom("Shippori Mincho", size: 20).weight(.bold)
}
