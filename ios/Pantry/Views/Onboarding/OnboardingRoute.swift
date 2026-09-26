import Foundation

/// Navigation path for the sign-up flow (canvas row 01). Screens push the
/// next route on their primary CTA; back navigation is the system pop.
enum OnboardingRoute: Hashable {
    case phone
    case otp(phone: String)
    case name(phone: String)
    case providerPicker
    case providerAuthorize(providerId: String, providerName: String)
    case providerConnected
}
