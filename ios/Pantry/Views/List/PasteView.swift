import SwiftUI

/// Canvas 3.3 "Paste Ma's list".
struct PasteView: View {
    let addressId: String
    @Binding var path: [AppRoute]

    @State private var text = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var lineCount: Int {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(label: "2 / 3") { path.safePop() }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Paste Ma's list")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Copy her message in WhatsApp and paste it here. Bengali or Hindi words typed in English are fine.")
                        .font(.mono(14))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(4)
                        .wrapping()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Message").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Button {
                            if let clip = UIPasteboard.general.string { text = clip }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste")
                            }
                            .font(.mono(13))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }

                    TextEditor(text: $text)
                        .font(.mono(15))
                        .foregroundStyle(Theme.ink)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(minHeight: 220)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.ink, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                    if lineCount > 0 {
                        HStack(spacing: 6) {
                            Chip(text: "\(lineCount) line\(lineCount == 1 ? "" : "s")")
                            Chip(text: "Bengali · Hindi · English", background: Theme.chipNeutralAlt, foreground: Theme.chipNeutralText)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle")
                    Text("To this address")
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
                    findItems()
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView().tint(Theme.background)
                        } else {
                            Image(systemName: "magnifyingglass")
                            Text("Find items")
                        }
                    }
                }
                .buttonStyle(.pantryPrimary(enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
    }

    private func findItems() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                let created = try await APIClient.shared.createList(addressId: addressId, rawText: text)
                isSubmitting = false
                path.append(.matching(listId: created.listId))
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { PasteView(addressId: "preview", path: .constant([])) }
}
