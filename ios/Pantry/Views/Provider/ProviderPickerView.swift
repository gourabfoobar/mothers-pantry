import SwiftUI

/// Canvas 2.1 "Choose provider" — data-driven from GET /providers (Swiggy
/// Instamart default, Kirana Now as the offline/demo fallback).
struct ProviderPickerView: View {
    @Binding var path: [OnboardingRoute]

    @State private var providers: [ProviderInfo] = []
    @State private var selectedId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(label: "Store") { path.removeLast() }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Where do you shop for Ma?")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Mother's Pantry orders through a grocery app you already use. Pick one — you can change it anytime.")
                        .font(.mono(14))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .wrapping()
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    VStack(spacing: 10) {
                        ForEach(providers) { provider in
                            providerRow(provider)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("All listed stores support secure MCP connections")
                }
                .font(.mono(13))
                .foregroundStyle(Theme.secondaryText)

                if let errorMessage {
                    Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 12) {
                Button {
                    if let provider = providers.first(where: { $0.id == selectedId }) {
                        path.append(.providerAuthorize(providerId: provider.id, providerName: provider.name))
                    }
                } label: {
                    Text(selectedId.flatMap { id in providers.first(where: { $0.id == id })?.name }.map { "Connect \($0)" } ?? "Connect")
                }
                .buttonStyle(.pantryPrimary(enabled: selectedId != nil))
                .disabled(selectedId == nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func providerRow(_ provider: ProviderInfo) -> some View {
        Button {
            if provider.available { selectedId = provider.id }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(provider.id == "swiggy" ? Color(hex: 0xFC8019) : Theme.ink)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(provider.name.first ?? "?"))
                            .font(.custom("Shippori Mincho", size: 20).weight(.bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(provider.name).font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                        if provider.isDefault {
                            Chip(text: "Recommended", background: Theme.paleAccent, foreground: Theme.accentText)
                        }
                    }
                    Text(provider.subtitle).font(.mono(13)).foregroundStyle(Theme.secondaryText)
                }
                Spacer()

                Circle()
                    .strokeBorder(selectedId == provider.id ? Theme.ink : Theme.border, lineWidth: selectedId == provider.id ? 1.5 : 1.5)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().fill(Theme.ink).frame(width: 12, height: 12)
                            .opacity(selectedId == provider.id ? 1 : 0)
                    )
            }
            .padding(16)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(selectedId == provider.id ? Theme.ink : Theme.border, lineWidth: selectedId == provider.id ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .opacity(provider.available ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!provider.available)
    }

    private func load() async {
        do {
            providers = try await APIClient.shared.providers()
            selectedId = providers.first(where: { $0.isDefault })?.id ?? providers.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { ProviderPickerView(path: .constant([])) }
}
