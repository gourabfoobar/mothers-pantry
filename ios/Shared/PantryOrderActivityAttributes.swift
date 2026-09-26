import ActivityKit
import Foundation

/// Shared between the app (starts/updates the Activity) and
/// PantryWidgetExtension (renders it) — the Codable shape must match
/// backend/src/services/apns.ts's LiveActivityContentState exactly, since
/// APNs delivers `content-state` as raw JSON decoded straight into this type.
struct PantryOrderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "placed" | "packed" | "on_the_way" | "delivered"
        var stage: String
        var etaText: String
        /// ISO 8601 — lets the widget drive a live countdown via `Text(_:style:)`.
        var etaAtISO: String?
        var courierName: String?
        var courierDistanceKm: Double?
        var itemCount: Int
        var total: Double

        var etaDate: Date? {
            etaAtISO.flatMap { ISO8601DateFormatter().date(from: $0) }
        }
    }

    var orderId: String
    var providerName: String
}

enum PantryOrderStage: String {
    case placed, packed, onTheWay = "on_the_way", delivered

    var label: String {
        switch self {
        case .placed: "Placed"
        case .packed: "Packed"
        case .onTheWay: "On the way"
        case .delivered: "Delivered"
        }
    }

    /// 0-based index into the 4-stage progress bar.
    var progressIndex: Int {
        switch self {
        case .placed: 0
        case .packed: 1
        case .onTheWay: 2
        case .delivered: 3
        }
    }
}
