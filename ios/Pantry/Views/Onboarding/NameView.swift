import SwiftUI

/// Canvas 1.4 "About you".
struct NameView: View {
    let phone: String
    @Binding var path: [OnboardingRoute]

    @State private var name = ""
    @State private var email = ""
    @State private var notificationsEnabled = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(label: "Almost there") { path.safePop() }

                VStack(alignment: .leading, spacing: 10) {
                    Text("What should we call you?")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Ma will see this name in the order updates you share with her.")
                        .font(.mono(14))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .wrapping()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                    TextField("", text: $name)
                        .font(.mono(18))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.ink, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Email for receipts").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                        Text("(optional)").font(.mono(13)).foregroundStyle(Theme.secondaryText.opacity(0.8))
                    }
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .font(.mono(17))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }

                Button {
                    notificationsEnabled.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: notificationsEnabled ? "checkmark.square.fill" : "square")
                            .foregroundStyle(Theme.ink)
                        Text("Allow notifications — needed to approve items and follow deliveries on the Lock Screen.")
                            .font(.mono(14))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .wrapping()
                    }
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 12) {
                Button {
                    save()
                } label: {
                    if isSaving { ProgressView().tint(Theme.background) } else { Text("Continue") }
                }
                .buttonStyle(.pantryPrimary(enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                _ = try await APIClient.shared.updateProfile(
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email.isEmpty ? nil : email,
                    notificationsEnabled: notificationsEnabled
                )
                if notificationsEnabled {
                    await NotificationService.requestAuthorization()
                }
                isSaving = false
                path.append(.providerPicker)
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { NameView(phone: "+919830012321", path: .constant([])) }
}
