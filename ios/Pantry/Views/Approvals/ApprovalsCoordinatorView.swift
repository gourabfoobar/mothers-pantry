import SwiftUI

/// Cycles through every item that needs a look (canvas 4.2/4.3), presented
/// as sheets over this screen — which just re-shows Review dimmed behind,
/// matching the canvas's "blurred content + bottom sheet" look for free.
struct ApprovalsCoordinatorView: View {
    let listId: String
    @Binding var path: [AppRoute]

    @State private var review: Review?
    @State private var totalNeedsCount = 0
    @State private var isLoading = true

    private var pendingItems: [ReviewItem] {
        review?.items.filter { $0.status == "needs_match" || $0.status == "needs_qty" } ?? []
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if isLoading {
                ProgressView()
            } else {
                // A dimmed echo of Review's content behind the sheet, like the canvas.
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3).fill(Theme.border.opacity(0.7))
                            .frame(width: [0.6, 0.8, 0.45, 0.7, 0.55][i] * 300, height: 14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 110)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Color.black.opacity(0.42).ignoresSafeArea()
            }
        }
        .navigationBarHidden(true)
        .task { await load(isFirstLoad: true) }
        .sheet(item: currentItemBinding) { item in
            let position = max(1, totalNeedsCount - pendingItems.count + 1)
            if item.status == "needs_qty" {
                ApproveQtySheet(item: item, index: position, total: totalNeedsCount, onResolved: advance)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            } else {
                ApproveMatchSheet(item: item, index: position, total: totalNeedsCount, onResolved: advance)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    /// `.sheet(item:)` wants an Identifiable binding; nil means "no sheet",
    /// and dismissing without resolving (swipe-down) just pops back to Review.
    private var currentItemBinding: Binding<ReviewItem?> {
        Binding(
            get: { pendingItems.first },
            set: { if $0 == nil { path.safePop() } }
        )
    }

    private func advance() {
        Task {
            await load(isFirstLoad: false)
            if pendingItems.isEmpty {
                path.safePop()
                path.append(.checkout(listId: listId))
            }
            // else: currentItemBinding recomputes from the refreshed review and
            // the sheet re-presents the next pending item automatically.
        }
    }

    private func load(isFirstLoad: Bool) async {
        review = try? await APIClient.shared.review(listId)
        if isFirstLoad { totalNeedsCount = pendingItems.count }
        isLoading = false
    }
}

#Preview {
    NavigationStack { ApprovalsCoordinatorView(listId: "preview", path: .constant([])) }
}
