import SwiftUI
import SwiftData

@main
struct PantryApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CachedOrder.self, CachedOrderItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ScaffoldPlaceholderView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
