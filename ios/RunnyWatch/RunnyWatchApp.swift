import SwiftUI
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

final class WatchActivityModel: NSObject, ObservableObject, WCSessionDelegate {
  @Published var activityType: String = "—"
  @Published var elapsedSeconds: Int = 0
  @Published var distanceMeters: Double = 0
  @Published var isRecording: Bool = false
  @Published var phoneReachable: Bool = false

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

  func requestStart(type: String = "Koşu") {
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
    ScrollView {
      VStack(spacing: 10) {
        Text("Runny")
          .font(.headline)
          .foregroundStyle(Color.green)

        Text(session.isRecording ? session.activityType : "Hazır")
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(session.formattedElapsed)
          .font(.system(.title2, design: .rounded).monospacedDigit())
          .fontWeight(.bold)

        Text(session.formattedDistance)
          .font(.caption)
          .foregroundStyle(.secondary)

        if session.isRecording {
          Button("Bitir") {
            session.requestStop()
          }
          .tint(.red)
        } else {
          Button("Koşu başlat") {
            session.requestStart(type: "Koşu")
          }
          .tint(.green)
        }

        Text(session.phoneReachable ? "Telefon bağlı" : "Telefon uzak")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 8)
    }
  }
}
