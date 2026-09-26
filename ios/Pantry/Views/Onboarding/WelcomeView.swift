import SwiftUI

/// Canvas 1.1 "Welcome".
struct WelcomeView: View {
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .phone:
                        PhoneView(path: $path)
                    case .otp(let phone):
                        OtpView(phone: phone, path: $path)
                    case .name(let phone):
                        NameView(phone: phone, path: $path)
                    case .providerPicker:
                        ProviderPickerView(path: $path)
                    case .providerAuthorize(let providerId, let providerName):
                        AuthorizeView(providerId: providerId, providerName: providerName, path: $path)
                    case .providerConnected:
                        ConnectedView()
                    }
                }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                Spacer().frame(height: 60)

                SealMark(size: 52)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mother's")
                        Text("Pantry")
                    }
                    .font(.mono(38, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    Text("Her list, your care — delivered to her door.")
                        .font(.mono(17))
                        .foregroundStyle(Theme.ink)
                        .wrapping()
                }

                Spacer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(heroMotif)

                VStack(alignment: .leading, spacing: 8) {
                    stepRow(number: "01", text: "Paste Ma's WhatsApp list")
                    stepRow(number: "02", text: "Approve what needs a second look")
                    stepRow(number: "03", text: "Follow it to her door, live")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 12) {
                Button {
                    path.append(.phone)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                        Text("Continue with phone number")
                    }
                }
                .buttonStyle(.pantryPrimary)

                Text("By continuing you agree to the Terms and Privacy Policy")
                    .font(.mono(12))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
    }

    private var heroMotif: some View {
        ZStack {
            EnsoMotif()
                .frame(width: 200, height: 200)
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    ForEach(Array("買い物"), id: \.self) { ch in
                        Text(String(ch))
                            .font(.custom("Shippori Mincho", size: 15))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.trailing, 8)
            }
            .frame(width: 220)
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.mono(14, weight: .bold))
                .foregroundStyle(Theme.accentText)
            Text(text)
                .font(.mono(14))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

#Preview {
    WelcomeView()
}
