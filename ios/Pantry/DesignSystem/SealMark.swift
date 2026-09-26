import SwiftUI

/// The 母 ("mother") seal — the app's brand mark. Used at several sizes:
/// 32pt in the Home header, 52-64pt on welcome/connect/placed screens.
struct SealMark: View {
    var size: CGFloat = 52
    var cornerRadius: CGFloat? = nil
    var background: Color = Theme.accent
    var foreground: Color = .white

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.135, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay(
                Text("母")
                    .font(.custom("Shippori Mincho", size: size * 0.56).weight(.bold))
                    .foregroundStyle(foreground)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        SealMark(size: 32)
        SealMark(size: 52)
        SealMark(size: 64)
    }
    .padding()
    .background(Theme.background)
}
