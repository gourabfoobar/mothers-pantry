import SwiftUI

/// Canvas 2.2 "Authorize connection".
struct AuthorizeView: View {
    let providerId: String
    let providerName: String
    @Binding var path: [OnboardingRoute]
    @Environment(\.openURL) private var openURL

    @State private var isWorking = false
    @State private var isWaitingInBrowser = false
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(label: "Connect") { path.safePop() }

                HStack(spacing: 14) {
                    SealMark(size: 56)
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle().fill(Theme.secondaryText.opacity(0.3 + Double(i % 3) * 0.2)).frame(width: 5, height: 5)
                        }
                    }
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(hex: 0x4A4A4A))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(String(providerName.first ?? "?"))
                                .font(.custom("Shippori Mincho", size: 31).weight(.bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                VStack(spacing: 10) {
                    Text("Connect to \(providerName)")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Mother's Pantry will be able to:")
                        .font(.mono(14))
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    permissionRow(icon: "magnifyingglass", text: "Search the catalogue and check stock")
                    permissionRow(icon: "cart", text: "Build and update a cart for you")
                    permissionRow(icon: "checkmark.circle", text: "Place orders — only after you approve")
                    permissionRow(icon: "shippingbox", text: "Read order status for live updates")
                }
                .padding(20)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                VStack(alignment: .leading, spacing: 6) {
                    Text("IT WILL NEVER").font(.mono(13, weight: .bold)).tracking(0.6).foregroundStyle(Theme.ink)
                    Text("Place an order without your tap · see your saved card or UPI details · share Ma's address beyond this store.")
                        .font(.mono(13))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .wrapping()
                }

                if isWaitingInBrowser {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Waiting for you to finish signing in on \(providerName)…")
                            .font(.mono(13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 12) {
                Button {
                    connect()
                } label: {
                    if isWorking {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Sign in on \(providerName)")
                    }
                }
                .buttonStyle(.pantryPrimary)
                .disabled(isWorking || isWaitingInBrowser)

                Text("Opens \(providerName)'s own sign-in page · revoke in Account")
                    .font(.mono(12))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .onDisappear { pollTask?.cancel() }
    }

    private func permissionRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.chipNeutralAlt).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(Color(hex: 0x4A4A4A))
            }
            Text(text).font(.mono(15)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func connect() {
        errorMessage = nil
        isWorking = true
        Task {
            do {
                if providerId == "swiggy" {
                    let started = try await APIClient.shared.startSwiggyAuthorize()
                    if let url = URL(string: started.authorizeUrl) {
                        openURL(url)
                    }
                    isWorking = false
                    isWaitingInBrowser = true
                    pollForConnection()
                } else {
                    _ = try await APIClient.shared.authorizeProvider(providerId)
                    isWorking = false
                    path.append(.providerConnected)
                }
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func pollForConnection() {
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<120 {
                if Task.isCancelled { return }
                if let connection = try? await APIClient.shared.providerConnection(), connection.providerId == providerId {
                    isWaitingInBrowser = false
                    path.append(.providerConnected)
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
            isWaitingInBrowser = false
            errorMessage = "Still waiting on \(providerName) — try again once you've finished signing in."
        }
    }
}

#Preview {
    NavigationStack { AuthorizeView(providerId: "swiggy", providerName: "Swiggy Instamart", path: .constant([])) }
}
