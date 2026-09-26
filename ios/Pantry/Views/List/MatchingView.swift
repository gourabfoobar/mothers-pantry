import SwiftUI

/// Canvas 3.4 "Matching" — a loading screen while the backend parses,
/// searches and allocates every line against the connected provider.
struct MatchingView: View {
    let listId: String
    @Binding var path: [AppRoute]

    @State private var stepsShown = 1
    @State private var errorMessage: String?

    private let steps = [
        "Reading Ma's message",
        "Matching names against the catalogue",
        "Checking stock at the store",
        "Choosing the closest pack sizes",
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                ScreenHeader(label: "3 / 3", onBack: nil)

                VStack(spacing: 26) {
                    ZStack {
                        EnsoMotif().frame(width: 170, height: 170)
                        ProgressView()
                    }
                    VStack(spacing: 8) {
                        Text("Finding the closest matches")
                            .font(.mono(24, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Talking to the store. This takes a few seconds.")
                            .font(.mono(14))
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(i < stepsShown ? Theme.ink : Color.clear)
                                    .strokeBorder(i < stepsShown ? Theme.ink : Theme.border, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if i < stepsShown {
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.background)
                                }
                            }
                            Text(steps[i]).font(.mono(15)).foregroundStyle(i < stepsShown ? Theme.ink : Theme.secondaryText)
                        }
                    }
                }
                .padding(20)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                if let errorMessage {
                    Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .frame(maxHeight: .infinity, alignment: .top)

            Text("You can leave — we'll notify you if anything needs you")
                .font(.mono(14))
                .foregroundStyle(Theme.secondaryText)
                .padding(.bottom, 36)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await run() }
    }

    private func run() async {
        let stepTimer = Task {
            for i in 2...steps.count {
                try? await Task.sleep(for: .seconds(0.6))
                if Task.isCancelled { return }
                stepsShown = i
            }
        }
        let minimumDisplay = Task { try? await Task.sleep(for: .seconds(1.4)) }

        do {
            _ = try await APIClient.shared.matchList(listId)
            _ = await minimumDisplay.value
            stepTimer.cancel()
            path.safePop()
            path.append(.review(listId: listId))
        } catch {
            stepTimer.cancel()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { MatchingView(listId: "preview", path: .constant([])) }
}
