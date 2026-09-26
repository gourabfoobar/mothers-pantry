import SwiftUI

/// Switches between the sign-up flow and the signed-in app. Home (3.1) lands
/// in milestone 8; until then a signed-in session shows a placeholder.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        #if DEBUG
        if let debugScreen = ProcessInfo.processInfo.environment["PANTRY_DEBUG_SCREEN"] {
            DebugScreenHost(screen: debugScreen)
        } else {
            signedInSwitch
        }
        #else
        signedInSwitch
        #endif
    }

    @ViewBuilder private var signedInSwitch: some View {
        if appState.isSignedIn {
            MainShellView()
        } else {
            WelcomeView()
        }
    }
}

#Preview {
    RootView().environment(AppState())
}
