import SwiftUI

#if DEBUG
/// Jumps straight to a named screen when launched with
/// `SIMCTL_CHILD_PANTRY_DEBUG_SCREEN=<name>` — a fast way to screenshot one
/// screen deep in a flow without scripting UI taps. Debug-only, never
/// compiled into a release build.
struct DebugScreenHost: View {
    let screen: String
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            resolvedScreen
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .phone: PhoneView(path: $path)
                    case .otp(let phone): OtpView(phone: phone, path: $path)
                    case .name(let phone): NameView(phone: phone, path: $path)
                    case .providerPicker: ComingSoonView(title: "Choose provider", milestone: 7)
                    }
                }
        }
    }

    @ViewBuilder private var resolvedScreen: some View {
        switch screen {
        case "Welcome": WelcomeView()
        case "Phone": PhoneView(path: $path)
        case "Otp": OtpView(phone: "+919830012321", path: $path)
        case "Name": NameView(phone: "+919830012321", path: $path)
        default: Text("Unknown debug screen: \(screen)")
        }
    }
}
#endif
