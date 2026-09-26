import SwiftUI

/// Exact palette from the design canvas — never approximate these.
enum Theme {
    static let background = Color(hex: 0xF1F2ED)
    static let card = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x3A3A3A)
    static let secondaryText = Color(hex: 0x6B6D6F)
    static let border = Color(hex: 0xE4E4DF)
    static let accent = Color(hex: 0xEE6F22)
    static let accentText = Color(hex: 0xB4531A)
    static let paleAccent = Color(hex: 0xFFE3D1)
    static let chipNeutral = Color(hex: 0xE6E6E2)
    static let chipNeutralAlt = Color(hex: 0xE9E9E6)
    static let chipNeutralText = Color(hex: 0x4A4A4A)

    /// The dark surface used for Lock Screen / notification mockups (4.1, 5.1, 5.2).
    static let darkSurface = Color(hex: 0x1F1F1F)
    static let darkInk = Color(hex: 0xF1F2ED)

    static let radius: CGFloat = 16
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
