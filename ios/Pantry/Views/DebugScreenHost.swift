import SwiftUI

#if DEBUG
/// Jumps straight to a named screen when launched with
/// `SIMCTL_CHILD_PANTRY_DEBUG_SCREEN=<name>` — a fast way to screenshot one
/// screen deep in a flow without scripting UI taps. Debug-only, never
/// compiled into a release build.
///
/// Set `SIMCTL_CHILD_PANTRY_DEBUG_AUTOLOGIN=1` alongside it to run a real
/// OTP sign-in first; `PANTRY_DEBUG_CONNECT_KIRANA=1` to also connect
/// kirana-now; `PANTRY_DEBUG_SEED_ADDRESS=1` to create a recipient+address;
/// `PANTRY_DEBUG_SEED_LIST=1` to also create and match Ma's sample list —
/// so screens deep in the list-building flow have real data to show.
struct DebugScreenHost: View {
    let screen: String
    @State private var path: [AppRoute] = []
    @State private var ready = ProcessInfo.processInfo.environment["PANTRY_DEBUG_AUTOLOGIN"] != "1"
    @State private var seededAddressId: String?
    @State private var seededListId: String?

    var body: some View {
        Group {
            if ready {
                NavigationStack(path: $path) {
                    resolvedScreen
                        .navigationDestination(for: OnboardingRoute.self) { onboardingDestination($0) }
                        .navigationDestination(for: AppRoute.self) { appDestination($0) }
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
        case "Phone": PhoneView(path: onboardingPath)
        case "Otp": OtpView(phone: "+919830012321", path: onboardingPath)
        case "Name": NameView(phone: "+919830012321", path: onboardingPath)
        case "ProviderPicker": ProviderPickerView(path: onboardingPath)
        case "Authorize": AuthorizeView(providerId: "swiggy", providerName: "Swiggy Instamart", path: onboardingPath)
        case "AuthorizeKirana": AuthorizeView(providerId: "kirana-now", providerName: "Kirana Now", path: onboardingPath)
        case "Connected": ConnectedView()
        case "Home": MainShellView()
        case "Address": AddressView(path: $path)
        case "Paste": PasteView(addressId: seededAddressId ?? "missing-address", path: $path)
        case "Matching": MatchingView(listId: seededListId ?? "missing-list", path: $path)
        case "Review": ReviewView(listId: seededListId ?? "missing-list", path: $path)
        default: Text("Unknown debug screen: \(screen)")
        }
    }

    // A throwaway OnboardingRoute path — those screens push within their own
    // stack in the real app, but the debug host only needs to render one.
    private var onboardingPath: Binding<[OnboardingRoute]> { .constant([]) }

    @ViewBuilder private func onboardingDestination(_ route: OnboardingRoute) -> some View {
        EmptyView()
    }

    @ViewBuilder private func appDestination(_ route: AppRoute) -> some View {
        switch route {
        case .address: AddressView(path: $path)
        case .paste(let addressId): PasteView(addressId: addressId, path: $path)
        case .matching(let listId): MatchingView(listId: listId, path: $path)
        case .review(let listId): ReviewView(listId: listId, path: $path)
        case .orderDetail: ComingSoonView(title: "Order detail", milestone: 11)
        case .checkoutFlow: ComingSoonView(title: "Approvals & checkout", milestone: 9)
        }
    }

    private func autoLogin() async {
        do {
            let phone = "+91" + String(format: "%010d", Int.random(in: 6_000_000_000...9_999_999_999))
            let requested = try await APIClient.shared.requestOTP(phone: phone)
            guard let code = requested.devCode else { return }
            _ = try await APIClient.shared.verifyOTP(phone: phone, code: code)
            _ = try? await APIClient.shared.updateProfile(name: "Gourab", email: nil, notificationsEnabled: true)

            let env = ProcessInfo.processInfo.environment
            if env["PANTRY_DEBUG_CONNECT_KIRANA"] == "1" {
                _ = try? await APIClient.shared.authorizeProvider("kirana-now")
            }
            if env["PANTRY_DEBUG_SEED_ADDRESS"] == "1" || env["PANTRY_DEBUG_SEED_LIST"] == "1" {
                let recipient = try? await APIClient.shared.createRecipient(name: "Mita Ghosh", relation: "Ma", phone: "+919830012345")
                let address = try? await APIClient.shared.createAddress(
                    recipientId: recipient?.id, label: "Ma's home", line1: "12B Hindusthan Park", city: "Kolkata", pincode: "700029"
                )
                seededAddressId = address?.id
                if env["PANTRY_DEBUG_SEED_LIST"] == "1", let addressId = address?.id {
                    let sample = "Babu ei list ta order kore dis\nAtta 5 kg\nChini 1 kg\nDhoniya pata 2 bundle\nAloo 3 kg\nPeyaj 2 kg\nSorsher tel 1 litre\nMusur dal 1 kg\nHaldi 200 gm\nKalo jeera 100 gm\nDoi 500 gm\nKacha lanka 100 gm\nPosto 100 gm"
                    let created = try? await APIClient.shared.createList(addressId: addressId, rawText: sample)
                    seededListId = created?.listId
                    if let listId = seededListId {
                        _ = try? await APIClient.shared.matchList(listId)
                    }
                }
            }
        } catch {
            NSLog("[debug autologin] failed: \(error)")
        }
        ready = true
    }
}
#endif
