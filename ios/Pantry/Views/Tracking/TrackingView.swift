import SwiftUI

/// Canvas 5.3 "Track order in app".
struct TrackingView: View {
    let orderId: String
    @Binding var path: [AppRoute]

    @State private var order: OrderDetail?
    @State private var isLoading = true
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let order {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ScreenHeader(label: order.id) { path.safePop() }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(statusHeadline(order.status).uppercased())
                                .font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText)
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                Text(order.etaAt.map(formatTime) ?? "—")
                                    .font(.mono(52, weight: .semibold)).foregroundStyle(Theme.ink)
                            }
                            Text(subheadline(order))
                                .font(.mono(14)).foregroundStyle(Theme.secondaryText)
                                .wrapping()
                        }

                        TimelineView(order: order)

                        HStack(spacing: 10) {
                            callButton(title: "Call \(order.courierName ?? "Rider")")
                            callButton(title: "Call Ma")
                        }

                        Button {
                            path.append(.orderDetail(orderId: order.id))
                        } label: {
                            HStack {
                                Text("\(order.items.count) items · ₹ \(Int(order.total))").font(.mono(15)).foregroundStyle(Theme.ink)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("Details").font(.mono(14)).foregroundStyle(Theme.secondaryText)
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .padding(16)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
        .onAppear { startAutoRefresh() }
        .onDisappear { refreshTask?.cancel() }
    }

    private func callButton(title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "phone")
            Text(title)
        }
        .font(.mono(15))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.ink, lineWidth: 1))
    }

    private func statusHeadline(_ status: String) -> String {
        switch status {
        case "placed": "Order placed"
        case "packed": "Being packed"
        case "on_the_way": "On the way · arriving"
        case "delivered": "Delivered"
        default: status
        }
    }

    private func subheadline(_ order: OrderDetail) -> String {
        if order.status == "delivered" { return "Delivered to \(order.addressLabel)." }
        if order.status == "on_the_way", let courier = order.courierName {
            let distance = order.courierDistanceKm.map { " \(String(format: "%.1f", $0)) km away." } ?? "."
            return "\(courier) picked up Ma's order and is\(distance)"
        }
        return "Kirana Now is preparing Ma's order."
    }

    private func formatTime(_ iso: String) -> String {
        guard let date = iso.asISODate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let ampm = DateFormatter()
        ampm.dateFormat = "a"
        return "\(formatter.string(from: date)) \(ampm.string(from: date).lowercased())"
    }

    private func load() async {
        order = try? await APIClient.shared.order(orderId)
        isLoading = false
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
                await load()
            }
        }
    }
}

private struct TimelineView: View {
    let order: OrderDetail

    private var stageIndex: Int {
        switch order.status {
        case "placed": 0
        case "packed": 1
        case "on_the_way": 2
        default: 4
        }
    }

    private struct Row { let label: String; let time: String?; let index: Int }

    private var rows: [Row] {
        func eventTime(_ type: String) -> String? {
            order.events.first(where: { $0.type == type }).map { formatShortTime($0.at) }
        }
        return [
            Row(label: "Order placed", time: eventTime("placed"), index: 0),
            Row(label: "Packed at the store", time: eventTime("packed"), index: 1),
            Row(label: "Picked up by \(order.courierName ?? "rider")", time: eventTime("on_the_way"), index: 2),
            Row(label: "Arriving at \(order.addressLabel)", time: order.status == "on_the_way" ? "~ \(order.etaAt.map(formatShortTime) ?? "")" : nil, index: 3),
            Row(label: "Delivered", time: eventTime("delivered"), index: 4),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 4) {
                        dot(for: row.index)
                        if i < rows.count - 1 {
                            Rectangle().fill(row.index <= stageIndex ? Theme.ink : Theme.border).frame(width: 1.5)
                        }
                    }
                    .frame(width: 20)

                    HStack {
                        Text(row.label)
                            .font(.mono(15, weight: row.index == stageIndex ? .bold : .regular))
                            .foregroundStyle(row.index <= stageIndex ? Theme.ink : Theme.secondaryText)
                        Spacer()
                        if let time = row.time {
                            Text(time).font(.mono(13)).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(.top, -3)
                }
                .frame(minHeight: i == rows.count - 1 ? 24 : 54)
            }
        }
    }

    @ViewBuilder private func dot(for index: Int) -> some View {
        if index == stageIndex {
            Circle().fill(Theme.paleAccent).frame(width: 20, height: 20)
                .overlay(Circle().fill(Theme.accent).frame(width: 10, height: 10))
        } else if index < stageIndex {
            Circle().fill(Theme.ink).frame(width: 12, height: 12)
        } else {
            Circle().strokeBorder(Theme.secondaryText, lineWidth: 1.5).frame(width: 12, height: 12)
        }
    }
}

private func formatShortTime(_ iso: String) -> String {
    guard let date = iso.asISODate else { return "" }
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date).lowercased()
}

#Preview {
    NavigationStack { TrackingView(orderId: "MP-2481", path: .constant([])) }
}
