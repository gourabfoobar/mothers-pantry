import SwiftUI

/// Canvas 1.2 "Phone number".
struct PhoneView: View {
    @Binding var path: [OnboardingRoute]
    @State private var phone = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var fullPhone: String { "+91" + phone.filter(\.isNumber) }
    private var canSend: Bool { phone.filter(\.isNumber).count >= 10 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(label: "Sign in") { path.safePop() }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your phone number")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("We'll text a 6-digit code to confirm it's you. No password to remember.")
                        .font(.mono(14))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .wrapping()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mobile number")
                        .font(.mono(13))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text("+91")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .font(.mono(17))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 56)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                        TextField("98300 12321", text: $phone)
                            .keyboardType(.numberPad)
                            .font(.mono(19))
                            .tracking(1)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.ink, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(Color(hex: 0x4A4A4A))
                    Text("Your number is only used to sign in and to share with the delivery partner when you choose to.")
                        .font(.mono(13))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .wrapping()
                }
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.mono(13))
                        .foregroundStyle(Theme.accentText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 12) {
                Button {
                    send()
                } label: {
                    if isSending {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Send code")
                    }
                }
                .buttonStyle(.pantryPrimary(enabled: canSend))
                .disabled(!canSend || isSending)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
    }

    private func send() {
        errorMessage = nil
        isSending = true
        Task {
            do {
                _ = try await APIClient.shared.requestOTP(phone: fullPhone)
                isSending = false
                path.append(.otp(phone: fullPhone))
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { PhoneView(path: .constant([])) }
}
