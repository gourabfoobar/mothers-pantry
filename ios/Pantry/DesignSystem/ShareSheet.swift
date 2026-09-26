import SwiftUI

/// Thin wrapper so "Tell Ma on WhatsApp" can hand off to the system share
/// sheet (WhatsApp included) instead of guessing at WhatsApp's URL scheme.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
