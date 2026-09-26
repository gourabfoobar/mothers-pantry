import Foundation

/// Navigation path for the signed-in app (canvas rows 03-06).
enum AppRoute: Hashable {
    case address
    case paste(addressId: String)
    case matching(listId: String)
    case review(listId: String)
    case orderDetail(orderId: String)
    /// Live in-app tracking (5.3) — lands in milestone 10.
    case tracking(orderId: String)
    /// Cycles through every needs-you item (4.2/4.3 as sheets), then checkout.
    case approvals(listId: String)
    case checkout(listId: String)
    case placed(orderId: String)
}
