import SwiftUI

/// The signed-in app: three tabs, each with its own navigation stack, plus
/// the shared bottom nav bar (canvas rows 03-06).
struct MainShellView: View {
    @State private var selection: MainTab = .home
    @State private var homePath: [AppRoute] = []
    @State private var ordersPath: [AppRoute] = []
    @State private var accountPath: [AppRoute] = []

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                tab(.home) {
                    NavigationStack(path: $homePath) {
                        HomeView(path: $homePath, onAccountTap: { selection = .account })
                            .navigationDestination(for: AppRoute.self) { destination(for: $0, path: $homePath) }
                    }
                }
                tab(.orders) {
                    NavigationStack(path: $ordersPath) {
                        HistoryView(path: $ordersPath)
                            .navigationDestination(for: AppRoute.self) { destination(for: $0, path: $ordersPath) }
                    }
                }
                tab(.account) {
                    NavigationStack(path: $accountPath) {
                        AccountView()
                            .navigationDestination(for: AppRoute.self) { destination(for: $0, path: $accountPath) }
                    }
                }
            }
            BottomNavBar(selection: $selection)
        }
        .background(Theme.background)
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func tab(_ tab: MainTab, @ViewBuilder content: () -> some View) -> some View {
        content().opacity(selection == tab ? 1 : 0).allowsHitTesting(selection == tab)
    }

    @ViewBuilder
    private func destination(for route: AppRoute, path: Binding<[AppRoute]>) -> some View {
        switch route {
        case .address:
            AddressView(path: path)
        case .paste(let addressId):
            PasteView(addressId: addressId, path: path)
        case .matching(let listId):
            MatchingView(listId: listId, path: path)
        case .review(let listId):
            ReviewView(listId: listId, path: path)
        case .orderDetail(let orderId):
            OrderDetailView(orderId: orderId, path: path)
        case .tracking(let orderId):
            TrackingView(orderId: orderId, path: path)
        case .approvals(let listId):
            ApprovalsCoordinatorView(listId: listId, path: path)
        case .checkout(let listId):
            CheckoutView(listId: listId, path: path)
        case .placed(let orderId):
            PlacedView(orderId: orderId, path: path)
        }
    }
}

#Preview {
    MainShellView().environment(AppState())
}
