import SwiftUI

/// Canvas 6.3 "Account & connections".
struct AccountView: View {
    @Environment(AppState.self) private var appState

    @State private var profile: UserProfile?
    @State private var recipients: [Recipient] = []
    @State private var addresses: [DeliveryAddress] = []
    @State private var connection: ProviderConnectionInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    Circle().fill(Theme.ink).frame(width: 60, height: 60)
                        .overlay(Text(String((profile?.name ?? "?").first ?? "?")).font(.mono(26)).foregroundStyle(Theme.background))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile?.name ?? "").font(.mono(26, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(profile?.phone ?? "").font(.mono(14)).foregroundStyle(Theme.secondaryText)
                    }
                }

                section("Delivering for") {
                    row(icon: "person.crop.circle", title: "Recipients", subtitle: recipientsSummary)
                    divider()
                    row(icon: "mappin.circle", title: "Addresses", subtitle: addressesSummary)
                }

                section("Store") {
                    HStack(spacing: 14) {
                        Image(systemName: "link").foregroundStyle(Theme.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connection?.providerName ?? "Not connected").font(.mono(15)).foregroundStyle(Theme.ink)
                            Text(connection != nil ? "Connected via MCP" : "").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        if connection != nil {
                            Chip(text: "Connected", background: Theme.chipNeutralAlt, foreground: Theme.chipNeutralText)
                        }
                    }
                    .padding(.vertical, 15).padding(.horizontal, 18)
                }

                section("Preferences") {
                    row(icon: "shield", title: "Approvals & Live Activities", subtitle: "On · ask when a match is uncertain")
                    divider()
                    row(icon: "globe", title: "Ma's languages", subtitle: "Bengali · Hindi · English")
                }

                Button {
                    appState.signOut()
                } label: {
                    Text("Sign out").font(.mono(15)).foregroundStyle(Theme.accentText)
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private var recipientsSummary: String {
        guard let first = recipients.first else { return "None yet" }
        let extra = recipients.count - 1
        return "\(first.name)\(first.relation.map { " (\($0))" } ?? "")" + (extra > 0 ? " · +\(extra) more" : "")
    }

    private var addressesSummary: String {
        addresses.isEmpty ? "None yet" : addresses.map(\.label).joined(separator: " · ")
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText)
            VStack(spacing: 0, content: content)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Theme.ink).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mono(15)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.mono(13)).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 15).padding(.horizontal, 18)
    }

    private func divider() -> some View {
        Divider().background(Theme.border).padding(.horizontal, 18)
    }

    private func load() async {
        profile = try? await APIClient.shared.me()
        recipients = (try? await APIClient.shared.recipients()) ?? []
        addresses = (try? await APIClient.shared.addresses()) ?? []
        connection = try? await APIClient.shared.providerConnection()
    }
}

#Preview {
    NavigationStack { AccountView() }
        .environment(AppState())
}
