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
}

@MainActor
final class WatchActivityModel: NSObject, ObservableObject, WCSessionDelegate {
  @Published var activityType: String = "—"
  @Published var elapsedSeconds: Int = 0
  @Published var distanceMeters: Double = 0
  @Published var isRecording: Bool = false
  @Published var phoneReachable: Bool = false
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
    activityType = type
    elapsedSeconds = 0
    distanceMeters = 0
    routeCoordinates = []
    send(["type": "start", "action": "start", "activityType": type])
    Task { await health.start(activityLabel: type) }
    startHealthTick()
    announceRecordingStarted(remote: false)
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
      isRecording = false
      stopHealthTick()
      pushHealthToPhone()
      await health.stop()
      send(["type": "stop", "action": "stop"])
      routeCoordinates = []
    }
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

  private func pushHealthToPhone() {
    guard isRecording else { return }
    var payload: [String: Any] = [
      "type": "health",
      "action": "health",
      "elevationGainMeters": health.elevationGainMeters,
      "activeEnergyKcal": health.activeEnergyKcal,
      "watchDistanceMeters": health.distanceMeters,
      "isRecording": true,
      "activityType": activityType,
      "elapsedSeconds": elapsedSeconds,
      "distanceMeters": displayDistanceMeters,
      "source": "watch",
    ]
    if let bpm = health.heartRateBpm { payload["heartRateBpm"] = bpm }
    if let avg = health.averageHeartRateBpm { payload["averageHeartRateBpm"] = avg }
    if let max = health.maxHeartRateBpm { payload["maxHeartRateBpm"] = max }
    if let alt = health.altitudeMeters { payload["altitudeMeters"] = alt }
    if let latitude { payload["latitude"] = latitude }
    if let longitude { payload["longitude"] = longitude }
    send(payload)
  }

  private func send(_ payload: [String: Any]) {
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    if session.isReachable {
      session.sendMessage(payload, replyHandler: nil) { error in
        NSLog("Watch→Phone error: \(error.localizedDescription)")
      }
    } else {
      session.transferUserInfo(payload)
    }
  }

  private func apply(_ context: [String: Any]) {
    Task { @MainActor in
      let action = (context["action"] as? String) ?? (context["type"] as? String) ?? ""

      // Telefondan gelen start/stop kesin sınır — yanlışlıkla kapanmayı engelle.
      if action == "start" {
        if let type = context["activityType"] as? String, !type.isEmpty {
          self.activityType = type
        }
        let wasRecording = self.isRecording
        self.isRecording = true
        if !wasRecording {
          self.cancelCountdown()
          self.routeCoordinates = []
          self.ensureHealthRunning()
          self.announceRecordingStarted(remote: true)
        } else {
          self.ensureHealthRunning()
        }
      } else if action == "stop" {
        let wasRecording = self.isRecording
        self.isRecording = false
        if wasRecording {
          self.stopHealthTick()
          await self.health.stop()
          self.routeCoordinates = []
        }
      }

      if let type = context["activityType"] as? String, !type.isEmpty {
        self.activityType = type
      }
      if let elapsed = context["elapsedSeconds"] as? Int {
        self.elapsedSeconds = elapsed
      } else if let elapsed = context["elapsedSeconds"] as? Double {
        self.elapsedSeconds = Int(elapsed)
      }
      if let distance = context["distanceMeters"] as? Double {
        self.distanceMeters = distance
      }
      // health / update: yalnızca isRecording true iken workout'u ayakta tut;
      // false gelince stop olmadan workout'u KESME (yanlış kapanmayı önler).
      if action != "start", action != "stop", let recording = context["isRecording"] as? Bool {
        if recording {
          let wasRecording = self.isRecording
          self.isRecording = true
          if !wasRecording {
            self.cancelCountdown()
            self.routeCoordinates = []
            self.ensureHealthRunning()
            self.announceRecordingStarted(remote: true)
          } else {
            self.ensureHealthRunning()
          }
        } else if self.isRecording {
          // idle / isRecording=false → workout'u durdurma; telefon stop göndermeli.
          self.ensureHealthRunning()
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
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      self.phoneReachable = session.isReachable
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
          Text("Aktivite")
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
