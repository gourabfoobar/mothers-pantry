import SwiftUI

/// Canvas 3.5 "Review matches".
struct ReviewView: View {
    let listId: String
    @Binding var path: [AppRoute]

    @State private var review: Review?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var needsItems: [ReviewItem] { review?.items.filter { $0.status == "needs_match" || $0.status == "needs_qty" } ?? [] }
    private var matchedItems: [ReviewItem] { review?.items.filter { $0.status == "approved" } ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let review {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ScreenHeader(label: "3 / 3") { path.safePop() }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(review.itemCount) items found")
                                .font(.mono(28, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 6) {
                                Chip(text: "\(review.matchedCount) matched")
                                if review.needsCount - review.roundedDownCount > 0 {
                                    Chip(text: "\(review.needsCount - review.roundedDownCount) to check", background: Theme.paleAccent, foreground: Theme.accentText)
                                }
                                if review.roundedDownCount > 0 {
                                    Chip(text: "\(review.roundedDownCount) rounded down", background: Theme.chipNeutralAlt, foreground: Theme.chipNeutralText)
                                }
                            }
                        }

                        if !needsItems.isEmpty {
                            sectionHeader("Needs you · \(needsItems.count)", color: Theme.accentText)
                            VStack(spacing: 0) {
                                ForEach(needsItems) { item in needsRow(item) }
                            }
                        }

                        if !matchedItems.isEmpty {
                            sectionHeader("Matched · \(matchedItems.count)", color: Theme.secondaryText)
                            VStack(spacing: 0) {
                                ForEach(matchedItems) { item in matchedRow(item) }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Estimated total").font(.mono(14)).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text("₹ \(Int(review.total))").font(.mono(14, weight: .medium)).foregroundStyle(Theme.ink)
                    }
                    Button {
                        path.append(.checkoutFlow(listId: listId))
                    } label: {
                        Text(needsItems.isEmpty ? "Continue to checkout" : "Review \(needsItems.count) item\(needsItems.count == 1 ? "" : "s")")
                    }
                    .buttonStyle(.pantryAccent)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .background(Theme.card)
                .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
            } else if let errorMessage {
                Text(errorMessage).font(.mono(14)).foregroundStyle(Theme.accentText).padding()
            }
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func sectionHeader(_ text: String, color: Color) -> some View {
        Text(text.uppercased()).font(.mono(13)).tracking(1).foregroundStyle(color)
    }

    private func needsRow(_ item: ReviewItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(Theme.accent).frame(width: 8, height: 8).padding(.top, 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("\u{201c}\(item.rawText)\u{201d}").font(.mono(12)).foregroundStyle(Theme.secondaryText)
                Text(item.catalogItemName ?? item.rawText).font(.mono(15, weight: .medium)).foregroundStyle(Theme.ink)
                Chip(
                    text: item.status == "needs_qty" ? "Rounded down · \(formatQty(item.requestedQty)) → \(formatQty(item.approvedQty ?? 0)) \(item.requestedUnit)" : "Check match",
                    background: item.status == "needs_qty" ? Theme.chipNeutralAlt : Theme.paleAccent,
                    foreground: item.status == "needs_qty" ? Theme.chipNeutralText : Theme.accentText
                )
                .padding(.top, 2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let total = item.lineTotal { Text("₹ \(Int(total))").font(.mono(15)).foregroundStyle(Theme.ink) }
                if let pack = item.packDescription, !pack.isEmpty { Text(pack).font(.mono(12)).foregroundStyle(Theme.secondaryText) }
            }
        }
        .padding(.vertical, 13)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func matchedRow(_ item: ReviewItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.secondaryText).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\u{201c}\(item.rawText)\u{201d}").font(.mono(12)).foregroundStyle(Theme.secondaryText)
                Text(item.catalogItemName ?? item.rawText).font(.mono(15, weight: .medium)).foregroundStyle(Theme.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let total = item.lineTotal { Text("₹ \(Int(total))").font(.mono(15)).foregroundStyle(Theme.ink) }
                if let pack = item.packDescription, !pack.isEmpty { Text(pack).font(.mono(12)).foregroundStyle(Theme.secondaryText) }
            }
        }
        .padding(.vertical, 13)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func load() async {
        do {
            review = try await APIClient.shared.review(listId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { ReviewView(listId: "preview", path: .constant([])) }
}
