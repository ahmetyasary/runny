import Flutter
import UIKit
import WatchConnectivity
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let watchChannelName = "com.runny/watch"
  private var watchChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    RunnyLiveSessionManager.shared.requestNotificationPermission()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: watchChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    watchChannel = channel
    WatchConnectivityManager.shared.attach(channel: channel)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getStatus":
        result(WatchConnectivityManager.shared.statusDictionary())
      case "sendSessionUpdate":
        let args = call.arguments as? [String: Any] ?? [:]
        WatchConnectivityManager.shared.sendSessionUpdate(args)
        Self.handleSessionSideEffects(args)
        result(nil)
      case "launchWatchWorkout":
        let args = call.arguments as? [String: Any] ?? [:]
        let type = args["activityType"] as? String ?? "Koşu"
        RunnyLiveSessionManager.shared.launchWatchApp(activityType: type)
        result(nil)
      case "startLiveActivity":
        let args = call.arguments as? [String: Any] ?? [:]
        Self.startLive(from: args)
        result(nil)
      case "updateLiveActivity":
        let args = call.arguments as? [String: Any] ?? [:]
        Self.updateLive(from: args)
        result(nil)
      case "endLiveActivity":
        let args = call.arguments as? [String: Any] ?? [:]
        Self.endLive(from: args)
        result(nil)
      case "syncRecentActivities":
        let args = call.arguments as? [String: Any] ?? [:]
        WatchConnectivityManager.shared.syncRecentActivities(args)
        result(nil)
      case "notifyLocal":
        let args = call.arguments as? [String: Any] ?? [:]
        let title = args["title"] as? String ?? "Runny"
        let body = args["body"] as? String ?? ""
        RunnyLiveSessionManager.shared.notifyLocal(title: title, body: body)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func handleSessionSideEffects(_ args: [String: Any]) {
    let action = args["action"] as? String ?? ""
    let isRecording = args["isRecording"] as? Bool ?? false
    let type = args["activityType"] as? String ?? "Aktivite"

    switch action {
    case "start":
      // Kayıt başı: Watch workout + Live Activity birlikte ayağa kalkar.
      RunnyLiveSessionManager.shared.launchWatchApp(activityType: type)
      startLive(from: args)
    case "update", "sync", "health":
      // Kayıt sürerken yalnızca güncelle / düşmüşse yeniden başlat.
      // idle/stop dışı aksiyonlarda Live Activity'yi ASLA kapatma.
      if isRecording {
        updateLive(from: args)
      }
    case "stop":
      // Bitince yalnızca biz kapatırız.
      endLive(from: args)
    default:
      break
    }
  }

  private static func startLive(from args: [String: Any]) {
    let type = args["activityType"] as? String ?? "Aktivite"
    let elapsed = (args["elapsedSeconds"] as? NSNumber)?.intValue ?? 0
    let distance = (args["distanceMeters"] as? NSNumber)?.doubleValue ?? 0
    let hr = (args["heartRateBpm"] as? NSNumber)?.doubleValue
    let elev = (args["elevationGainMeters"] as? NSNumber)?.doubleValue ?? 0
    Task { @MainActor in
      RunnyLiveSessionManager.shared.startLiveActivity(
        activityType: type,
        elapsedSeconds: elapsed,
        distanceMeters: distance,
        heartRateBpm: hr,
        elevationGainMeters: elev
      )
    }
  }

  private static func updateLive(from args: [String: Any]) {
    let type = args["activityType"] as? String
    let elapsed = (args["elapsedSeconds"] as? NSNumber)?.intValue ?? 0
    let distance = (args["distanceMeters"] as? NSNumber)?.doubleValue ?? 0
    let hr = (args["heartRateBpm"] as? NSNumber)?.doubleValue
    let elev = (args["elevationGainMeters"] as? NSNumber)?.doubleValue ?? 0
    let isRecording = args["isRecording"] as? Bool ?? true
    Task { @MainActor in
      RunnyLiveSessionManager.shared.updateLiveActivity(
        elapsedSeconds: elapsed,
        distanceMeters: distance,
        heartRateBpm: hr,
        elevationGainMeters: elev,
        isRecording: isRecording,
        activityType: type
      )
    }
  }

  private static func endLive(from args: [String: Any]) {
    let elapsed = (args["elapsedSeconds"] as? NSNumber)?.intValue
    let distance = (args["distanceMeters"] as? NSNumber)?.doubleValue
    let hr = (args["heartRateBpm"] as? NSNumber)?.doubleValue
    let elev = (args["elevationGainMeters"] as? NSNumber)?.doubleValue
    Task { @MainActor in
      RunnyLiveSessionManager.shared.endLiveActivity(
        elapsedSeconds: elapsed,
        distanceMeters: distance,
        heartRateBpm: hr,
        elevationGainMeters: elev
      )
    }
  }
}

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
  static let shared = WatchConnectivityManager()

  private var channel: FlutterMethodChannel?
  private var session: WCSession?

  func attach(channel: FlutterMethodChannel) {
    self.channel = channel
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
    self.session = session
  }

  func statusDictionary() -> [String: Any] {
    guard WCSession.isSupported(), let session else {
      return [
        "supported": false,
        "paired": false,
        "reachable": false,
        "appInstalled": false,
      ]
    }
    return [
      "supported": true,
      "paired": session.isPaired,
      "reachable": session.isReachable,
      "appInstalled": session.isWatchAppInstalled,
    ]
  }

  func sendSessionUpdate(_ payload: [String: Any]) {
    guard let session, session.activationState == .activated else { return }

    let action = (payload["action"] as? String) ?? ""
    let isStop = action == "stop"
    try? session.updateApplicationContext(payload)

    if session.isReachable {
      session.sendMessage(payload, replyHandler: nil) { error in
        NSLog("Runny Watch sendMessage error: \(error.localizedDescription)")
        session.transferUserInfo(payload)
      }
      // Stop kritik: reachable olsa bile kuyruğa da yaz.
      if isStop {
        session.transferUserInfo(payload)
      }
    } else {
      session.transferUserInfo(payload)
    }
  }

  func syncRecentActivities(_ payload: [String: Any]) {
    guard let session, session.activationState == .activated else { return }

    var envelope = payload
    envelope["type"] = "recentActivities"
    envelope["action"] = "recentActivities"

    // applicationContext oturum paketini ezmesin; mesaj + userInfo kullan.
    if session.isReachable {
      session.sendMessage(envelope, replyHandler: nil) { error in
        NSLog("Runny recentActivities send error: \(error.localizedDescription)")
        session.transferUserInfo(envelope)
      }
    } else {
      session.transferUserInfo(envelope)
    }
  }

  private func emitStatusChanged() {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod(
        "watchStatusChanged",
        arguments: self?.statusDictionary()
      )
    }
  }

  private func forwardWatchEvent(_ message: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      var payload = message
      if payload["type"] == nil, let action = message["action"] as? String {
        payload["type"] = action
      }
      self?.channel?.invokeMethod("watchEvent", arguments: payload)
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    emitStatusChanged()
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    emitStatusChanged()
  }

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
    emitStatusChanged()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    emitStatusChanged()
  }

  func sessionWatchStateDidChange(_ session: WCSession) {
    emitStatusChanged()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    forwardWatchEvent(message)
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    forwardWatchEvent(message)
    replyHandler(["ok": true])
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    forwardWatchEvent(applicationContext)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    forwardWatchEvent(userInfo)
  }
}
