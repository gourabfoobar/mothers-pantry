import SwiftUI

/// SwiftUI's `Text` only wraps when it's given a real width to wrap against;
/// inside a hugging VStack it otherwise measures at its ideal single-line
/// width and truncates. Every multi-line paragraph in this app needs this.
struct WrappingText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func wrapping() -> some View { modifier(WrappingText()) }
}
