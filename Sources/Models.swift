import Foundation

enum Store: String, CaseIterable, Identifiable, Codable {
    case food = "Food", groceries = "Groceries"
    var id: String { rawValue }
}

struct Product: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let detail: String
    let emoji: String
    let price: Int // Whole rupees in the sample catalogue.
    let store: Store
}

struct Basket {
    private(set) var quantities: [String: Int] = [:]
    mutating func change(_ product: Product, by delta: Int) {
        quantities[product.id] = min(20, max(0, (quantities[product.id] ?? 0) + delta))
    }
    func quantity(_ product: Product) -> Int { quantities[product.id] ?? 0 }
    func total(_ products: [Product]) -> Int {
        products.reduce(0) { $0 + $1.price * quantity($1) }
    }
    mutating func clear(_ products: [Product]) {
        for product in products { quantities.removeValue(forKey: product.id) }
    }
}

enum SampleCatalogue {
    static let products: [Product] = [
        .init(id: "bowl", name: "Green goodness bowl", detail: "The Sample Kitchen · vegetarian", emoji: "🥗", price: 249, store: .food),
        .init(id: "dosa", name: "Masala dosa", detail: "The Sample Kitchen · vegetarian", emoji: "🥞", price: 149, store: .food),
        .init(id: "rice", name: "Vegetable biryani", detail: "The Sample Kitchen · vegetarian", emoji: "🍛", price: 229, store: .food),
        .init(id: "wrap", name: "Paneer wrap", detail: "The Sample Kitchen · vegetarian", emoji: "🌯", price: 189, store: .food),
        .init(id: "milk", name: "Fresh milk", detail: "500 ml", emoji: "🥛", price: 32, store: .groceries),
        .init(id: "eggs", name: "Farm eggs", detail: "Pack of 6", emoji: "🥚", price: 65, store: .groceries),
        .init(id: "banana", name: "Bananas", detail: "6 pieces", emoji: "🍌", price: 48, store: .groceries),
        .init(id: "bread", name: "Whole wheat bread", detail: "400 g", emoji: "🍞", price: 50, store: .groceries),
        .init(id: "tomato", name: "Tomatoes", detail: "500 g", emoji: "🍅", price: 30, store: .groceries),
        .init(id: "oats", name: "Rolled oats", detail: "500 g", emoji: "🌾", price: 149, store: .groceries)
    ]
}

// The matching engine only knows this sample catalogue. A live provider must supply
// current products, pack sizes, availability and prices before real ordering.
struct GrocerySKU: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let aliases: [String]
    let amount: Int
    let unit: GroceryUnit
    let packLabel: String
    let price: Int
    let symbol: String
    var requiresNameApproval = false
}

enum GroceryUnit: String, Codable {
    case grams, millilitres, pieces, packs
}

enum DemoGroceries {
    static let items: [GrocerySKU] = [
        .init(id: "potato1", name: "Potatoes", aliases: ["potato", "potatoes", "aloo", "alu"], amount: 1000, unit: .grams, packLabel: "1 kg", price: 45, symbol: "🥔"),
        .init(id: "onion1", name: "Onions", aliases: ["onion", "onions", "pyaz", "pyaaz", "peyaj", "peyaz"], amount: 1000, unit: .grams, packLabel: "1 kg", price: 52, symbol: "🧅"),
        .init(id: "tomato500", name: "Tomatoes", aliases: ["tomato", "tomatoes", "tamatar", "tometo"], amount: 500, unit: .grams, packLabel: "500 g", price: 30, symbol: "🍅"),
        .init(id: "rice1", name: "Rice", aliases: ["rice", "chawal", "chaal", "chal"], amount: 1000, unit: .grams, packLabel: "1 kg", price: 95, symbol: "🍚"),
        .init(id: "atta2", name: "Wheat flour", aliases: ["atta", "wheat flour", "flour"], amount: 2000, unit: .grams, packLabel: "2 kg", price: 125, symbol: "🌾"),
        .init(id: "milk500", name: "Milk", aliases: ["milk", "doodh", "dudh", "dood"], amount: 500, unit: .millilitres, packLabel: "500 ml", price: 32, symbol: "🥛"),
        .init(id: "eggs6", name: "Eggs", aliases: ["egg", "eggs", "anda", "ande", "dim"], amount: 6, unit: .pieces, packLabel: "6 pieces", price: 65, symbol: "🥚"),
        .init(id: "banana6", name: "Bananas", aliases: ["banana", "bananas", "kela", "kele", "kola"], amount: 6, unit: .pieces, packLabel: "6 pieces", price: 48, symbol: "🍌"),
        .init(id: "bread400", name: "Bread", aliases: ["bread", "pauroti", "pauruti"], amount: 400, unit: .grams, packLabel: "400 g", price: 50, symbol: "🍞")
    ]
}

struct GroceryRequest: Equatable {
    let original: String
    let name: String
    let amount: Int?
    let unit: GroceryUnit?
    let explicitUnit: Bool
}

enum MatchIssue: Equatable {
    case ready, confirmName, confirmQuantity, unavailable, missingQuantity
}

