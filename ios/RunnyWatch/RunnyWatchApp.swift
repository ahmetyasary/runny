import SwiftUI
import MapKit
import WatchConnectivity
import Combine
import WatchKit
import UserNotifications

@main
struct RunnyWatchApp: App {
  @StateObject private var session = WatchActivityModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(session)
    }
  }
}

struct WatchSport: Identifiable, Hashable {
  let id: String
  let label: String
  let symbol: String
  let tint: Color
}

enum WatchSports {
  static let all: [WatchSport] = [
    WatchSport(id: "walk", label: "Yürüyüş", symbol: "figure.walk", tint: Color(red: 0.29, green: 0.61, blue: 0.91)),
    WatchSport(id: "run", label: "Koşu", symbol: "figure.run", tint: Color(red: 0.29, green: 0.72, blue: 0.42)),
    WatchSport(id: "bike", label: "Bisiklet", symbol: "bicycle", tint: Color(red: 1.0, green: 0.63, blue: 0.29)),
    WatchSport(id: "swim", label: "Yüzme", symbol: "figure.pool.swim", tint: Color(red: 0.16, green: 0.66, blue: 0.63)),
    WatchSport(id: "hike", label: "Hiking", symbol: "figure.hiking", tint: Color(red: 0.61, green: 0.48, blue: 0.87)),
    WatchSport(id: "trail", label: "Trail", symbol: "figure.walk.motion", tint: Color(red: 0.48, green: 0.61, blue: 0.29)),
    WatchSport(id: "gym", label: "Fitness", symbol: "dumbbell.fill", tint: Color(red: 0.88, green: 0.36, blue: 0.39)),
    WatchSport(id: "yoga", label: "Yoga", symbol: "figure.yoga", tint: Color(red: 0.43, green: 0.38, blue: 0.77)),
  ]

  static func sport(forLabel label: String) -> WatchSport? {
    all.first { $0.label == label }
  }

  static func sport(forTypeKey key: String) -> WatchSport? {
    switch key {
    case "walk": return all.first { $0.id == "walk" }
    case "run": return all.first { $0.id == "run" }
    case "bike": return all.first { $0.id == "bike" }
    case "swim": return all.first { $0.id == "swim" }
    case "hike": return all.first { $0.id == "hike" }
    case "trail": return all.first { $0.id == "trail" }
    case "gym": return all.first { $0.id == "gym" }
    case "yoga": return all.first { $0.id == "yoga" }
    default: return sport(forLabel: key)
    }
  }
}

struct WatchRecentActivity: Identifiable, Hashable {
  let id: String
  let typeLabel: String
  let typeKey: String
  let title: String
  let distanceKm: Double
  let durationSeconds: Int
  let durationLabel: String
  let calories: Int
  let elevationGainMeters: Int
  let avgHeartRate: Int?
  let maxHeartRate: Int?
  let paceLabel: String?
  let whenLabel: String
  let location: String

  var sport: WatchSport {
    WatchSports.sport(forTypeKey: typeKey)
      ?? WatchSports.sport(forLabel: typeLabel)
      ?? WatchSports.all[1]
  }

  var distanceLabel: String {
    String(format: "%.2f km", distanceKm)
  }

  static func fromDictionary(_ dict: [String: Any]) -> WatchRecentActivity? {
    guard let id = dict["id"] as? String else { return nil }
    let typeLabel = (dict["type"] as? String) ?? "Aktivite"
    let typeKey = (dict["typeKey"] as? String) ?? typeLabel
    let title = (dict["title"] as? String) ?? typeLabel
    let distanceKm = (dict["distanceKm"] as? Double)
      ?? (dict["distanceKm"] as? NSNumber)?.doubleValue
      ?? 0
    let durationSeconds = (dict["durationSeconds"] as? Int)
      ?? (dict["durationSeconds"] as? NSNumber)?.intValue
      ?? 0
    let durationLabel = (dict["durationLabel"] as? String)
      ?? formatDuration(durationSeconds)
    let calories = (dict["calories"] as? Int)
      ?? (dict["calories"] as? NSNumber)?.intValue
      ?? 0
    let elevation = (dict["elevationGainMeters"] as? Int)
      ?? (dict["elevationGainMeters"] as? NSNumber)?.intValue
      ?? 0
    let avgHr = (dict["avgHeartRate"] as? Int)
      ?? (dict["avgHeartRate"] as? NSNumber)?.intValue
    let maxHr = (dict["maxHeartRate"] as? Int)
      ?? (dict["maxHeartRate"] as? NSNumber)?.intValue
    let pace = dict["paceLabel"] as? String
    let when = (dict["when"] as? String) ?? ""
    let location = (dict["location"] as? String) ?? ""

    return WatchRecentActivity(
      id: id,
      typeLabel: typeLabel,
      typeKey: typeKey,
      title: title,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      durationLabel: durationLabel,
      calories: calories,
      elevationGainMeters: elevation,
      avgHeartRate: avgHr,
      maxHeartRate: maxHr,
      paceLabel: pace,
      whenLabel: when,
      location: location
    )
  }

