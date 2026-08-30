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
  private var lastActivityType: String = "Aktivite"
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
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      NSLog("Runny Live Activity disabled by user/system")
      return
    }

    lastActivityType = activityType.isEmpty ? lastActivityType : activityType

    // Kayıt sürerken zaten aktif bir Live Activity varsa yeniden başlatma;
    // sadece içeriği güncelle (yanlışlıkla kapanmayı azaltır).
    if activeLiveActivity() != nil {
      updateLiveActivity(
        elapsedSeconds: elapsedSeconds,
        distanceMeters: distanceMeters,
        heartRateBpm: heartRateBpm,
        elevationGainMeters: elevationGainMeters,
        isRecording: true,
        activityType: lastActivityType
      )
      return
    }

    let attributes = RunnyActivityAttributes(activityType: lastActivityType)
    let state = RunnyActivityAttributes.ContentState(
      elapsedSeconds: elapsedSeconds,
      distanceMeters: distanceMeters,
      heartRateBpm: heartRateBpm,
      elevationGainMeters: elevationGainMeters,
      isRecording: true
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: .init(
          state: state,
          // Sistemin "stale" işaretlemesini geciktir — kayıt süresince canlı kalsın.
          staleDate: Date().addingTimeInterval(8 * 60)
        ),
        pushType: nil
      )
      activityBox = activity
      NSLog("Runny Live Activity started id=\(activity.id)")
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
    isRecording: Bool,
    activityType: String? = nil
  ) {
    guard #available(iOS 16.2, *) else { return }

    if let activityType, !activityType.isEmpty {
      lastActivityType = activityType
    }

    // Kayıt devam ediyorsa Live Activity yoksa / düşmüşse yeniden ayağa kaldır.
    guard isRecording else { return }

    guard let activity = activeLiveActivity() else {
      startLiveActivity(
        activityType: lastActivityType,
        elapsedSeconds: elapsedSeconds,
        distanceMeters: distanceMeters,
        heartRateBpm: heartRateBpm,
        elevationGainMeters: elevationGainMeters
      )
      return
    }

    let state = RunnyActivityAttributes.ContentState(
      elapsedSeconds: elapsedSeconds,
      distanceMeters: distanceMeters,
      heartRateBpm: heartRateBpm,
      elevationGainMeters: elevationGainMeters,
      isRecording: true
    )
    Task {
      await activity.update(
        .init(state: state, staleDate: Date().addingTimeInterval(8 * 60))
      )
    }
  }

  @MainActor
  func endLiveActivity(
    elapsedSeconds: Int? = nil,
    distanceMeters: Double? = nil,
    heartRateBpm: Double? = nil,
    elevationGainMeters: Double? = nil
  ) {
    guard #available(iOS 16.2, *) else { return }

    let targets = allTrackedActivities()
    guard !targets.isEmpty else {
      activityBox = nil
      return
    }

    for activity in targets {
      var finalState = activity.content.state
      finalState.isRecording = false
      if let elapsedSeconds { finalState.elapsedSeconds = elapsedSeconds }
      if let distanceMeters { finalState.distanceMeters = distanceMeters }
      if let heartRateBpm { finalState.heartRateBpm = heartRateBpm }
      if let elevationGainMeters { finalState.elevationGainMeters = elevationGainMeters }

      Task {
        // Kısa final görünüm, sonra biz kapatıyoruz — kullanıcı swipe etmeden kaybolur.
        await activity.end(
          .init(state: finalState, staleDate: nil),
          dismissalPolicy: .after(Date().addingTimeInterval(4))
        )
      }
    }
    activityBox = nil
  }

  @available(iOS 16.2, *)
  @MainActor
  private func activeLiveActivity() -> Activity<RunnyActivityAttributes>? {
    if let boxed = activityBox as? Activity<RunnyActivityAttributes> {
      switch boxed.activityState {
      case .active, .stale:
        return boxed
      case .ended, .dismissed:
        activityBox = nil
      @unknown default:
        activityBox = nil
      }
    }

    for activity in Activity<RunnyActivityAttributes>.activities {
      switch activity.activityState {
      case .active, .stale:
        activityBox = activity
        return activity
      case .ended, .dismissed:
        continue
      @unknown default:
        continue
      }
    }
    return nil
  }

  @available(iOS 16.2, *)
  @MainActor
  private func allTrackedActivities() -> [Activity<RunnyActivityAttributes>] {
    var list = Activity<RunnyActivityAttributes>.activities.filter {
      $0.activityState == .active || $0.activityState == .stale
    }
    if let boxed = activityBox as? Activity<RunnyActivityAttributes>,
       (boxed.activityState == .active || boxed.activityState == .stale),
       !list.contains(where: { $0.id == boxed.id }) {
      list.append(boxed)
    }
    return list
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
