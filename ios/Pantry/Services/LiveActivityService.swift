import ActivityKit
import Foundation

/// Starts the order's Live Activity and hands its push-to-update token to
/// the backend, which then drives every update via APNs (services/apns.ts +
/// orderPoller.ts) — the app itself never updates the Activity locally.
@MainActor
enum LiveActivityService {
    static func start(orderId: String, providerName: String, etaAtISO: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PantryOrderActivityAttributes(orderId: orderId, providerName: providerName)
        let initialState = PantryOrderActivityAttributes.ContentState(
            stage: "placed",
            etaText: "",
            etaAtISO: etaAtISO,
            courierName: nil,
            courierDistanceKm: nil,
            itemCount: 0,
            total: 0
        )

        // The Simulator has no APNs device token at all, so requesting a
        // `.token` push-to-update Activity there fails with a permissions
        // error before it ever gets to "no token yet" — it's not reachable
        // over push. Fall back to a local (non-push) Activity so the widget
        // UI is still visible and verifiable in the Simulator; real devices
        // use `.token` so the backend's poller can drive updates over APNs.
        #if targetEnvironment(simulator)
        let pushType: PushType? = nil
        #else
        let pushType: PushType? = .token
        #endif

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: pushType
            )
            guard pushType != nil else { return }
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    try? await APIClient.shared.registerActivityToken(orderId: orderId, token: token)
                }
            }
        } catch {
            NSLog("[live-activity] failed to start: \(error)")
        }
    }
}
