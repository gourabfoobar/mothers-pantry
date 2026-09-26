import Foundation
import SwiftData

/// Local cache of order history so 6.1/6.2 have something to show offline.
/// The backend (`GET /orders`, `GET /orders/:id`) stays the source of truth;
/// this is populated from those responses, not written to directly.
@Model
final class CachedOrder {
    @Attribute(.unique) var id: String
    var status: String
    var total: Double
    var addressLabel: String
    var placedAt: Date
    var etaAt: Date?
    var courierName: String?
    var courierDistanceKm: Double?

    @Relationship(deleteRule: .cascade, inverse: \CachedOrderItem.order)
    var items: [CachedOrderItem] = []

    init(
        id: String,
        status: String,
        total: Double,
        addressLabel: String,
        placedAt: Date,
        etaAt: Date? = nil,
        courierName: String? = nil,
        courierDistanceKm: Double? = nil
    ) {
        self.id = id
        self.status = status
        self.total = total
        self.addressLabel = addressLabel
        self.placedAt = placedAt
        self.etaAt = etaAt
        self.courierName = courierName
        self.courierDistanceKm = courierDistanceKm
    }
}

@Model
final class CachedOrderItem {
    @Attribute(.unique) var id: String
    var rawText: String
    var catalogItemName: String?
    var requestedQty: Double
    var requestedUnit: String
    var approvedQty: Double?
    var lineTotal: Double?
    var status: String
    var roundedDown: Bool

    var order: CachedOrder?

    init(
        id: String,
        rawText: String,
        catalogItemName: String?,
        requestedQty: Double,
        requestedUnit: String,
        approvedQty: Double?,
        lineTotal: Double?,
        status: String,
        roundedDown: Bool
    ) {
        self.id = id
        self.rawText = rawText
        self.catalogItemName = catalogItemName
        self.requestedQty = requestedQty
        self.requestedUnit = requestedUnit
        self.approvedQty = approvedQty
        self.lineTotal = lineTotal
        self.status = status
        self.roundedDown = roundedDown
    }
}
