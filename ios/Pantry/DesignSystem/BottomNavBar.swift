import SwiftUI

enum MainTab: CaseIterable {
    case home, orders, account

    var label: String {
        switch self {
        case .home: "Home"
        case .orders: "Orders"
        case .account: "Account"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .orders: "list.bullet"
        case .account: "person.crop.circle"
        }
    }
}

/// The 88pt bottom bar repeated on Home/Orders/Account/Tracking/OrderDetail
/// in the canvas — a small orange dot under the active tab, not a native
/// UITabBar look.
struct BottomNavBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selection == tab ? .semibold : .regular))
                        Text(tab.label)
                            .font(.mono(12, weight: selection == tab ? .bold : .regular))
                        Circle()
                            .fill(selection == tab ? Theme.accent : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .foregroundStyle(selection == tab ? Theme.ink : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 88)
        .background(Theme.card)
        .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
    }
}
