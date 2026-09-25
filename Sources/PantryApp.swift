import SwiftUI
import UIKit

@main
struct PantryApp: App {
    var body: some Scene { WindowGroup { GroceryListView() } }
}

struct GroceryListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var message = ProcessInfo.processInfo.arguments.contains(where: { $0 == "--demo" || $0 == "--demo-approved" })
        ? "aloo 1 kg\npeyaj 500 g\ndim 6\natta 1 kg\nunknown herb 2 packs" : ""
    @State private var matches: [GroceryMatch] = []
    @State private var analyzed = false
    @State private var reviewing = false
    @State private var completed = false
    @State private var provider = "offline"
    @State private var connected = false
    @State private var addresses: [DeliveryAddress] = []
    @State private var selectedAddressId = ""
    @State private var loading = false
    @State private var errorMessage: String?

    private let ink = Color(red: 0.14, green: 0.19, blue: 0.18)
    private let canvas = Color(red: 0.965, green: 0.965, blue: 0.95)
    private let accent = Color(red: 0.77, green: 0.91, blue: 0.53)
    private var active: [GroceryMatch] { matches.filter { !$0.skipped && $0.product != nil && $0.packs > 0 } }
    private var unresolved: Int { matches.filter { !$0.resolved }.count }
    private var subtotal: Int { active.reduce(0) { $0 + $1.total } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .padding(9).background(accent, in: RoundedRectangle(cornerRadius: 10))
                        Text("pantry").font(.system(size: 21, weight: .bold, design: .rounded))
                        Spacer()
                        Text("GROCERY ASSISTANT").font(.system(size: 10, weight: .bold)).tracking(1.3)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("A simpler way\nto shop her list.")
                            .font(.system(size: 39, weight: .semibold, design: .rounded))
                            .tracking(-1.5)
                        Text("Paste her WhatsApp message. Check every match before you decide what to order.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    providerCard
                    if analyzed { analyzedSummary } else { inputCard }
                    if analyzed { results }
                    Label(provider == "offline" ? "Offline sample catalog. No order or payment can be placed." : "Local bridge active. Search uses \(provider == "demo" ? "sample" : "Swiggy staging") data; checkout is disabled.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(canvas)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await refreshProvider()
                if ProcessInfo.processInfo.arguments.contains(where: { $0 == "--demo" || $0 == "--demo-approved" }) {
                    await findMatches()
                    if ProcessInfo.processInfo.arguments.contains("--demo-approved") {
                        for index in matches.indices {
                            if matches[index].product == nil || matches[index].packs == 0 {
                                matches[index].skipped = true
                            } else {
                                matches[index].approved = true
                            }
                        }
                        reviewing = true
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshProvider() } }
            }
            .onChange(of: selectedAddressId) { _, _ in
                if !ProcessInfo.processInfo.arguments.contains(where: { $0 == "--demo" || $0 == "--demo-approved" }) {
                    analyzed = false
                    matches = []
                }
            }
            .safeAreaInset(edge: .bottom) {
                if analyzed && !matches.isEmpty {
                    Button { reviewing = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Review plan").font(.headline)
                                Text(unresolved == 0 ? "\(active.count) items · sample ₹\(subtotal)" : "\(unresolved) need attention")
                                    .font(.caption)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white).padding(18)
                        .background(ink, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(unresolved > 0 || active.isEmpty)
                    .opacity(unresolved > 0 || active.isEmpty ? 0.45 : 1)
                    .padding(.horizontal, 22).padding(.vertical, 9).background(canvas)
                }
            }
            .sheet(isPresented: $reviewing) { reviewSheet }
            .alert("Sample plan confirmed", isPresented: $completed) {
                Button("Done", role: .cancel) { }
            } message: {
                Text("No order was placed and no payment was taken. Connect a live grocery provider to order.")
            }
        }
        .tint(ink)
    }

    private var analyzedSummary: some View {
        HStack {
            sectionNumber("01")
            Text("\(matches.count) lines pasted").font(.headline)
            Spacer()
            Button("Edit list") { analyzed = false }
                .font(.subheadline.weight(.semibold))
        }
        .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(connected ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(provider == "offline" ? "Offline sample mode" : (connected ? (provider == "demo" ? "Local demo bridge" : "Swiggy staging connected") : "Swiggy sign-in needed"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Refresh") { Task { await refreshProvider() } }.font(.caption)
            }
            if provider == "swiggy" && !connected {
                Button("Connect Swiggy") {
                    UIApplication.shared.open(URL(string: "http://localhost:8765/connect")!)
                }.font(.subheadline.weight(.semibold))
            }
            if provider == "swiggy" && connected && !addresses.isEmpty {
                Picker("Delivery address", selection: $selectedAddressId) {
                    Text("Choose an address").tag("")
                    ForEach(addresses) { address in
                        Text(address.addressLine).tag(address.id)
                    }
                }
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    @MainActor private func refreshProvider() async {
        do {
            let status = try await BackendClient.getStatus()
            if status.provider != provider || status.connected != connected {
                analyzed = false
                matches = []
            }
            provider = status.provider
            connected = status.connected
            if connected {
                do {
                    addresses = try await BackendClient.getAddresses()
                    if !addresses.contains(where: { $0.id == selectedAddressId }) {
                        selectedAddressId = provider == "demo" ? (addresses.first?.id ?? "") : ""
                    }
                    errorMessage = nil
                } catch {
                    addresses = []
                    errorMessage = "Could not load delivery addresses. Refresh the connection."
                }
            } else {
                addresses = []
                errorMessage = nil
            }
        } catch {
            if provider != "offline" {
                analyzed = false
                matches = []
            }
            provider = "offline"
            connected = false
            addresses = []
            errorMessage = nil
        }
    }

    @MainActor private func findMatches() async {
        loading = true
        defer { loading = false }
        errorMessage = nil
        if provider == "offline" {
            matches = GroceryMatcher.match(message)
            analyzed = true
            return
        }
        guard connected, !selectedAddressId.isEmpty else {
            errorMessage = "Connect Swiggy and select a delivery address first."
            return
        }
        do {
            let requests = GroceryMatcher.parse(message)
            let catalog = try await BackendClient.getCatalog(addressId: selectedAddressId, names: requests.map(\.name))
            matches = GroceryMatcher.match(message, catalogue: catalog)
            analyzed = true
        } catch {
            errorMessage = "Search failed. Refresh the connection and try again."
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                sectionNumber("01")
                Text("Paste the list").font(.headline)
                Spacer()
                Button {
                    message = UIPasteboard.general.string ?? ""
                    analyzed = false
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard").font(.subheadline.weight(.semibold))
                }
            }
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text("e.g. aloo 1 kg\npeyaj 500 g\ndim 6\natta 1 kg")
                        .foregroundStyle(.secondary).padding(.top, 10).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $message)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 145)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("WhatsApp grocery list")
                    .onChange(of: message) { _, _ in analyzed = false }
            }
            .padding(10).background(canvas, in: RoundedRectangle(cornerRadius: 17))
            Text("Use one item per line. Include a quantity and unit when possible.")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                Task { await findMatches() }
            } label: {
                HStack {
                    Text(loading ? "Searching…" : "Find matches")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline).padding(18).frame(maxWidth: .infinity)
                .background(accent, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(loading || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 24))
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionNumber("02")
                Text("Check the matches").font(.headline)
                Spacer()
                Text("\(matches.count) FOUND")
                    .font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(.secondary)
            }
            Text("Confirm uncertain names and quantities. Remove items you do not want.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(matches.indices, id: \.self) { index in matchCard(index) }
        }
    }

    private func matchCard(_ index: Int) -> some View {
        let match = matches[index]
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Text(match.product?.symbol ?? "?")
                    .font(.system(size: 29)).frame(width: 54, height: 54)
                    .background(canvas, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.request.original).font(.caption).foregroundStyle(.secondary)
                    Text(match.product?.name ?? "No catalog match").font(.headline)
                    if let product = match.product, match.packs > 0 {
                        Text("\(match.packs) × \(product.packLabel) · ₹\(match.total)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            issueLabel(match)
            HStack(spacing: 10) {
                if !match.resolved && match.product != nil && match.packs > 0 {
                    Button("Approve match") { matches[index].approved = true }
                        .buttonStyle(.borderedProminent).tint(ink)
                }
                Button(match.skipped ? "Restore" : "Remove item") {
                    matches[index].skipped.toggle()
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(17).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 21))
        .opacity(match.skipped ? 0.55 : 1)
    }

    private func issueLabel(_ match: GroceryMatch) -> some View {
        let description: String
        switch match.issue {
        case .ready: description = "Name and quantity match the catalog"
        case .confirmName: description = "Name suggestion — confirm this item"
        case .confirmQuantity:
            if !match.request.explicitUnit {
                description = "Unit assumed to be pieces — confirm name and quantity"
            } else if match.request.unit == .packs {
                description = "Pack size was not specified — confirm this choice"
            } else if let product = match.product, match.packs > 0, let requested = match.request.amount,
               let unit = match.request.unit, unit != .packs {
                description = match.packs * product.amount >= requested * 2
                    ? "Offered quantity is at least 2× requested — approval required"
                    : "Pack quantity differs from request — approval required"
            } else {
                description = "Quantity or unit is unclear — edit the list"
            }
        case .unavailable: description = "No available match found — check manually"
        case .missingQuantity: description = "Quantity missing — edit the list"
        }
        let label = match.skipped ? "Removed from plan" : (match.approved ? "Approved: " + description : description)
        return Label(label, systemImage: match.issue == .ready || match.approved ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(match.issue == .ready || match.approved ? Color.green : Color.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var reviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    Text("One final check")
                        .font(.system(size: 29, weight: .semibold, design: .rounded))
                    Text(provider == "swiggy" ? "These are search results, not a payable quote. Stock and prices must be refreshed before checkout." : "These are sample matches and prices. Live stock, delivery fees, and a payable quote are unavailable.")
                        .foregroundStyle(.secondary)
                    ForEach(active) { match in
                        HStack {
                            Text(match.product?.symbol ?? "")
                            Text(match.product?.name ?? "")
                            Spacer()
                            Text("\(match.packs) × \(match.product?.packLabel ?? "")")
                        }
                        .font(.subheadline).padding(15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15))
                    }
                    HStack {
                        Text("Sample subtotal")
                        Spacer()
                        Text("₹\(subtotal)").bold()
                    }
                    Button {
                        reviewing = false
                        completed = true
                    } label: {
                        Text("Confirm sample plan").font(.headline)
                            .frame(maxWidth: .infinity).padding(18)
                            .background(accent, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Text("Real ordering will require a live quote, address, and separate final approval.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .background(canvas)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { reviewing = false } }
        }
    }

    private func sectionNumber(_ value: String) -> some View {
        Text(value).font(.system(size: 11, weight: .bold, design: .monospaced))
            .frame(width: 31, height: 31).background(canvas, in: Circle())
    }
}

private struct ProviderStatus: Decodable {
    let provider: String
    let connected: Bool
}

private struct DeliveryAddress: Identifiable, Decodable {
    let id: String
    let addressLine: String
}

private struct AddressResponse: Decodable {
    let addresses: [DeliveryAddress]
}

private struct CatalogRow: Decodable {
    let name: String
    let products: [GrocerySKU]
}

private struct CatalogResponse: Decodable {
    let results: [CatalogRow]
}

private enum BackendClient {
    private static let base = URL(string: "http://localhost:8765")!

    static func getStatus() async throws -> ProviderStatus {
        try await get("/status", as: ProviderStatus.self)
    }

    static func getAddresses() async throws -> [DeliveryAddress] {
        try await get("/addresses", as: AddressResponse.self).addresses
    }

    static func getCatalog(addressId: String, names: [String]) async throws -> [GrocerySKU] {
        var request = URLRequest(url: base.appendingPathComponent("catalog"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "addressId": addressId,
            "requests": names.map { ["name": $0] }
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(CatalogResponse.self, from: data).results.flatMap(\.products)
    }

    private static func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        var request = URLRequest(url: base.appendingPathComponent(String(path.dropFirst())))
        request.timeoutInterval = 3
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(type, from: data)
    }
}
