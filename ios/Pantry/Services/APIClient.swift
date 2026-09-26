import Foundation

enum APIError: LocalizedError {
    case server(status: Int, message: String)
    case decoding(Error)
    case network(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .server(let status, let message): return "\(message) (\(status))"
        case .decoding: return "Couldn't understand the server's response."
        case .network(let error): return error.localizedDescription
        case .unauthorized: return "Session expired. Please sign in again."
        }
    }
}

/// Talks to the Mother's Pantry backend (`../backend`). One shared instance,
/// holding the bearer token in memory (backed by the Keychain) and a
/// simulator/LAN-friendly base URL.
@MainActor
final class APIClient {
    static let shared = APIClient()

    /// `http://localhost:4200` reaches the Mac from the Simulator directly.
    /// For a physical device on the same Wi-Fi, override with the Mac's LAN IP.
    var baseURL: URL = {
        if let stored = UserDefaults.standard.string(forKey: "pantry.baseURL"), let url = URL(string: stored) {
            return url
        }
        return URL(string: "http://localhost:4200")!
    }()

    private(set) var token: String? {
        didSet {
            if let token { KeychainTokenStore.save(token) } else { KeychainTokenStore.delete() }
        }
    }

    var isSignedIn: Bool { token != nil }

    private let session = URLSession(configuration: .default)
    private let decoder = JSONDecoder()

    private init() {
        token = KeychainTokenStore.load()
    }

    func setBaseURL(_ url: URL) {
        baseURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: "pantry.baseURL")
    }

    func signOut() {
        token = nil
    }

    // MARK: - Core request

    struct EmptyResponse: Decodable {}
    private struct ErrorBody: Decodable { let error: String }
    private struct NoBody: Encodable {}

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: 0, message: "No response")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            let message = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "Request failed"
            throw APIError.server(status: http.statusCode, message: message)
        }
        return data
    }

    private func buildRequest(_ path: String, method: String, authorized: Bool) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if authorized, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        }
        return request
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T // swiftlint:disable:this force_cast
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// GET, or a body-less POST (e.g. `/lists/:id/match`).
    private func request<T: Decodable>(_ path: String, method: String = "GET", authorized: Bool = true) async throws -> T {
        var request = buildRequest(path, method: method, authorized: authorized)
        if method == "POST" { request.httpBody = try JSONEncoder().encode(NoBody()) }
        return try decode(try await send(request))
    }

    private func request<T: Decodable, B: Encodable>(
        _ path: String, method: String = "POST", body: B, authorized: Bool = true
    ) async throws -> T {
        var request = buildRequest(path, method: method, authorized: authorized)
        request.httpBody = try JSONEncoder().encode(body)
        return try decode(try await send(request))
    }

    // MARK: - Auth

    func requestOTP(phone: String) async throws -> OTPRequestResponse {
        try await request("/auth/otp/request", body: ["phone": phone], authorized: false)
    }

    func verifyOTP(phone: String, code: String) async throws -> OTPVerifyResponse {
        let result: OTPVerifyResponse = try await request(
            "/auth/otp/verify", body: ["phone": phone, "code": code], authorized: false
        )
        token = result.token
        return result
    }

    func updateProfile(name: String, email: String?, notificationsEnabled: Bool) async throws -> UserProfile {
        try await request("/auth/profile", body: ProfileUpdate(name: name, email: email, notificationsEnabled: notificationsEnabled))
    }

    func me() async throws -> UserProfile {
        try await request("/auth/me")
    }

    private struct ProfileUpdate: Encodable {
        let name: String
        let email: String?
        let notificationsEnabled: Bool
    }

    // MARK: - Providers

    func providers() async throws -> [ProviderInfo] {
        try await request("/providers", authorized: false)
    }

    /// kirana-now: connects immediately, no real account needed.
    func authorizeProvider(_ id: String) async throws -> ProviderConnectionInfo {
        try await request("/providers/\(id)/authorize", method: "POST")
    }

    /// Swiggy: returns a URL to open in a browser; Swiggy hosts phone+OTP
    /// itself and redirects to the backend's callback when done.
    func startSwiggyAuthorize() async throws -> StartedSwiggyAuth {
        try await request("/providers/swiggy/authorize", method: "POST")
    }

    func providerConnection() async throws -> ProviderConnectionInfo? {
        try await request("/providers/connection")
    }

    // MARK: - Recipients & addresses

    func recipients() async throws -> [Recipient] {
        try await request("/recipients")
    }

    func createRecipient(name: String, relation: String?, phone: String?) async throws -> Recipient {
        try await request("/recipients", body: CreateRecipient(name: name, relation: relation, phone: phone))
    }

    private struct CreateRecipient: Encodable { let name: String; let relation: String?; let phone: String? }

    func addresses() async throws -> [DeliveryAddress] {
        try await request("/addresses")
    }

    func createAddress(recipientId: String?, label: String, line1: String, city: String?, pincode: String?) async throws -> DeliveryAddress {
        try await request(
            "/addresses", body: CreateAddress(recipientId: recipientId, label: label, line1: line1, city: city, pincode: pincode)
        )
    }

    private struct CreateAddress: Encodable {
        let recipientId: String?; let label: String; let line1: String; let city: String?; let pincode: String?
    }

    // MARK: - Lists, matching, approvals

    func createList(addressId: String, rawText: String) async throws -> ListCreated {
        try await request("/lists", body: ["addressId": addressId, "rawText": rawText])
    }

    func matchList(_ listId: String) async throws -> Review {
        try await request("/lists/\(listId)/match", method: "POST")
    }

    func review(_ listId: String) async throws -> Review {
        try await request("/lists/\(listId)/review")
    }

    func approveMatch(orderItemId: String, catalogItemId: String? = nil) async throws {
        let _: EmptyResponse = try await request("/matches/\(orderItemId)/approve", body: ["catalogItemId": catalogItemId])
    }

    func rejectMatch(orderItemId: String) async throws {
        let _: EmptyResponse = try await request("/matches/\(orderItemId)/reject", method: "POST")
    }

    func approveQty(orderItemId: String) async throws {
        let _: EmptyResponse = try await request("/qty/\(orderItemId)/approve", method: "POST")
    }

    func rejectQty(orderItemId: String) async throws {
        let _: EmptyResponse = try await request("/qty/\(orderItemId)/reject", method: "POST")
    }

    // MARK: - Cart & orders

    func cart(listId: String) async throws -> CartPayload {
        try await request("/orders/cart/\(listId)")
    }

    func placeOrder(listId: String) async throws -> PlacedOrder {
        try await request("/orders/place/\(listId)", method: "POST")
    }

    func registerActivityToken(orderId: String, token: String) async throws {
        let _: EmptyResponse = try await request("/orders/\(orderId)/activity-token", body: ["token": token])
    }

    func orders() async throws -> [OrderSummary] {
        try await request("/orders")
    }

    func order(_ id: String) async throws -> OrderDetail {
        try await request("/orders/\(id)")
    }

    func reorder(_ orderId: String) async throws -> ReorderResult {
        try await request("/orders/\(orderId)/reorder", method: "POST")
    }

    // MARK: - Devices

    func registerDevice(pushToken: String?, activityPushToStartToken: String?) async throws {
        let _: EmptyResponse = try await request(
            "/devices/register", body: ["pushToken": pushToken, "activityPushToStartToken": activityPushToStartToken]
        )
    }
}
