import SwiftUI

/// Canvas 3.1 "Home".
struct HomeView: View {
    @Binding var path: [AppRoute]
    var onAccountTap: () -> Void = {}

    @State private var userName = ""
    @State private var providerName = ""
    @State private var activeOrder: OrderSummary?
    @State private var recentOrders: [OrderSummary] = []
    @State private var isLoading = true

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    HStack(spacing: 10) {
                        SealMark(size: 32, cornerRadius: 4)
                        Text("via \(providerName.isEmpty ? "your store" : providerName)")
                            .font(.mono(13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Button(action: onAccountTap) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting.uppercased() + (userName.isEmpty ? "" : ", \(userName)"))
                        .font(.mono(13))
                        .tracking(1)
                        .foregroundStyle(Theme.secondaryText)
                    Text("Ma's pantry")
                        .font(.mono(30, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }

                Button {
                    path.append(.address)
                } label: {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            Text("A new list\nfrom Ma?")
                                .font(.mono(22))
                                .foregroundStyle(Theme.background)
                                .lineSpacing(4)
                            Spacer()
                            ZStack {
                                Circle().fill(Theme.accent).frame(width: 44, height: 44)
                                Image(systemName: "plus").foregroundStyle(Color(hex: 0x1F1F1F)).font(.system(size: 18, weight: .semibold))
                            }
                        }
                        Text("Paste her WhatsApp message. We'll find every item and ask only when unsure.")
                            .font(.mono(14))
                            .foregroundStyle(Color(hex: 0xD6D6D2))
                            .lineSpacing(4)
                            .wrapping()
                    }
                    .padding(24)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }
                .buttonStyle(.plain)

                if let activeOrder {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ON THE WAY").font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText)
                        Button {
                            path.append(.tracking(orderId: activeOrder.id))
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Theme.chipNeutralAlt).frame(width: 40, height: 40)
                                    Image(systemName: "shippingbox").foregroundStyle(Color(hex: 0x4A4A4A))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(activeOrder.etaAt.map(formatETA) ?? "On the way")
                                        .font(.mono(15, weight: .medium)).foregroundStyle(Theme.ink)
                                    Text("\(activeOrder.itemCount) items · to \(activeOrder.addressLabel)")
                                        .font(.mono(13)).foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
                            }
                            .padding(16)
                            .background(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !recentOrders.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("RECENT").font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText).padding(.bottom, 8)
                        ForEach(recentOrders) { order in
                            Button {
                                path.append(.orderDetail(orderId: order.id))
                            } label: {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(formatDate(order.placedAt)).font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                                        Text("\(order.itemCount) items · \(order.addressLabel)").font(.mono(13)).foregroundStyle(Theme.secondaryText)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 6) {
                                        Text("₹ \(Int(order.total))").font(.mono(15)).foregroundStyle(Theme.ink)
                                        Chip(text: order.status.capitalized, background: Theme.chipNeutral)
                                    }
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
                                }
                                .padding(.vertical, 16)
                                .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
                            }
                            .buttonStyle(.plain)
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

    private func formatETA(_ iso: String) -> String {
        guard let date = iso.asISODate else { return "Arriving soon" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Arriving \(formatter.string(from: date))"
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = iso.asISODate else { return iso }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private func load() async {
        if let profile = try? await APIClient.shared.me() {
            userName = profile.name ?? ""
        }
        if let connection = try? await APIClient.shared.providerConnection() {
            providerName = connection.providerName
        }
        if let orders = try? await APIClient.shared.orders() {
            activeOrder = orders.first(where: { $0.status != "delivered" })
            recentOrders = orders.filter { $0.status == "delivered" }
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { HomeView(path: .constant([])) }
}
