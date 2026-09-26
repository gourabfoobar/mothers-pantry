import WidgetKit
import SwiftUI
import ActivityKit

@main
struct PantryWidgetBundle: WidgetBundle {
    var body: some Widget {
        PantryOrderLiveActivity()
    }
}

/// Canvas 5.1 (Lock Screen) and 5.2 (Dynamic Island compact/minimal/expanded).
struct PantryOrderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PantryOrderActivityAttributes.self) { context in
            LiveActivityCard(attributes: context.attributes, state: context.state)
                .padding(18)
                .activityBackgroundTint(Theme.darkSurface)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SealMark(size: 30, background: Theme.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CompactEta(state: context.state)
                        .frame(width: 60)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(PantryOrderStage(rawValue: context.state.stage)?.label ?? "")
                        .font(.mono(15, weight: .bold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityBody(state: context.state, showCallButtons: true)
                }
            } compactLeading: {
                SealMark(size: 22, cornerRadius: 6, background: Theme.accent)
            } compactTrailing: {
                CompactEta(state: context.state)
            } minimal: {
                SealMark(size: 20, cornerRadius: 6, background: Theme.accent)
            }
        }
    }
}
