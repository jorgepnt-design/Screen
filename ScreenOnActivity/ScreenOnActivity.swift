import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ScreenOnWidgets: WidgetBundle {
    var body: some Widget { ScreenOnLiveActivity() }
}

struct ScreenOnLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenActivityAttributes.self) { context in
            ActivityDetails(context: context)
                .padding()
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ActivityDetails(context: context)
                }
            } compactLeading: {
                Image(systemName: confirmed(context) ? "sun.max.fill" : "questionmark.circle")
                    .foregroundStyle(confirmed(context) ? Color.green : Color.orange)
            } compactTrailing: {
                Text(confirmed(context) ? "ON" : "–").foregroundStyle(confirmed(context) ? Color.green : Color.orange)
            } minimal: {
                Image(systemName: confirmed(context) ? "sun.max.fill" : "questionmark.circle")
                    .foregroundStyle(confirmed(context) ? Color.green : Color.orange)
            }
            .keylineTint(.green)
        }
    }

    private func confirmed(_ context: ActivityViewContext<ScreenActivityAttributes>) -> Bool {
        context.state.isActive && !context.isStale
    }
}

private struct ActivityDetails: View {
    let context: ActivityViewContext<ScreenActivityAttributes>
    private var confirmed: Bool { context.state.isActive && !context.isStale }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Screen On", systemImage: confirmed ? "sun.max.fill" : "questionmark.circle")
                .font(.headline).foregroundStyle(confirmed ? Color.green : Color.orange)
            Text(confirmed ? "Bildschirm bleibt eingeschaltet" : "Status nicht bestätigt – App öffnen")
                .font(.subheadline).foregroundStyle(.white)
            if confirmed {
                HStack {
                    Text("Aktiv seit")
                    Text(context.attributes.startedAt, style: .timer).monospacedDigit()
                }.font(.caption).foregroundStyle(.white)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