struct GroceryMatch: Identifiable, Equatable {
    let id: Int
    let request: GroceryRequest
    let product: GrocerySKU?
    let packs: Int
    let issue: MatchIssue
    var approved = false
    var skipped = false

    var resolved: Bool { skipped || issue == .ready || approved }
    var total: Int { (product?.price ?? 0) * packs }
}

enum GroceryMatcher {
    private static let amountPattern = try! NSRegularExpression(pattern: #"(?i)(?<![\p{L}\d])(\d+(?:\.\d+)?)\s*(kilograms?|kgs?|grams?|gms?|gm|g|litres?|liters?|l|millilitres?|milliliters?|ml|pieces?|pcs?|packets?|packs?)?(?![\p{L}])"#)

    static func parse(_ text: String) -> [GroceryRequest] {
        text.components(separatedBy: CharacterSet(charactersIn: "\n,;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                let clean = line.replacingOccurrences(of: #"^\s*(?:[-•*]\s+|\d+[.)]\s+)"#, with: "", options: .regularExpression)
                let range = NSRange(clean.startIndex..<clean.endIndex, in: clean)
                guard let match = amountPattern.firstMatch(in: clean, range: range),
                      let full = Range(match.range, in: clean),
                      let numberRange = Range(match.range(at: 1), in: clean),
                      let number = Double(clean[numberRange]) else {
                    return GroceryRequest(original: line, name: normalize(clean), amount: nil, unit: nil, explicitUnit: false)
                }
                let unitText = Range(match.range(at: 2), in: clean).map { String(clean[$0]).lowercased() } ?? ""
                let unit: GroceryUnit
                let multiplier: Double
                switch unitText {
                case "kg", "kgs", "kilogram", "kilograms": unit = .grams; multiplier = 1000
                case "g", "gm", "gms", "gram", "grams": unit = .grams; multiplier = 1
                case "l", "liter", "liters", "litre", "litres": unit = .millilitres; multiplier = 1000
                case "ml", "milliliter", "milliliters", "millilitre", "millilitres": unit = .millilitres; multiplier = 1
                case "pack", "packs", "packet", "packets": unit = .packs; multiplier = 1
                default: unit = .pieces; multiplier = 1
                }
                var name = clean
                name.removeSubrange(full)
                return GroceryRequest(original: line, name: normalize(name), amount: Int(number * multiplier), unit: unit, explicitUnit: !unitText.isEmpty)
            }
    }

    static func match(_ text: String, catalogue: [GrocerySKU] = DemoGroceries.items) -> [GroceryMatch] {
        parse(text).enumerated().map { index, request in
            let exactNames = catalogue.filter { sku in sku.aliases.contains(request.name) }
            let candidates: [GrocerySKU]
            if !exactNames.isEmpty {
                candidates = exactNames
            } else {
                let ranked = catalogue.map { sku in
                    (sku, sku.aliases.map { editDistance($0, request.name) }.min() ?? Int.max)
                }.sorted { $0.1 < $1.1 }
                let limit = request.name.count <= 4 ? 1 : 2
                if let first = ranked.first, first.1 <= limit,
                   (ranked.count == 1 || ranked[1].1 > first.1) {
                    candidates = [first.0]
                } else {
                    candidates = []
                }
            }
            guard !candidates.isEmpty else {
                return GroceryMatch(id: index, request: request, product: nil, packs: 0, issue: .unavailable)
            }
            guard let amount = request.amount, amount > 0, let unit = request.unit else {
                return GroceryMatch(id: index, request: request, product: candidates.first, packs: 0, issue: .missingQuantity)
            }
            let compatible = candidates.filter { $0.unit == unit || unit == .packs }
            guard let product = compatible.min(by: { left, right in
                let leftGap = max(0, Int(ceil(Double(amount) / Double(left.amount))) * left.amount - amount)
                let rightGap = max(0, Int(ceil(Double(amount) / Double(right.amount))) * right.amount - amount)
                return leftGap == rightGap ? left.price < right.price : leftGap < rightGap
            }) else {
                return GroceryMatch(id: index, request: request, product: candidates.first, packs: 0, issue: .confirmQuantity)
            }
            let packs = unit == .packs ? amount : Int(ceil(Double(amount) / Double(product.amount)))
            guard packs > 0 && packs <= 20 else {
                return GroceryMatch(id: index, request: request, product: product, packs: 0, issue: .confirmQuantity)
            }
            let exact = unit != .packs && packs * product.amount == amount
            let englishName = product.aliases.prefix(2).contains(request.name)
            let issue: MatchIssue = !exact || !request.explicitUnit ? .confirmQuantity : (englishName && !product.requiresNameApproval ? .ready : .confirmName)
            return GroceryMatch(id: index, request: request, product: product, packs: packs, issue: issue)
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func editDistance(_ left: String, _ right: String) -> Int {
        let a = Array(left), b = Array(right)
        var previous = Array(0...b.count)
        for (i, character) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, other) in b.enumerated() {
                current[j + 1] = min(previous[j + 1] + 1,
                                     current[j] + 1,
                                     previous[j] + (character == other ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