  private static func formatDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
  }
}

@MainActor
final class WatchActivityModel: NSObject, ObservableObject, WCSessionDelegate {
  @Published var activityType: String = "—"
  @Published var elapsedSeconds: Int = 0
  @Published var distanceMeters: Double = 0
  @Published var isRecording: Bool = false
  @Published var phoneReachable: Bool = false
  /// Aktiviteyi kim başlattı: "watch" | "phone" | nil
  @Published var sessionOwner: String? = nil
  @Published var recentActivities: [WatchRecentActivity] = []
  @Published var latitude: Double?
  @Published var longitude: Double?
  /// Telefon GPS noktalarından biriken rota.
  @Published var routeCoordinates: [CLLocationCoordinate2D] = []
  @Published var isCountingDown = false
  @Published var countdownValue = 3

  let health = WatchHealthManager.shared
  private var healthCancellable: AnyCancellable?
  private var pushTimer: Timer?
  private var healthTickTimer: Timer?
  private var countdownTimer: Timer?
  private var elapsedTimer: Timer?
  private var recordingStartedAt: Date?
  private var lastOfflineSyncAt: Date?
  /// Yerel/uzak stop sonrası telefondan gelen update ile yeniden başlamayı engelle.
  private var ignoreRemoteStartUntil: Date?
  private var pendingSportLabel: String?

  override init() {
    super.init()
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
    healthCancellable = health.objectWillChange.sink { [weak self] _ in
      self?.objectWillChange.send()
      self?.scheduleHealthPush()
    }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    loadRecentActivitiesFromDisk()
  }

  private static let recentActivitiesKey = "runny.recentActivities"

  private func loadRecentActivitiesFromDisk() {
    guard let data = UserDefaults.standard.array(forKey: Self.recentActivitiesKey) as? [[String: Any]] else {
      return
    }
    recentActivities = data.compactMap(WatchRecentActivity.fromDictionary)
  }

  private func persistRecentActivities() {
    let encoded: [[String: Any]] = recentActivities.map { item in
      var map: [String: Any] = [
        "id": item.id,
        "type": item.typeLabel,
        "typeKey": item.typeKey,
        "title": item.title,
        "distanceKm": item.distanceKm,
        "durationSeconds": item.durationSeconds,
        "durationLabel": item.durationLabel,
        "calories": item.calories,
        "elevationGainMeters": item.elevationGainMeters,
        "when": item.whenLabel,
        "location": item.location,
      ]
      if let avg = item.avgHeartRate { map["avgHeartRate"] = avg }
      if let max = item.maxHeartRate { map["maxHeartRate"] = max }
      if let pace = item.paceLabel { map["paceLabel"] = pace }
      return map
    }
    UserDefaults.standard.set(encoded, forKey: Self.recentActivitiesKey)
  }

  func applyRecentActivities(from context: [String: Any]) {
    let raw = context["activities"] as? [[String: Any]]
      ?? context["recentActivities"] as? [[String: Any]]
      ?? []
    recentActivities = Array(raw.compactMap(WatchRecentActivity.fromDictionary).prefix(5))
    persistRecentActivities()
  }

  var formattedElapsed: String {
    let h = elapsedSeconds / 3600
    let m = (elapsedSeconds % 3600) / 60
    let s = elapsedSeconds % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
  }

  var displayDistanceMeters: Double {
    max(distanceMeters, health.distanceMeters)
  }

  var formattedDistance: String {
    String(format: "%.2f km", displayDistanceMeters / 1000.0)
  }

