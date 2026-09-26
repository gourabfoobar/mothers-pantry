import WidgetKit
import SwiftUI

@main
struct PantryWidgetBundle: WidgetBundle {
    var body: some Widget {
        PantryOrderLiveActivity()
    }
}

/// Placeholder Live Activity — built out at milestone 10 to match
/// canvas screens 5.1 (Lock Screen) and 5.2 (Dynamic Island).
struct PantryOrderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PantryOrderActivityAttributes.self) { context in
            Text(context.state.status)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                }
            } compactLeading: {
                Text("母")
            } compactTrailing: {
                Text(context.state.etaText)
            } minimal: {
                Text("母")
            }
        }
    }
}
