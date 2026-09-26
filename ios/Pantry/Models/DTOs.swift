import Foundation

// MARK: - Auth

struct OTPRequestResponse: Decodable {
    let sent: Bool
    let devCode: String?
}

struct OTPVerifyResponse: Decodable {
    let token: String
    let userId: String
    let isNewUser: Bool
}

struct UserProfile: Codable, Identifiable {
    let id: String
    let phone: String
    var name: String?
    var email: String?
    let notificationsEnabled: Int?

    enum CodingKeys: String, CodingKey {
        case id, phone, name, email
        case notificationsEnabled = "notifications_enabled"
    }
}

// MARK: - Providers

struct ProviderInfo: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let available: Bool
    let isDefault: Bool
}

struct StartedSwiggyAuth: Decodable {
    let authorizeUrl: String
    let state: String
}

struct ProviderConnectionInfo: Decodable {
    let id: String
    let providerId: String
    let providerName: String
    let storeId: String
    let storeName: String
    let connectedAt: String
}

// MARK: - Recipients & addresses

struct Recipient: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var relation: String?
    var phone: String?
    var mayCall: Bool?
}

struct DeliveryAddress: Codable, Identifiable, Hashable {
    let id: String
    var recipientId: String?
    var label: String
    var line1: String
    var city: String?
    var pincode: String?
}

// MARK: - Lists, matching & review

struct ListCreated: Decodable {
    let listId: String
    let itemCount: Int
    let greetingCount: Int
    let languages: [String]
}

struct MatchCandidateDTO: Decodable, Identifiable, Hashable {
    let catalogItemId: String
    let name: String
    let confidence: Double
    let reason: String
    let price: Double?

    var id: String { catalogItemId + name }
}

struct PackAllocationDTO: Decodable, Hashable {
    let size: Double
    let unit: String
    let count: Int
    let price: Double
}

struct ReviewItem: Decodable, Identifiable, Hashable {
    let id: String
    let lineId: String
    let rawText: String
    let catalogItemId: String?
    let catalogItemName: String?
    let requestedQty: Double
    let requestedUnit: String
    let approvedQty: Double?
    let packs: [PackAllocationDTO]
    let lineTotal: Double?
    let status: String // needs_match | needs_qty | approved | rejected
    let roundedDown: Bool
    let candidates: [MatchCandidateDTO]
}

struct Review: Decodable {
    let itemCount: Int
    let matchedCount: Int
    let needsCount: Int
    let roundedDownCount: Int
    let total: Double
    let items: [ReviewItem]
}

// MARK: - Cart & orders

struct CartPayload: Decodable {
    let ready: Bool
    let unresolvedCount: Int
    let address: DeliveryAddress?
    let items: [ReviewItem]
    let itemTotal: Double
    let delivery: Double
    let handling: Double
    let total: Double
}

struct PlacedOrder: Decodable {
    let id: String
    let status: String
    let total: Double
    let etaAt: String
}

struct OrderSummary: Decodable, Identifiable {
    let id: String
    let status: String
    let total: Double
    let placedAt: String
    let etaAt: String?
    let addressLabel: String
    let itemCount: Int
}

struct OrderEventDTO: Decodable, Identifiable, Hashable {
    let type: String
    let label: String?
    let at: String

    var id: String { type + at }
}

struct OrderDetail: Decodable, Identifiable {
    let id: String
    let status: String
    let total: Double
    let listId: String
    let courierName: String?
    let courierDistanceKm: Double?
    let placedAt: String
    let etaAt: String?
    let addressLabel: String
    let addressLine1: String
    let events: [OrderEventDTO]
    let items: [ReviewItem]
}

struct ReorderResult: Decodable {
    let listId: String
}
