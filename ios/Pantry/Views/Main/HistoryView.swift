import SwiftUI

/// Canvas 6.1 "Order history".
struct HistoryView: View {
    @Binding var path: [AppRoute]

    @State private var orders: [OrderSummary] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HISTORY").font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText)
                    Text("Orders").font(.mono(30, weight: .semibold)).foregroundStyle(Theme.ink)
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if orders.isEmpty {
                    Text("No orders yet — start Ma's first list from Home.")
                        .font(.mono(14)).foregroundStyle(Theme.secondaryText)
                        .padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedByMonth, id: \.month) { group in
                            Text(group.month.uppercased())
                                .font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText)
                                .padding(.top, 12).padding(.bottom, 4)
                            ForEach(group.orders) { order in
                                orderRow(order)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func orderRow(_ order: OrderSummary) -> some View {
        Button {
            if order.status == "delivered" {
                path.append(.orderDetail(orderId: order.id))
            } else {
                path.append(.tracking(orderId: order.id))
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate(order.placedAt)).font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                    Text("\(order.itemCount) items · \(order.addressLabel)").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("₹ \(Int(order.total))").font(.mono(15)).foregroundStyle(Theme.ink)
                    Chip(
                        text: order.status == "delivered" ? "Delivered" : "On the way",
                        background: order.status == "delivered" ? Theme.chipNeutral : Theme.paleAccent,
                        foreground: order.status == "delivered" ? Theme.ink : Theme.accentText
                    )
                }
                Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
            }
            .padding(.vertical, 16)
            .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }

    private struct MonthGroup { let month: String; let orders: [OrderSummary] }

    private var groupedByMonth: [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var order: [String] = []
        var buckets: [String: [OrderSummary]] = [:]
        for o in orders {
            let month = o.placedAt.asISODate.map { formatter.string(from: $0) } ?? "Earlier"
            if buckets[month] == nil { order.append(month) }
            buckets[month, default: []].append(o)
        }
        return order.map { MonthGroup(month: $0, orders: buckets[$0] ?? []) }
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = iso.asISODate else { return iso }
        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter(); f.dateFormat = "'Today ·' d MMM"
            return f.string(from: date)
        }
        let f = DateFormatter(); f.dateFormat = "d MMMM"
        return f.string(from: date)
    }

    private func load() async {
        orders = (try? await APIClient.shared.orders()) ?? []
        isLoading = false
    }
}

#Preview {
    NavigationStack { HistoryView(path: .constant([])) }
}
