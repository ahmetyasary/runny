import WidgetKit
import SwiftUI
import ActivityKit

@main
struct RunnyWidgetsBundle: WidgetBundle {
  var body: some Widget {
    RunnyLiveActivityWidget()
  }
}

struct RunnyLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RunnyActivityAttributes.self) { context in
      // Lock screen / banner
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(context.attributes.activityType)
            .font(.headline)
          Text(context.state.isRecording ? "Kayıt devam ediyor" : "Bitti")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(Self.formatElapsed(context.state.elapsedSeconds))
            .font(.title3.monospacedDigit().weight(.bold))
          Text(String(format: "%.2f km", context.state.distanceMeters / 1000))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      .padding(14)
      .activityBackgroundTint(Color.black.opacity(0.85))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.attributes.activityType)
            .font(.caption.weight(.semibold))
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(Self.formatElapsed(context.state.elapsedSeconds))
            .font(.caption.monospacedDigit().weight(.bold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Label(
              String(format: "%.2f km", context.state.distanceMeters / 1000),
              systemImage: "figure.run"
            )
            Spacer()
            if let hr = context.state.heartRateBpm {
              Label(String(format: "%.0f", hr), systemImage: "heart.fill")
                .foregroundStyle(.red)
            }
            Label(
              String(format: "%.0f m", context.state.elevationGainMeters),
              systemImage: "mountain.2.fill"
            )
          }
          .font(.caption2)
        }
      } compactLeading: {
        Image(systemName: "figure.run")
      } compactTrailing: {
        Text(Self.formatElapsed(context.state.elapsedSeconds))
          .font(.caption2.monospacedDigit())
          .minimumScaleFactor(0.6)
      } minimal: {
        Image(systemName: "figure.run")
      }
    }
  }

  private static func formatElapsed(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
  }
}
