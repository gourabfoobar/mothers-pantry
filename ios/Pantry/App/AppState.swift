import Observation
import Foundation

/// App-wide session state, shared via the environment. Screens read/mutate
/// this rather than each holding their own copy of "am I signed in".
@MainActor
@Observable
final class AppState {
    var isSignedIn: Bool
    var profile: UserProfile?
    var providerConnection: ProviderConnectionInfo?

    init() {
        isSignedIn = APIClient.shared.isSignedIn
    }

    func finishSignIn(profile: UserProfile?) {
        self.profile = profile
        isSignedIn = true
    }

    func signOut() {
        APIClient.shared.signOut()
        profile = nil
        providerConnection = nil
        isSignedIn = false
    }
}
