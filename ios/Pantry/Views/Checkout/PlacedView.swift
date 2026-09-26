import SwiftUI

/// Canvas 4.5 "Order placed".
struct PlacedView: View {
    let orderId: String
    @Binding var path: [AppRoute]

    @State private var order: OrderDetail?
    @State private var providerName = ""
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                ZStack {
                    EnsoMotif().frame(width: 200, height: 200)
                    SealMark(size: 64)
                }

                VStack(spacing: 10) {
                    Text("Order \(orderId)").font(.mono(13)).tracking(0.6).foregroundStyle(Theme.secondaryText)
                    Text("Order placed").font(.mono(32, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("\(providerName.isEmpty ? "The store" : providerName) is packing Ma's groceries.\n\(etaText)")
                        .font(.mono(14))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                    Text("Live updates are on your Lock Screen")
                }
                .font(.mono(13))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 54)

            VStack(spacing: 10) {
                Button {
                    path.append(.tracking(orderId: orderId))
                } label: {
                    Text("Track order")
                }
                .buttonStyle(.pantryPrimary)

                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "message")
                        Text("Tell Ma on WhatsApp")
                    }
                    .font(.mono(16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.ink, lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareText])
        }
    }

    private var etaText: String {
        guard let iso = order?.etaAt, let date = iso.asISODate else { return "Arriving today." }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Arriving today, \(formatter.string(from: date))."
    }

    private var shareText: String {
        "Ma, your order is on its way from \(providerName.isEmpty ? "the store" : providerName)! \(etaText)"
    }

    private func load() async {
        order = try? await APIClient.shared.order(orderId)
        providerName = (try? await APIClient.shared.providerConnection())?.providerName ?? ""
    }
}

#Preview {
    NavigationStack { PlacedView(orderId: "MP-2481", path: .constant([])) }
}
