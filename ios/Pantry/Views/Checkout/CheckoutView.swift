import SwiftUI

/// Canvas 4.4 "Cart & checkout".
struct CheckoutView: View {
    let listId: String
    @Binding var path: [AppRoute]

    @State private var cart: CartPayload?
    @State private var recipient: Recipient?
    @State private var providerName = ""
    @State private var isLoading = true
    @State private var isPlacing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let cart {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ScreenHeader(label: "Cart") { path.safePop() }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ready for checkout")
                                .font(.mono(28, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                Text("All approvals done")
                            }
                            .font(.mono(13))
                            .foregroundStyle(Color(hex: 0x4A4A4A))
                        }

                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.accentText)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(cart.address?.label ?? "Address") · \(recipient?.name ?? "")")
                                        .font(.mono(15, weight: .medium)).foregroundStyle(Theme.ink)
                                    Text([cart.address?.line1, recipient?.phone].compactMap { $0 }.joined(separator: " · "))
                                        .font(.mono(13)).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .padding(16)
                            Divider().background(Theme.border)
                            HStack(spacing: 14) {
                                Image(systemName: "clock").foregroundStyle(Theme.ink)
                                Text("Today, 6:30 – 7:00 pm").font(.mono(15)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("Change").font(.mono(14)).foregroundStyle(Theme.accentText)
                            }
                            .padding(16)
                        }
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

                        Button {
                            path.append(.review(listId: listId))
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(cart.items.count) items").font(.mono(15, weight: .medium)).foregroundStyle(Theme.ink)
                                    Text(itemsSummary).font(.mono(13)).foregroundStyle(Theme.secondaryText).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
                            }
                            .padding(16)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 10) {
                            billRow("Item total", "₹ \(Int(cart.itemTotal))")
                            billRow("Delivery", cart.delivery == 0 ? "Free" : "₹ \(Int(cart.delivery))")
                            billRow("Handling", "₹ \(Int(cart.handling))")
                            Divider().background(Theme.border)
                            HStack(alignment: .lastTextBaseline) {
                                Text("To pay").font(.mono(15, weight: .medium)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("₹ \(Int(cart.total))").font(.mono(24, weight: .semibold)).foregroundStyle(Theme.ink)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 54)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 8) {
                    Button {
                        place()
                    } label: {
                        if isPlacing { ProgressView().tint(Color(hex: 0x1F1F1F)) } else { Text("Place order · ₹ \(Int(cart.total))") }
                    }
                    .buttonStyle(.pantryAccent)
                    .disabled(isPlacing || !cart.ready)

                    Text("Paid with your saved method in \(providerName.isEmpty ? "your store" : providerName)")
                        .font(.mono(12)).foregroundStyle(Theme.secondaryText)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 30)
            } else {
                VStack(spacing: 12) {
                    Text(errorMessage ?? "Couldn't load the cart.")
                        .font(.mono(14)).foregroundStyle(Theme.accentText).multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }.buttonStyle(.pantrySecondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private var itemsSummary: String {
        cart?.items.prefix(3).map { $0.catalogItemName ?? $0.rawText }.joined(separator: " · ") ?? ""
    }

    private func billRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.mono(14)).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).font(.mono(14)).foregroundStyle(Theme.ink)
        }
    }

    private func load() async {
        isLoading = true
        do {
            cart = try await APIClient.shared.cart(listId: listId)
        } catch {
            errorMessage = error.localizedDescription
        }
        if let recipientId = cart?.address?.recipientId {
            recipient = (try? await APIClient.shared.recipients())?.first(where: { $0.id == recipientId })
        }
        providerName = (try? await APIClient.shared.providerConnection())?.providerName ?? ""
        isLoading = false
    }

    private func place() {
        errorMessage = nil
        isPlacing = true
        Task {
            do {
                let order = try await APIClient.shared.placeOrder(listId: listId)
                LiveActivityService.start(orderId: order.id, providerName: providerName, etaAtISO: order.etaAt)
                isPlacing = false
                path.append(.placed(orderId: order.id))
            } catch {
                isPlacing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { CheckoutView(listId: "preview", path: .constant([])) }
}
