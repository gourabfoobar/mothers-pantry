import SwiftUI

/// Canvas 6.2 "Order detail".
struct OrderDetailView: View {
    let orderId: String
    @Binding var path: [AppRoute]

    @State private var order: OrderDetail?
    @State private var showAllItems = false
    @State private var isLoading = true
    @State private var isReordering = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let order {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ScreenHeader(label: order.id) { path.safePop() }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(formatDate(order.placedAt)).font(.mono(28, weight: .semibold)).foregroundStyle(Theme.ink)
                            HStack(spacing: 8) {
                                Chip(text: order.status == "delivered" ? "Delivered \(order.etaAt.map(formatTime) ?? "")" : "On the way")
                                Text("to \(order.addressLabel)").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                            }
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(visibleItems) { item in itemRow(item) }
                            if order.items.count > 5 && !showAllItems {
                                Button { showAllItems = true } label: {
                                    Text("Show all \(order.items.count) items").font(.mono(14)).foregroundStyle(Theme.ink)
                                }
                                .padding(.vertical, 12)
                            }
                        }

                        HStack(alignment: .lastTextBaseline) {
                            Text("Paid").font(.mono(15)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("₹ \(Int(order.total))").font(.mono(22, weight: .semibold)).foregroundStyle(Theme.ink)
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        reorder()
                    } label: {
                        if isReordering {
                            ProgressView().tint(Theme.background)
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise")
                                Text("Reorder this list")
                            }
                        }
                    }
                    .buttonStyle(.pantryPrimary)
                    .disabled(isReordering)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private var visibleItems: [ReviewItem] {
        showAllItems ? order?.items ?? [] : Array((order?.items ?? []).prefix(5))
    }

    private func itemRow(_ item: ReviewItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\u{201c}\(item.rawText)\u{201d}").font(.mono(12)).foregroundStyle(Theme.secondaryText)
                Text(item.catalogItemName ?? item.rawText).font(.mono(15)).foregroundStyle(Theme.ink)
                if item.roundedDown, let approved = item.approvedQty {
                    Text("Rounded down \(formatQty(item.requestedQty)) → \(formatQty(approved)) \(item.requestedUnit) · you approved")
                        .font(.mono(12)).foregroundStyle(Color(hex: 0x4A4A4A))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let total = item.lineTotal { Text("₹ \(Int(total))").font(.mono(15)).foregroundStyle(Theme.ink) }
                if let pack = item.packDescription, !pack.isEmpty {
                    Text(pack).font(.mono(12)).foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
    }

    private func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = iso.asISODate else { return iso }
        let f = DateFormatter(); f.dateFormat = "d MMMM"
        return f.string(from: date)
    }

    private func formatTime(_ iso: String) -> String {
        guard let date = iso.asISODate else { return "" }
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: date).lowercased()
    }

    private func load() async {
        order = try? await APIClient.shared.order(orderId)
        isLoading = false
    }

    private func reorder() {
        errorMessage = nil
        isReordering = true
        Task {
            do {
                let result = try await APIClient.shared.reorder(orderId)
                isReordering = false
                path.append(.review(listId: result.listId))
            } catch {
                isReordering = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { OrderDetailView(orderId: "MP-2417", path: .constant([])) }
}
