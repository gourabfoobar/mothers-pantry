import ActivityKit
import Foundation

/// Shared between the app and PantryWidgetExtension — filled in at milestone 10.
struct PantryOrderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var etaText: String
    }

    var orderId: String
}
