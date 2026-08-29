import SwiftUI
import MapKit
import WatchConnectivity

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

final class WatchActivityModel: NSObject, ObservableObject, WCSessionDelegate {
  @Published var activityType: String = "—"
  @Published var elapsedSeconds: Int = 0
  @Published var distanceMeters: Double = 0
  @Published var isRecording: Bool = false
  @Published var phoneReachable: Bool = false
  @Published var latitude: Double?
  @Published var longitude: Double?

  override init() {
    super.init()
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
  }

  var formattedElapsed: String {
    let h = elapsedSeconds / 3600
    let m = (elapsedSeconds % 3600) / 60
    let s = elapsedSeconds % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
  }

  var formattedDistance: String {
    String(format: "%.2f km", distanceMeters / 1000.0)
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

  func requestStart(type: String) {
    isRecording = true
    activityType = type
    elapsedSeconds = 0
    distanceMeters = 0
    send(["type": "start", "action": "start", "activityType": type])
  }

  func requestStop() {
    send(["type": "stop", "action": "stop"])
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
    DispatchQueue.main.async {
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
      if let recording = context["isRecording"] as? Bool {
        self.isRecording = recording
      }
      if let lat = context["latitude"] as? Double {
        self.latitude = lat
      } else if let lat = context["latitude"] as? NSNumber {
        self.latitude = lat.doubleValue
      }
      if let lon = context["longitude"] as? Double {
        self.longitude = lon
      } else if let lon = context["longitude"] as? NSNumber {
        self.longitude = lon.doubleValue
      }
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      self.phoneReachable = session.isReachable
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async {
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
              session.requestStart(type: sport.label)
            } label: {
              Label {
                Text(sport.label)
              } icon: {
                Image(systemName: sport.symbol)
                  .foregroundStyle(sport.tint)
              }
            }
          }
        } header: {
          Text("Aktivite başlat")
        } footer: {
          Text(session.phoneReachable ? "Telefon bağlı" : "Telefon uzak — yine de dene")
        }
      }
      .navigationTitle("Runny")
    }
  }
}

struct RecordingPagerView: View {
  var body: some View {
    TabView {
      RecordingMetricsView()
      RecordingLocationView()
    }
    .tabViewStyle(.page)
  }
}

struct RecordingMetricsView: View {
  @EnvironmentObject private var session: WatchActivityModel

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        if let sport = session.activeSport {
          Image(systemName: sport.symbol)
            .font(.title2)
            .foregroundStyle(sport.tint)
        }

        Text(session.activityType)
          .font(.headline)

        Text(session.formattedElapsed)
          .font(.system(.title2, design: .rounded).monospacedDigit())
          .fontWeight(.bold)

        Text(session.formattedDistance)
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Bitir") {
          session.requestStop()
        }
        .tint(.red)

        Text("Konum için sağa kaydır →")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Text(session.phoneReachable ? "Telefon bağlı" : "Telefon uzak")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 8)
    }
  }
}

struct RecordingLocationView: View {
  @EnvironmentObject private var session: WatchActivityModel
  @State private var position: MapCameraPosition = .automatic

  var body: some View {
    VStack(spacing: 6) {
      Text("Konum")
        .font(.headline)

      if let coordinate = session.coordinate {
        Map(position: $position) {
          Marker("Şu an", coordinate: coordinate)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { moveCamera(to: coordinate) }
        .onChange(of: session.latitude) { _, _ in
          if let next = session.coordinate { moveCamera(to: next) }
        }
        .onChange(of: session.longitude) { _, _ in
          if let next = session.coordinate { moveCamera(to: next) }
        }

        Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      } else {
        Spacer(minLength: 8)
        Image(systemName: "location.slash")
          .font(.title2)
          .foregroundStyle(.secondary)
        Text("Konum bekleniyor…")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Telefon GPS’i aktarılınca burada görünür.")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Spacer(minLength: 8)
      }
    }
    .padding(.horizontal, 6)
  }

  private func moveCamera(to coordinate: CLLocationCoordinate2D) {
    position = .region(
      MKCoordinateRegion(
        center: coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
      )
    )
  }
}
