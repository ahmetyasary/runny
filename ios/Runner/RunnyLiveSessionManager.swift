import ActivityKit
import Foundation
import HealthKit
import UserNotifications

enum RunnyWorkoutMapper {
  static func configuration(for label: String) -> HKWorkoutConfiguration {
    let config = HKWorkoutConfiguration()
    config.activityType = activityType(for: label)
    config.locationType = isIndoor(label) ? .indoor : .outdoor
    return config
  }

  static func activityType(for label: String) -> HKWorkoutActivityType {
    switch label {
    case "Yürüyüş": return .walking
    case "Koşu": return .running
    case "Bisiklet": return .cycling
    case "Yüzme": return .swimming
    case "Hiking", "Trail": return .hiking
    case "Fitness": return .traditionalStrengthTraining
    case "Yoga": return .yoga
    default: return .running
    }
  }

  static func isIndoor(_ label: String) -> Bool {
    label == "Fitness" || label == "Yoga"
  }
}

final class RunnyLiveSessionManager {
  static let shared = RunnyLiveSessionManager()

  private var activityBox: Any?
  private let healthStore = HKHealthStore()

  func launchWatchApp(activityType: String) {
    let config = RunnyWorkoutMapper.configuration(for: activityType)
    healthStore.startWatchApp(with: config) { success, error in
      if let error {
        NSLog("Runny startWatchApp error: \(error.localizedDescription)")
      } else {
        NSLog("Runny startWatchApp success=\(success)")
      }
    }
  }

  @MainActor
  func startLiveActivity(
    activityType: String,
    elapsedSeconds: Int,
    distanceMeters: Double,
    heartRateBpm: Double?,
    elevationGainMeters: Double
  ) {
    guard #available(iOS 16.2, *) else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let attributes = RunnyActivityAttributes(activityType: activityType)
    let state = RunnyActivityAttributes.ContentState(
      elapsedSeconds: elapsedSeconds,
      distanceMeters: distanceMeters,
      heartRateBpm: heartRateBpm,
      elevationGainMeters: elevationGainMeters,
      isRecording: true
    )

    endLiveActivity()

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: .init(state: state, staleDate: nil),
        pushType: nil
      )
      activityBox = activity
    } catch {
      NSLog("Runny Live Activity start error: \(error.localizedDescription)")
    }
  }

  @MainActor
  func updateLiveActivity(
    elapsedSeconds: Int,
    distanceMeters: Double,
    heartRateBpm: Double?,
    elevationGainMeters: Double,
    isRecording: Bool
  ) {
    guard #available(iOS 16.2, *) else { return }
    guard let activity = activityBox as? Activity<RunnyActivityAttributes> else { return }
    let state = RunnyActivityAttributes.ContentState(
      elapsedSeconds: elapsedSeconds,
      distanceMeters: distanceMeters,
      heartRateBpm: heartRateBpm,
      elevationGainMeters: elevationGainMeters,
      isRecording: isRecording
    )
    Task {
      await activity.update(.init(state: state, staleDate: nil))
    }
  }

  @MainActor
  func endLiveActivity() {
    guard #available(iOS 16.2, *) else { return }
    guard let activity = activityBox as? Activity<RunnyActivityAttributes> else { return }
    let finalState = activity.content.state
    Task {
      await activity.end(
        .init(state: finalState, staleDate: nil),
        dismissalPolicy: .immediate
      )
    }
    activityBox = nil
  }

  func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { _, _ in }
  }

  func notifyLocal(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "runny.activity.\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }
}
