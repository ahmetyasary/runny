import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let watchChannelName = "com.runny/watch"
  private var watchChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
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

    // Application context: arka planda da güncellenir.
    try? session.updateApplicationContext(payload)

    if session.isReachable {
      session.sendMessage(payload, replyHandler: nil) { error in
        NSLog("Runny Watch sendMessage error: \(error.localizedDescription)")
      }
    } else {
      session.transferUserInfo(payload)
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

  // MARK: - WCSessionDelegate

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
