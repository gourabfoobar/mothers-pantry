import SwiftUI

#if DEBUG
/// Jumps straight to a named screen when launched with
/// `SIMCTL_CHILD_PANTRY_DEBUG_SCREEN=<name>` — a fast way to screenshot one
/// screen deep in a flow without scripting UI taps. Debug-only, never
/// compiled into a release build.
///
/// Set `SIMCTL_CHILD_PANTRY_DEBUG_AUTOLOGIN=1` alongside it to run a real
/// OTP sign-in against the backend first, so screens that need a session
/// (Provider, Connected, and everything from milestone 8 on) have one.
struct DebugScreenHost: View {
    let screen: String
    @State private var path: [OnboardingRoute] = []
    @State private var ready = ProcessInfo.processInfo.environment["PANTRY_DEBUG_AUTOLOGIN"] != "1"

    var body: some View {
        Group {
            if ready {
                NavigationStack(path: $path) {
                    resolvedScreen
                        .navigationDestination(for: OnboardingRoute.self) { route in
                            switch route {
                            case .phone: PhoneView(path: $path)
                            case .otp(let phone): OtpView(phone: phone, path: $path)
                            case .name(let phone): NameView(phone: phone, path: $path)
                            case .providerPicker: ProviderPickerView(path: $path)
                            case .providerAuthorize(let providerId, let providerName):
                                AuthorizeView(providerId: providerId, providerName: providerName, path: $path)
                            case .providerConnected: ConnectedView()
                            }
                        }
                }
            } else {
                ProgressView("Signing in…")
            }
        }
        .environment(AppState())
        .task { if !ready { await autoLogin() } }
    }

    @ViewBuilder private var resolvedScreen: some View {
        switch screen {
        case "Welcome": WelcomeView()
        case "Phone": PhoneView(path: $path)
        case "Otp": OtpView(phone: "+919830012321", path: $path)
        case "Name": NameView(phone: "+919830012321", path: $path)
        case "ProviderPicker": ProviderPickerView(path: $path)
        case "Authorize": AuthorizeView(providerId: "swiggy", providerName: "Swiggy Instamart", path: $path)
        case "AuthorizeKirana": AuthorizeView(providerId: "kirana-now", providerName: "Kirana Now", path: $path)
        case "Connected": ConnectedView()
        default: Text("Unknown debug screen: \(screen)")
        }
    }

    private func autoLogin() async {
        do {
            let phone = "+91" + String(format: "%010d", Int.random(in: 6_000_000_000...9_999_999_999))
            let requested = try await APIClient.shared.requestOTP(phone: phone)
            guard let code = requested.devCode else { return }
            _ = try await APIClient.shared.verifyOTP(phone: phone, code: code)
            _ = try? await APIClient.shared.updateProfile(name: "Gourab", email: nil, notificationsEnabled: true)
            let flag = ProcessInfo.processInfo.environment["PANTRY_DEBUG_CONNECT_KIRANA"]
            NSLog("[debug autologin] PANTRY_DEBUG_CONNECT_KIRANA=\(flag ?? "nil")")
            if flag == "1" {
                do {
                    let connection = try await APIClient.shared.authorizeProvider("kirana-now")
                    NSLog("[debug autologin] connected: \(connection.storeName)")
                } catch {
                    NSLog("[debug autologin] connect FAILED: \(error)")
                }
            }
        } catch {
            print("[debug autologin] failed: \(error)")
        }
        ready = true
    }
}
#endif