  var paceLabel: String {
    let meters = displayDistanceMeters
    guard meters > 20, elapsedSeconds > 0 else { return "--'--\"" }
    let secPerKm = Double(elapsedSeconds) / (meters / 1000.0)
    let m = Int(secPerKm) / 60
    let s = Int(secPerKm) % 60
    return String(format: "%d'%02d\"", m, s)
  }

  var isWatchPrimary: Bool { sessionOwner == "watch" }
  var isPhonePrimary: Bool { sessionOwner == "phone" }

  var heartLabel: String {
    if let bpm = health.heartRateBpm {
      return String(format: "%.0f", bpm)
    }
    return "—"
  }

  var elevationLabel: String {
    String(format: "%.0f m", health.elevationGainMeters)
  }

  var caloriesLabel: String {
    String(format: "%.0f", health.activeEnergyKcal)
  }

  var hasLocation: Bool {
    latitude != nil && longitude != nil
  }

  var coordinate: CLLocationCoordinate2D? {
    guard let latitude, let longitude else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  var activeSport: WatchSport? {
    WatchSports.sport(forLabel: activityType)
  }

  func beginCountdown(type: String) {
    guard !isRecording, !isCountingDown else { return }
    pendingSportLabel = type
    activityType = type
    countdownValue = 3
    isCountingDown = true
    WKInterfaceDevice.current().play(.click)
    countdownTimer?.invalidate()
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tickCountdown()
      }
    }
  }

  func cancelCountdown() {
    countdownTimer?.invalidate()
    countdownTimer = nil
    isCountingDown = false
    countdownValue = 3
    pendingSportLabel = nil
    if !isRecording {
      activityType = "—"
    }
  }

  private func tickCountdown() {
    guard isCountingDown else { return }
    if countdownValue <= 1 {
      countdownTimer?.invalidate()
      countdownTimer = nil
      isCountingDown = false
      let type = pendingSportLabel ?? activityType
      pendingSportLabel = nil
      WKInterfaceDevice.current().play(.start)
      requestStart(type: type)
      return
    }
    countdownValue -= 1
    WKInterfaceDevice.current().play(.click)
  }

  func requestStart(type: String) {
    cancelCountdown()
    isRecording = true
    sessionOwner = "watch"
    ignoreRemoteStartUntil = nil
    activityType = type
    distanceMeters = 0
    routeCoordinates = []
    lastOfflineSyncAt = nil
    startElapsedClock(from: 0)
    // Start her zaman kuyruğa da yazılsın (telefon şimdi yoksa sonra gelsin).
    send(buildSnapshot(type: "start", action: "start"), important: true)
    Task { await health.start(activityLabel: type) }
    startHealthTick()
    announceRecordingStarted(remote: false)
  }

  private func startElapsedClock(from seconds: Int) {
    stopElapsedClock()
    let clamped = max(0, seconds)
    recordingStartedAt = Date().addingTimeInterval(-Double(clamped))
    elapsedSeconds = clamped
    elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.isRecording, let start = self.recordingStartedAt else { return }
        self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
      }
    }
  }

  private func stopElapsedClock() {
    elapsedTimer?.invalidate()
    elapsedTimer = nil
    recordingStartedAt = nil
  }

  private func syncElapsedFromPhone(_ seconds: Int) {
    // Saat asıl kaynaksa telefon süresini yok say.
    guard !isWatchPrimary else { return }
    let phone = max(0, seconds)
    // Telefon gerideyse (eski paket) yerel saati geri alma.
    if phone + 1 < elapsedSeconds { return }
    recordingStartedAt = Date().addingTimeInterval(-Double(phone))
    elapsedSeconds = phone
    if isRecording, elapsedTimer == nil {
      startElapsedClock(from: phone)
    }
  }

  private func announceRecordingStarted(remote: Bool) {
    WKInterfaceDevice.current().play(.notification)
    let content = UNMutableNotificationContent()
    content.title = "Runny"
    content.body = remote
      ? "\(activityType) telefondan başladı — kayıt canlı."
      : "\(activityType) kaydı başladı."
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "runny.recording.start",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }

  func requestStop() {
    Task {
      let stopPayload = buildSnapshot(type: "stop", action: "stop")
      isRecording = false
      sessionOwner = nil
      ignoreRemoteStartUntil = Date().addingTimeInterval(15)
      stopElapsedClock()
      stopHealthTick()
      pushTimer?.invalidate()
      pushTimer = nil
      await health.stop()
      send(stopPayload, important: true)
      // İkinci stop — kaçmasın.
      send(stopPayload, important: true)
      routeCoordinates = []
      lastOfflineSyncAt = nil
    }
  }

  private var shouldIgnoreRemoteStart: Bool {
    guard let until = ignoreRemoteStartUntil else { return false }
    if Date() < until { return true }
    ignoreRemoteStartUntil = nil
    return false
  }

  private func startHealthTick() {
    stopHealthTick()
    healthTickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        // Workout düştüyse kayıt sürerken yeniden ayağa kaldır.
        self.ensureHealthRunning()
        self.pushHealthToPhone()
      }
    }
  }

  private func stopHealthTick() {
    healthTickTimer?.invalidate()
    healthTickTimer = nil
  }

  private func appendRoutePoint(_ coordinate: CLLocationCoordinate2D) {
    if let last = routeCoordinates.last {
      let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
      let nextLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
      // Saat belleği için ~8 m'den küçük kaymaları atla.
      if lastLoc.distance(from: nextLoc) < 8 { return }
    }
    routeCoordinates.append(coordinate)
    // Çok uzun aktivitelerde nokta sayısını sınırla.
    if routeCoordinates.count > 800 {
      routeCoordinates = stride(from: 0, to: routeCoordinates.count, by: 2)
        .map { routeCoordinates[$0] }
    }
  }

  private func ensureHealthRunning() {
    guard isRecording, !health.isRunning else { return }
    Task { await health.start(activityLabel: activityType) }
    startHealthTick()
  }

  private func scheduleHealthPush() {
    pushTimer?.invalidate()
    pushTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
      Task { @MainActor in
        self?.pushHealthToPhone()
      }
    }
  }

  private func buildSnapshot(type: String, action: String) -> [String: Any] {
    var payload: [String: Any] = [
      "type": type,
      "action": action,
      "elevationGainMeters": health.elevationGainMeters,
      "activeEnergyKcal": health.activeEnergyKcal,
      "watchDistanceMeters": health.distanceMeters,
      "isRecording": action == "stop"
        ? false
        : (isRecording || action == "start" || action == "sync"),
      "activityType": activityType,
      "elapsedSeconds": elapsedSeconds,
      "distanceMeters": displayDistanceMeters,
      "source": "watch",
      "sessionOwner": sessionOwner ?? "watch",
    ]
    if let started = recordingStartedAt {
      let formatter = ISO8601DateFormatter()
      payload["startedAt"] = formatter.string(from: started)
    }
    if let bpm = health.heartRateBpm { payload["heartRateBpm"] = bpm }
    if let avg = health.averageHeartRateBpm { payload["averageHeartRateBpm"] = avg }
    if let max = health.maxHeartRateBpm { payload["maxHeartRateBpm"] = max }
    if let alt = health.altitudeMeters { payload["altitudeMeters"] = alt }
    if let latitude { payload["latitude"] = latitude }
    if let longitude { payload["longitude"] = longitude }
    return payload
  }

  private func pushHealthToPhone() {
    guard isRecording else { return }
    let session = WCSession.default
    if session.isReachable {
      send(buildSnapshot(type: "health", action: "health"))
      return
    }
    // Offline: kuyruğu şişirmemek için ~30 sn'de bir sync snapshot.
    let now = Date()
    if let last = lastOfflineSyncAt, now.timeIntervalSince(last) < 30 {
      return
    }
    lastOfflineSyncAt = now
    send(buildSnapshot(type: "sync", action: "sync"), important: true)
  }

  /// Bağlantı geri gelince kaldığı yerden tek paket aktar.
  private func flushCatchUpToPhone() {
    guard isRecording, !shouldIgnoreRemoteStart else { return }
    lastOfflineSyncAt = Date()
    send(buildSnapshot(type: "sync", action: "sync"), important: true)
    NSLog("Runny Watch: reconnect sync elapsed=\(elapsedSeconds) dist=\(displayDistanceMeters)")
  }

  /// - important: true → reachable değilse transferUserInfo kuyruğuna yaz
  /// - important: false → yalnızca anlık sendMessage (offline'da atlanır)
  private func send(_ payload: [String: Any], important: Bool = false) {
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    if session.isReachable {
      session.sendMessage(payload, replyHandler: nil) { error in
        NSLog("Watch→Phone error: \(error.localizedDescription)")
        // Anlık gönderim başarısızsa kritik paketleri kuyruğa düşür.
        if important {
          session.transferUserInfo(payload)
        }
      }
    } else if important {
      session.transferUserInfo(payload)
    }
  }

  private func apply(_ context: [String: Any]) {
    Task { @MainActor in
      let action = (context["action"] as? String) ?? (context["type"] as? String) ?? ""

      if action == "recentActivities" || context["activities"] is [[String: Any]] {
        self.applyRecentActivities(from: context)
        if action == "recentActivities" { return }
      }

      let incomingOwner = context["sessionOwner"] as? String

      // Telefondan gelen start/stop kesin sınır — yanlışlıkla kapanmayı engelle.
      if action == "start" {
        if self.shouldIgnoreRemoteStart {
          NSLog("Runny Watch: ignore remote start (recent stop)")
          return
        }
        // Saat zaten asıl kayıttaysa telefon start'ı sahipliği çalmaz.
        if self.isWatchPrimary, self.isRecording {
          self.ensureHealthRunning()
          if self.elapsedTimer == nil {
            self.startElapsedClock(from: self.elapsedSeconds)
          }
        } else {
          if let type = context["activityType"] as? String, !type.isEmpty {
            self.activityType = type
          }
          let wasRecording = self.isRecording
          self.isRecording = true
          self.sessionOwner = incomingOwner ?? "phone"
          if !wasRecording {
            self.cancelCountdown()
            self.routeCoordinates = []
            let phoneElapsed = (context["elapsedSeconds"] as? Int)
              ?? (context["elapsedSeconds"] as? Double).map { Int($0) }
              ?? 0
            self.startElapsedClock(from: phoneElapsed)
            self.ensureHealthRunning()
            self.announceRecordingStarted(remote: true)
          } else {
            self.ensureHealthRunning()
            if self.elapsedTimer == nil {
              self.startElapsedClock(from: self.elapsedSeconds)
            }
          }
        }
      } else if action == "stop" {
        let wasRecording = self.isRecording
        self.isRecording = false
        self.sessionOwner = nil
        self.ignoreRemoteStartUntil = Date().addingTimeInterval(15)
        self.pushTimer?.invalidate()
        self.pushTimer = nil
        self.stopElapsedClock()
        self.stopHealthTick()
        if wasRecording {
          await self.health.stop()
          self.routeCoordinates = []
        }
        self.lastOfflineSyncAt = nil
        NSLog("Runny Watch: stopped by remote")
        return
      }

      if let type = context["activityType"] as? String, !type.isEmpty {
        self.activityType = type
      }

      // Süre: yalnızca telefon asılsa (veya sahiplik yokken) telefona uy.
      if self.isRecording, !self.isWatchPrimary {
        if let elapsed = context["elapsedSeconds"] as? Int {
          self.syncElapsedFromPhone(elapsed)
        } else if let elapsed = context["elapsedSeconds"] as? Double {
          self.syncElapsedFromPhone(Int(elapsed))
        }
      }

      // Mesafe: telefon asılsa telefon GPS; saat asılsa yereli koru (health zaten yazar).
      if self.isRecording, !self.isWatchPrimary, let distance = context["distanceMeters"] as? Double {
        self.distanceMeters = distance
      }

      // update/health: kayıt kapalıysa ASLA yeniden başlatma (özellikle stop sonrası).
      if action != "start", action != "stop", let recording = context["isRecording"] as? Bool {
        if recording {
          if self.shouldIgnoreRemoteStart {
            NSLog("Runny Watch: ignore remote recording update (recent stop)")
            return
          }
          if !self.isRecording {
            // Kapalıyken update ile otomatik start yok — yalnızca telefon action=start.
            return
          }
          if self.sessionOwner == nil {
            self.sessionOwner = incomingOwner ?? "phone"
          }
          self.ensureHealthRunning()
          if self.elapsedTimer == nil {
            self.startElapsedClock(from: self.elapsedSeconds)
          }
        }
      }
      var nextLat = self.latitude
      var nextLon = self.longitude
      if let lat = context["latitude"] as? Double {
        nextLat = lat
      } else if let lat = context["latitude"] as? NSNumber {
        nextLat = lat.doubleValue
      }
      if let lon = context["longitude"] as? Double {
        nextLon = lon
      } else if let lon = context["longitude"] as? NSNumber {
        nextLon = lon.doubleValue
      }
      self.latitude = nextLat
      self.longitude = nextLon
      if self.isRecording, let nextLat, let nextLon {
        self.appendRoutePoint(
          CLLocationCoordinate2D(latitude: nextLat, longitude: nextLon)
        )
      }
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      self.phoneReachable = session.isReachable
      if session.isReachable {
        self.flushCatchUpToPhone()
      }
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      let reachable = session.isReachable
      let wasReachable = self.phoneReachable
      self.phoneReachable = reachable
      // Kopukken devam ettiyse bağlanır bağlanmaz anlık durum aktar.
      if reachable, !wasReachable {
        self.flushCatchUpToPhone()
      }
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    apply(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    apply(message)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    apply(userInfo)
  }
}

struct ContentView: View {
  @EnvironmentObject private var session: WatchActivityModel

  var body: some View {
    Group {
      if session.isRecording {
        RecordingPagerView()
      } else if session.isCountingDown {
        CountdownView()
      } else {
        SportPickerView()
      }
    }
  }
}

struct SportPickerView: View {
  @EnvironmentObject private var session: WatchActivityModel

  var body: some View {
    NavigationStack {
      List {
        if !session.recentActivities.isEmpty {
          Section {
            ForEach(session.recentActivities) { activity in
              NavigationLink {
                RecentActivityDetailView(activity: activity)
              } label: {
                RecentActivityRow(activity: activity)
              }
            }
          } header: {
            Text("Son 5 aktivite")
          }
        } else {
          Section {
            VStack(alignment: .leading, spacing: 4) {
              Text("Henüz aktivite yok")
                .font(.caption.weight(.semibold))
              Text("Telefondan senkron gelince burada görünür.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
          } header: {
            Text("Son aktiviteler")
          }
        }

        Section {
          ForEach(WatchSports.all) { sport in
            Button {
              session.beginCountdown(type: sport.label)
            } label: {
              HStack(spacing: 10) {
                ZStack {
                  Circle()
                    .fill(sport.tint.opacity(0.22))
                    .frame(width: 30, height: 30)
                  Image(systemName: sport.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(sport.tint)
                }
                Text(sport.label)
                  .font(.system(.body, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          }
        } header: {
          Text("Yeni aktivite")
        }
      }
      .navigationTitle("Runny")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Image(systemName: "iphone")
            .foregroundStyle(session.phoneReachable ? Color.green : Color.red)
        }
      }
    }
  }
}

struct RecentActivityRow: View {
  let activity: WatchRecentActivity

  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(activity.sport.tint.opacity(0.22))
          .frame(width: 34, height: 34)
        Image(systemName: activity.sport.symbol)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(activity.sport.tint)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(activity.typeLabel)
          .font(.system(.caption, design: .rounded).weight(.bold))
          .foregroundStyle(activity.sport.tint)
        Text(activity.distanceLabel)
          .font(.system(.body, design: .rounded).weight(.semibold))
        HStack(spacing: 6) {
          Text(activity.durationLabel)
          if let pace = activity.paceLabel {
            Text("·")
            Text(pace.replacingOccurrences(of: " /km", with: ""))
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        if !activity.whenLabel.isEmpty {
          Text(activity.whenLabel)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 2)
  }
}

struct RecentActivityDetailView: View {
  let activity: WatchRecentActivity

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          ZStack {
            Circle()
              .fill(activity.sport.tint.opacity(0.25))
              .frame(width: 40, height: 40)
            Image(systemName: activity.sport.symbol)
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(activity.sport.tint)
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(activity.typeLabel)
              .font(.headline.weight(.bold))
              .foregroundStyle(activity.sport.tint)
            if !activity.whenLabel.isEmpty {
              Text(activity.whenLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          Spacer(minLength: 0)
        }

        Text(activity.title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(2)

        LazyVGrid(
          columns: [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
          ],
          spacing: 6
        ) {
          RecentMetricTile(
            title: "Mesafe",
            value: activity.distanceLabel,
            tint: activity.sport.tint
          )
          RecentMetricTile(
            title: "Süre",
            value: activity.durationLabel,
            tint: activity.sport.tint
          )
          if let pace = activity.paceLabel {
            RecentMetricTile(title: "Tempo", value: pace, tint: activity.sport.tint)
          }
          if activity.elevationGainMeters > 0 {
            RecentMetricTile(
              title: "Yükseliş",
              value: "\(activity.elevationGainMeters) m",
              tint: activity.sport.tint
            )
          }
          if activity.calories > 0 {
            RecentMetricTile(
              title: "Kalori",
              value: "\(activity.calories)",
              tint: activity.sport.tint
            )
          }
          if let avg = activity.avgHeartRate {
            RecentMetricTile(title: "Ort. nabız", value: "\(avg)", tint: .red)
          }
          if let max = activity.maxHeartRate {
            RecentMetricTile(title: "Max nabız", value: "\(max)", tint: .red)
          }
        }

        if !activity.location.isEmpty, activity.location != "Konum yok" {
          Label(activity.location, systemImage: "mappin.and.ellipse")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle("Özet")
  }
}

struct RecentMetricTile: View {
  let title: String
  let value: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title.uppercased())
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(tint)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 8)
    .padding(.vertical, 7)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(tint.opacity(0.12))
    )
  }
}

struct CountdownView: View {
  @EnvironmentObject private var session: WatchActivityModel
  private var tint: Color { session.activeSport?.tint ?? .green }

  var body: some View {
    VStack(spacing: 10) {
      if let sport = session.activeSport {
        Label(sport.label, systemImage: sport.symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
      } else {
        Text(session.activityType)
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
      }

      Text("\(session.countdownValue)")
        .font(.system(size: 64, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(tint)
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.2), value: session.countdownValue)
        .frame(maxWidth: .infinity)
        .minimumScaleFactor(0.6)

      Text(session.countdownValue == 0 ? "Başla!" : "Hazırlan…")
        .font(.caption2)
        .foregroundStyle(.secondary)

      Button("Vazgeç") {
        session.cancelCountdown()
      }
      .tint(.red)
      .buttonStyle(.bordered)
    }
    .padding(.horizontal, 6)
  }
}

struct RecordingPagerView: View {
  var body: some View {
    TabView {
      RecordingHeroView()
      RecordingHealthView()
      RecordingLocationView()
    }
    .tabViewStyle(.page)
  }
}

struct RecordingHeroView: View {
  @EnvironmentObject private var session: WatchActivityModel
  private var tint: Color { session.activeSport?.tint ?? .green }

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        HStack(spacing: 6) {
          Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
          Text(session.activityType.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
          Spacer()
          Image(systemName: "iphone")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(session.phoneReachable ? Color.green : Color.red)
        }

        Text(session.formattedElapsed)
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .monospacedDigit()
          .minimumScaleFactor(0.7)
          .frame(maxWidth: .infinity, alignment: .leading)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
          MetricTile(
            title: "MESAFE",
            value: session.formattedDistance,
            symbol: "point.bottomleft.forward.to.point.topright.scurvepath",
            tint: tint
          )
          MetricTile(
            title: "TEMPO",
            value: session.paceLabel,
            symbol: "speedometer",
            tint: .orange
          )
          MetricTile(
            title: "NABIZ",
            value: session.heartLabel,
            unit: "bpm",
            symbol: "heart.fill",
            tint: .red
          )
          MetricTile(
            title: "YÜKSELİŞ",
            value: session.elevationLabel,
            symbol: "mountain.2.fill",
            tint: .cyan
          )
        }

        Button(role: .destructive) {
          session.requestStop()
        } label: {
          Label("Bitir", systemImage: "stop.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      }
      .padding(.horizontal, 4)
    }
  }
}

struct RecordingHealthView: View {
  @EnvironmentObject private var session: WatchActivityModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Label("Sağlık", systemImage: "heart.text.square.fill")
          .font(.headline)

        HealthRow(
          icon: "heart.fill",
          tint: .red,
          title: "Nabız",
          value: session.heartLabel,
          unit: "bpm"
        )
        HealthRow(
          icon: "heart.text.square.fill",
          tint: .pink,
          title: "Ort. nabız",
          value: session.health.averageHeartRateBpm.map { String(format: "%.0f", $0) } ?? "—",
          unit: "bpm"
        )
        HealthRow(
          icon: "bolt.heart.fill",
          tint: .red,
          title: "Max nabız",
          value: session.health.maxHeartRateBpm.map { String(format: "%.0f", $0) } ?? "—",
          unit: "bpm"
        )
        HealthRow(
          icon: "flame.fill",
          tint: .orange,
          title: "Kalori",
          value: session.caloriesLabel,
          unit: "kcal"
        )
        HealthRow(
          icon: "mountain.2.fill",
          tint: .cyan,
          title: "Yükseliş",
          value: String(format: "%.0f", session.health.elevationGainMeters),
          unit: "m"
        )
        HealthRow(
          icon: "arrow.up.and.down",
          tint: .mint,
          title: "Relatif irtifa",
          value: session.health.altitudeMeters.map { String(format: "%.0f", $0) } ?? "—",
          unit: "m"
        )
        HealthRow(
          icon: "figure.run",
          tint: session.activeSport?.tint ?? .green,
          title: "Saat mesafesi",
          value: String(format: "%.2f", session.health.distanceMeters / 1000),
          unit: "km"
        )

        if let msg = session.health.statusMessage {
          Text(msg)
            .font(.caption2)
            .foregroundStyle(.orange)
        } else {
          Text("Veriler Apple Health üzerinden canlı okunuyor.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 4)
    }
  }
}

struct MetricTile: View {
  let title: String
  let value: String
  var unit: String? = nil
  let symbol: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 3) {
        Image(systemName: symbol)
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(tint)
        Text(title)
          .font(.system(size: 9, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
      }
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .monospacedDigit()
          .minimumScaleFactor(0.7)
          .lineLimit(1)
        if let unit {
          Text(unit)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.white.opacity(0.08))
    )
  }
}

struct HealthRow: View {
  let icon: String
  let tint: Color
  let title: String
  let value: String
  let unit: String

  var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundStyle(tint)
        .frame(width: 18)
      Text(title)
        .font(.caption)
      Spacer()
      Text(value)
        .font(.system(.body, design: .rounded).weight(.bold))
        .monospacedDigit()
      Text(unit)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}

struct RecordingLocationView: View {
  @EnvironmentObject private var session: WatchActivityModel
  @State private var position: MapCameraPosition = .automatic

  private var tint: Color { session.activeSport?.tint ?? .green }

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Label("Rota", systemImage: "map")
          .font(.headline)
        Spacer()
        Text("\(session.routeCoordinates.count) nokta")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if let coordinate = session.coordinate {
        Map(position: $position) {
          if session.routeCoordinates.count >= 2 {
            MapPolyline(coordinates: session.routeCoordinates)
              .stroke(
                tint,
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
              )
          }
          Annotation("Şu an", coordinate: coordinate) {
            ZStack {
              Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 18, height: 18)
              Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { fitCamera() }
        .onChange(of: session.routeCoordinates.count) { _, _ in fitCamera() }

        Text(session.formattedDistance)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(tint)
      } else {
        Spacer(minLength: 8)
        Image(systemName: "location.slash")
          .font(.title2)
          .foregroundStyle(.secondary)
        Text("Rota bekleniyor…")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Telefon GPS’i gelince çizgi burada görünür.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Spacer(minLength: 8)
      }
    }
    .padding(.horizontal, 4)
  }

  private func fitCamera() {
    let coords = session.routeCoordinates
    if coords.count >= 2 {
      var minLat = coords[0].latitude
      var maxLat = coords[0].latitude
      var minLon = coords[0].longitude
      var maxLon = coords[0].longitude
      for c in coords.dropFirst() {
        minLat = min(minLat, c.latitude)
        maxLat = max(maxLat, c.latitude)
        minLon = min(minLon, c.longitude)
        maxLon = max(maxLon, c.longitude)
      }
      let center = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      )
      let latDelta = max((maxLat - minLat) * 1.6, 0.003)
      let lonDelta = max((maxLon - minLon) * 1.6, 0.003)
      position = .region(
        MKCoordinateRegion(
          center: center,
          span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
      )
      return
    }
    if let coordinate = session.coordinate {
      position = .region(
        MKCoordinateRegion(
          center: coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
      )
    }
  }
}
