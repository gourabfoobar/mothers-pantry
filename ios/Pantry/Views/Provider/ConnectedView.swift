import SwiftUI

/// Canvas 2.3 "Connected".
struct ConnectedView: View {
    @Environment(AppState.self) private var appState

    @State private var connection: ProviderConnectionInfo?
    @State private var phone: String = ""
    @State private var isFinishing = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                VStack(spacing: 28) {
                    ZStack {
                        EnsoMotif().frame(width: 180, height: 180)
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.accentText)
                    }
                    VStack(spacing: 10) {
                        Text("\(connection?.providerName ?? "Store") is connected")
                            .font(.mono(26, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("Ma's lists will be matched against this store's catalogue and stock.")
                            .font(.mono(14))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .wrapping()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

                VStack(spacing: 0) {
                    infoRow(label: "Account", value: phone)
                    Divider().background(Theme.border)
                    infoRow(label: "Nearest store", value: connection?.storeName ?? "—")
                    Divider().background(Theme.border)
                    infoRow(label: "Payment", value: "Handled in \(connection?.providerName ?? "the store app")")
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 12) {
                Button {
                    finish()
                } label: {
                    if isFinishing { ProgressView().tint(Theme.background) } else { Text("Start Ma's first list") }
                }
                .buttonStyle(.pantryPrimary)
                .disabled(isFinishing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.mono(14)).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).font(.mono(14)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func load() async {
        connection = try? await APIClient.shared.providerConnection()
        if let profile = try? await APIClient.shared.me() {
            phone = profile.phone
        }
    }

    private func finish() {
        isFinishing = true
        Task {
            let profile = try? await APIClient.shared.me()
            isFinishing = false
            appState.finishSignIn(profile: profile)
        }
    }
}

#Preview {
    NavigationStack { ConnectedView() }
        .environment(AppState())
}
