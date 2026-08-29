import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct RunnyActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var elapsedSeconds: Int
    var distanceMeters: Double
    var heartRateBpm: Double?
    var elevationGainMeters: Double
    var isRecording: Bool
  }

  var activityType: String
}
