import SwiftUI

/// Canvas 1.3 "Verify code".
struct OtpView: View {
    let phone: String
    @Binding var path: [OnboardingRoute]
    @Environment(AppState.self) private var appState

    @State private var code = ""
    @State private var secondsLeft = 30
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(label: "Sign in") { path.removeLast() }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter the code")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 4) {
                        Text("Sent to")
                        Text(phone).foregroundStyle(Theme.ink)
                        Text("· Change").foregroundStyle(Theme.accentText)
                            .onTapGesture { path.removeLast() }
                    }
                    .font(.mono(14))
                    .foregroundStyle(Theme.secondaryText)
                }

                codeBoxes

                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text(secondsLeft > 0 ? "Resend code in 0:\(String(format: "%02d", secondsLeft))" : "Resend code")
                        .onTapGesture { if secondsLeft == 0 { resend() } }
                }
                .font(.mono(14))
                .foregroundStyle(Theme.secondaryText)

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
                    verify()
                } label: {
                    if isVerifying {
                        ProgressView().tint(Theme.background)
                    } else {
                        Text("Verify")
                    }
                }
                .buttonStyle(.pantryPrimary(enabled: code.count == 6))
                .disabled(code.count != 6 || isVerifying)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .onReceive(timer) { _ in if secondsLeft > 0 { secondsLeft -= 1 } }
        .onAppear { focused = true }
    }

    private var codeBoxes: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let filled = i < code.count
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(filled ? Theme.ink : Theme.border, lineWidth: filled ? 2 : 1)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.card))
                        .frame(height: 64)
                        .overlay(
                            Text(i < code.count ? String(Array(code)[i]) : "")
                                .font(.mono(28))
                                .foregroundStyle(Theme.ink)
                        )
                }
            }
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter(\.isNumber).prefix(6))
                }
        }
    }

    private func verify() {
        errorMessage = nil
        isVerifying = true
        Task {
            do {
                let result = try await APIClient.shared.verifyOTP(phone: phone, code: code)
                isVerifying = false
                if result.isNewUser {
                    path.append(.name(phone: phone))
                } else {
                    let profile = try? await APIClient.shared.me()
                    appState.finishSignIn(profile: profile)
                }
            } catch {
                isVerifying = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resend() {
        secondsLeft = 30
        Task { _ = try? await APIClient.shared.requestOTP(phone: phone) }
    }
}

#Preview {
    NavigationStack { OtpView(phone: "+919830012321", path: .constant([])) }
        .environment(AppState())
}
