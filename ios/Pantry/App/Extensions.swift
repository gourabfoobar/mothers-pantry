import Foundation

extension Array {
    /// `removeLast()` traps on an empty array; navigation-path pops should
    /// just no-op instead (e.g. a screen shown standalone by the debug host).
    mutating func safePop() {
        if !isEmpty { removeLast() }
    }
}

/// The backend always emits timestamps via JS's `Date.toISOString()`, which
/// always includes milliseconds ("...2026-09-26T14:36:38.184Z") — a bare
/// `ISO8601DateFormatter()` can't parse that without `.withFractionalSeconds`
/// and silently returns nil. Every screen should parse dates through this.
private let isoWithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()
private let isoWithoutFractionalSeconds = ISO8601DateFormatter()

extension String {
    /// Parses this string as an ISO 8601 timestamp, with or without fractional seconds.
    var asISODate: Date? {
        isoWithFractionalSeconds.date(from: self) ?? isoWithoutFractionalSeconds.date(from: self)
    }
}
