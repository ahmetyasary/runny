import Foundation
import HealthKit
import CoreMotion
import Combine

/// Saat üzerinde canlı workout: nabız, yükselti, mesafe (HK).
@MainActor
final class WatchHealthManager: NSObject, ObservableObject {
  static let shared = WatchHealthManager()

  @Published private(set) var heartRateBpm: Double?
  @Published private(set) var averageHeartRateBpm: Double?
  @Published private(set) var maxHeartRateBpm: Double?
  @Published private(set) var activeEnergyKcal: Double = 0
  @Published private(set) var elevationGainMeters: Double = 0
  @Published private(set) var altitudeMeters: Double?
  @Published private(set) var distanceMeters: Double = 0
  @Published private(set) var isAuthorized = false
  @Published private(set) var isRunning = false
  @Published private(set) var statusMessage: String?

  private let store = HKHealthStore()
  private let altimeter = CMAltimeter()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var baselineAltitude: Double?
  private var lastRelativeAltitude: Double = 0
  private var heartRateSamples: [Double] = []

  private let typesToRead: Set<HKObjectType> = [
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
    HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
    HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
    HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
  ]

  private let typesToShare: Set<HKSampleType> = [
    HKObjectType.workoutType(),
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
    HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
    HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
  ]

  func requestAuthorization() async {
    guard HKHealthStore.isHealthDataAvailable() else {
      statusMessage = "HealthKit yok"
      return
    }
    do {
      try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
      isAuthorized = true
      statusMessage = nil
    } catch {
      statusMessage = "Sağlık izni gerekli"
      isAuthorized = false
    }
  }

  func start(activityLabel: String) async {
    await requestAuthorization()
    guard !isRunning else { return }

    resetMetrics()

    let config = HKWorkoutConfiguration()
    config.activityType = Self.mapActivity(activityLabel)
    config.locationType = Self.isIndoor(activityLabel) ? .indoor : .outdoor

    do {
      let workoutSession = try HKWorkoutSession(healthStore: store, configuration: config)
      let workoutBuilder = workoutSession.associatedWorkoutBuilder()
      workoutBuilder.dataSource = HKLiveWorkoutDataSource(
        healthStore: store,
        workoutConfiguration: config
      )

      workoutSession.delegate = self
      workoutBuilder.delegate = self

      session = workoutSession
      builder = workoutBuilder

      let start = Date()
      workoutSession.startActivity(with: start)
      try await workoutBuilder.beginCollection(at: start)

      isRunning = true
      statusMessage = nil
      startAltimeter()
    } catch {
      statusMessage = "Workout başlatılamadı"
      NSLog("WatchHealth start error: \(error.localizedDescription)")
    }
  }

  func stop() async {
    stopAltimeter()
    guard isRunning else { return }

    let end = Date()
    session?.end()
    do {
      try await builder?.endCollection(at: end)
      try await builder?.finishWorkout()
    } catch {
      NSLog("WatchHealth stop error: \(error.localizedDescription)")
    }

    session = nil
    builder = nil
    isRunning = false
  }

  private func resetMetrics() {
    heartRateBpm = nil
    averageHeartRateBpm = nil
    maxHeartRateBpm = nil
    activeEnergyKcal = 0
    elevationGainMeters = 0
    altitudeMeters = nil
    distanceMeters = 0
    baselineAltitude = nil
    lastRelativeAltitude = 0
    heartRateSamples = []
  }

  private func startAltimeter() {
    guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
    altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
      guard let self, let data, error == nil else { return }
      Task { @MainActor in
        let relative = data.relativeAltitude.doubleValue
        if self.baselineAltitude == nil {
          self.baselineAltitude = relative
        }
        let delta = relative - self.lastRelativeAltitude
        if delta > 0.3 {
          self.elevationGainMeters += delta
        }
        self.lastRelativeAltitude = relative
        if let baseline = self.baselineAltitude {
          self.altitudeMeters = relative - baseline
        }
      }
    }
  }

  private func stopAltimeter() {
    altimeter.stopRelativeAltitudeUpdates()
  }

  private func update(from statistics: HKStatistics?) {
    guard let statistics else { return }

    if statistics.quantityType == HKQuantityType(.heartRate),
       let quantity = statistics.mostRecentQuantity() {
      let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
      heartRateBpm = bpm
      heartRateSamples.append(bpm)
      if heartRateSamples.count > 600 {
        heartRateSamples.removeFirst(heartRateSamples.count - 600)
      }
      averageHeartRateBpm = heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
      maxHeartRateBpm = heartRateSamples.max()
    }

    if statistics.quantityType == HKQuantityType(.activeEnergyBurned),
       let quantity = statistics.sumQuantity() {
      activeEnergyKcal = quantity.doubleValue(for: .kilocalorie())
    }

    let distanceTypes: [HKQuantityTypeIdentifier] = [
      .distanceWalkingRunning, .distanceCycling, .distanceSwimming,
    ]
    if distanceTypes.contains(where: { statistics.quantityType == HKQuantityType($0) }),
       let quantity = statistics.sumQuantity() {
      distanceMeters = max(distanceMeters, quantity.doubleValue(for: .meter()))
    }
  }

  static func mapActivity(_ label: String) -> HKWorkoutActivityType {
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

extension WatchHealthManager: HKWorkoutSessionDelegate {
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {
    Task { @MainActor in
      switch toState {
      case .running:
        self.isRunning = true
      case .ended, .stopped:
        // Beklenmedik kapanışta ensureHealthRunning yeniden başlatabilsin.
        self.isRunning = false
        self.session = nil
        self.builder = nil
        self.stopAltimeter()
      case .paused:
        break
      default:
        break
      }
    }
  }

  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didFailWithError error: Error
  ) {
    Task { @MainActor in
      self.statusMessage = "Workout hatası"
      self.isRunning = false
      self.session = nil
      self.builder = nil
      self.stopAltimeter()
    }
  }
}

extension WatchHealthManager: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    Task { @MainActor in
      for type in collectedTypes {
        guard let quantityType = type as? HKQuantityType else { continue }
        let stats = workoutBuilder.statistics(for: quantityType)
        self.update(from: stats)
      }
    }
  }

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
