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
/// `PANTRY_DEBUG_SEED_LIST=1` to also create and match Ma's sample list;
/// `PANTRY_DEBUG_SEED_ORDER=1` to additionally resolve every approval and
/// place the order — so screens deep in the flow have real data to show.
struct DebugScreenHost: View {
    let screen: String
    @State private var path: [AppRoute] = []
    @State private var ready = ProcessInfo.processInfo.environment["PANTRY_DEBUG_AUTOLOGIN"] != "1"
    @State private var seededAddressId: String?
    @State private var seededListId: String?
    @State private var seededOrderId: String?

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
        case "Approvals": ApprovalsCoordinatorView(listId: seededListId ?? "missing-list", path: $path)
        case "Checkout": CheckoutView(listId: seededListId ?? "missing-list", path: $path)
        case "Placed": PlacedView(orderId: seededOrderId ?? "missing-order", path: $path)
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
        case .tracking: ComingSoonView(title: "Track order", milestone: 10)
        case .approvals(let listId): ApprovalsCoordinatorView(listId: listId, path: $path)
        case .checkout(let listId): CheckoutView(listId: listId, path: $path)
        case .placed(let orderId): PlacedView(orderId: orderId, path: $path)
        }
    }

    private func autoLogin() async {
        do {
            NSLog("[debug autologin] start")
            let phone = "+91" + String(format: "%010d", Int.random(in: 6_000_000_000...9_999_999_999))
            let requested = try await APIClient.shared.requestOTP(phone: phone)
            NSLog("[debug autologin] otp requested")
            guard let code = requested.devCode else { return }
            _ = try await APIClient.shared.verifyOTP(phone: phone, code: code)
            NSLog("[debug autologin] otp verified")
            _ = try? await APIClient.shared.updateProfile(name: "Gourab", email: nil, notificationsEnabled: true)
            NSLog("[debug autologin] profile updated")

            let env = ProcessInfo.processInfo.environment
            if env["PANTRY_DEBUG_CONNECT_KIRANA"] == "1" {
                _ = try? await APIClient.shared.authorizeProvider("kirana-now")
                NSLog("[debug autologin] kirana connected")
            }
            if env["PANTRY_DEBUG_SEED_ADDRESS"] == "1" || env["PANTRY_DEBUG_SEED_LIST"] == "1" {
                let recipient = try? await APIClient.shared.createRecipient(name: "Mita Ghosh", relation: "Ma", phone: "+919830012345")
                NSLog("[debug autologin] recipient created: \(recipient?.id ?? "nil")")
                let address = try? await APIClient.shared.createAddress(
                    recipientId: recipient?.id, label: "Ma's home", line1: "12B Hindusthan Park", city: "Kolkata", pincode: "700029"
                )
                NSLog("[debug autologin] address created: \(address?.id ?? "nil")")
                seededAddressId = address?.id
                if env["PANTRY_DEBUG_SEED_LIST"] == "1", let addressId = address?.id {
                    let sample = env["PANTRY_DEBUG_KALO_FIRST"] == "1"
                        ? "Kalo jeera 100 gm\nChini 1 kg\nAloo 3 kg"
                        : "Babu ei list ta order kore dis\nAtta 5 kg\nChini 1 kg\nDhoniya pata 2 bundle\nAloo 3 kg\nPeyaj 2 kg\nSorsher tel 1 litre\nMusur dal 1 kg\nHaldi 200 gm\nKalo jeera 100 gm\nDoi 500 gm\nKacha lanka 100 gm\nPosto 100 gm"
                    let created = try? await APIClient.shared.createList(addressId: addressId, rawText: sample)
                    NSLog("[debug autologin] list created: \(created?.listId ?? "nil")")
                    seededListId = created?.listId
                    if let listId = seededListId {
                        _ = try? await APIClient.shared.matchList(listId)
                        NSLog("[debug autologin] list matched")
                        if env["PANTRY_DEBUG_SEED_ORDER"] == "1" {
                            await resolveAllApprovals(listId: listId)
                            NSLog("[debug autologin] approvals resolved")
                            if let order = try? await APIClient.shared.placeOrder(listId: listId) {
                                seededOrderId = order.id
                                NSLog("[debug autologin] order placed: \(order.id)")
                            } else {
                                NSLog("[debug autologin] placeOrder FAILED")
                            }
                        }
                    }
                }
            }
        } catch {
            NSLog("[debug autologin] failed: \(error)")
        }
        NSLog("[debug autologin] done, ready=true")
        ready = true
    }

    /// Approves every needs-you item with its top candidate / rounded-down
    /// qty, so a seeded order can reach checkout without UI interaction.
    private func resolveAllApprovals(listId: String) async {
        for i in 0..<20 {
            guard let review = try? await APIClient.shared.review(listId) else { return }
            let pending = review.items.filter { $0.status == "needs_match" || $0.status == "needs_qty" }
            guard let item = pending.first else {
                NSLog("[debug autologin] resolveAllApprovals: nothing pending at iteration \(i)")
                return
            }
            NSLog("[debug autologin] resolving \(item.rawText) (\(item.status)) at iteration \(i)")
            if item.status == "needs_qty" {
                _ = try? await APIClient.shared.approveQty(orderItemId: item.id)
            } else {
                _ = try? await APIClient.shared.approveMatch(orderItemId: item.id, catalogItemId: item.candidates.first?.catalogItemId)
            }
        }
    }
}
#endif
