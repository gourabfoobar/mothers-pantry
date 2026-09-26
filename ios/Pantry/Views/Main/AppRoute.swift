import Foundation

/// Navigation path for the signed-in app (canvas rows 03-06). Grows with
/// each milestone; today covers building and reviewing a list (3.1-3.5).
enum AppRoute: Hashable {
    case address
    case paste(addressId: String)
    case matching(listId: String)
    case review(listId: String)
    case orderDetail(orderId: String)
    /// Placeholder for the approvals/checkout flow until milestone 9 lands.
    case checkoutFlow(listId: String)
}
