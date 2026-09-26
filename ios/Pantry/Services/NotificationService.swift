import UIKit
import UserNotifications

/// Actionable notification categories for match/quantity approvals (canvas
/// 4.1) — identifiers must match backend/src/services/notifications.ts
/// exactly, since the backend sets `categoryId` on the push payload.
enum NotificationCategory {
    static let matchApproval = "PANTRY_MATCH_APPROVAL"
    static let qtyApproval = "PANTRY_QTY_APPROVAL"

    static let useAction = "PANTRY_USE_MATCH"
    static let rejectMatchAction = "PANTRY_REJECT_MATCH"
    static let approveQtyAction = "PANTRY_APPROVE_QTY"
    static let rejectQtyAction = "PANTRY_REJECT_QTY"
}

@MainActor
enum NotificationService {
    static func registerCategories() {
        let use = UNNotificationAction(identifier: NotificationCategory.useAction, title: "Use this match", options: [])
        let rejectMatch = UNNotificationAction(identifier: NotificationCategory.rejectMatchAction, title: "Reject", options: [.destructive])
        let matchCategory = UNNotificationCategory(
            identifier: NotificationCategory.matchApproval, actions: [use, rejectMatch], intentIdentifiers: [], options: []
        )

        let approveQty = UNNotificationAction(identifier: NotificationCategory.approveQtyAction, title: "Approve", options: [])
        let rejectQty = UNNotificationAction(identifier: NotificationCategory.rejectQtyAction, title: "Reject", options: [.destructive])
        let qtyCategory = UNNotificationCategory(
            identifier: NotificationCategory.qtyApproval, actions: [approveQty, rejectQty], intentIdentifiers: [], options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([matchCategory, qtyCategory])
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        registerCategories()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            await UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }
}

/// Handles taps on the Approve/Reject actions without opening the app —
/// the whole point of canvas 4.1's Lock Screen cards.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let orderItemId = userInfo["orderItemId"] as? String else { return }

        switch response.actionIdentifier {
        case NotificationCategory.useAction:
            let catalogItemId = userInfo["catalogItemId"] as? String
            try? await APIClient.shared.approveMatch(orderItemId: orderItemId, catalogItemId: catalogItemId)
        case NotificationCategory.rejectMatchAction:
            try? await APIClient.shared.rejectMatch(orderItemId: orderItemId)
        case NotificationCategory.approveQtyAction:
            try? await APIClient.shared.approveQty(orderItemId: orderItemId)
        case NotificationCategory.rejectQtyAction:
            try? await APIClient.shared.rejectQty(orderItemId: orderItemId)
        default:
            break // plain tap — just opens the app
        }
    }
}
