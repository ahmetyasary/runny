import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apple Watch ile telefon arasındaki köprü.
///
/// Akış: Flutter ⇄ MethodChannel ⇄ iOS WCSession ⇄ watchOS uygulaması
class WatchBridge {
  WatchBridge._();

  static const channel = MethodChannel('com.runny/watch');

  static final _events = StreamController<WatchEvent>.broadcast();
  static bool _listening = false;

  static Stream<WatchEvent> get events => _events.stream;

  static void ensureListening() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'watchEvent':
          final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
          _events.add(WatchEvent.fromMap(args));
        case 'watchStatusChanged':
          final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
          _events.add(
            WatchEvent(
              type: WatchEventType.statusChanged,
              payload: args,
            ),
          );
      }
      return null;
    });
  }

  static Future<WatchStatus> getStatus() async {
    ensureListening();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const WatchStatus(
        supported: false,
        paired: false,
        reachable: false,
        appInstalled: false,
      );
    }
    try {
      final raw = await channel.invokeMethod<Map>('getStatus');
      if (raw == null) return const WatchStatus.unsupported();
      return WatchStatus.fromMap(Map<String, dynamic>.from(raw));
    } on PlatformException {
      return const WatchStatus.unsupported();
    } on MissingPluginException {
      return const WatchStatus.unsupported();
    }
  }

  static Future<void> sendSessionUpdate({
    required String action,
    required String activityType,
    required int elapsedSeconds,
    required double distanceMeters,
    bool isRecording = true,
    double? latitude,
    double? longitude,
  }) async {
    ensureListening();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await channel.invokeMethod('sendSessionUpdate', {
        'action': action,
        'activityType': activityType,
        'elapsedSeconds': elapsedSeconds,
        'distanceMeters': distanceMeters,
        'isRecording': isRecording,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'latitude': ?latitude,
        'longitude': ?longitude,
      });
    } on PlatformException catch (error) {
      debugPrint('WatchBridge send failed: ${error.message}');
    } on MissingPluginException {
      // Simulator / plugin yok.
    }
  }
}

enum WatchEventType {
  startRequested,
  stopRequested,
  pauseRequested,
  resumeRequested,
  statusChanged,
  unknown,
}

class WatchEvent {
  const WatchEvent({
    required this.type,
    this.payload = const {},
  });

  final WatchEventType type;
  final Map<String, dynamic> payload;

  factory WatchEvent.fromMap(Map<String, dynamic> map) {
    final name = map['type'] as String? ?? '';
    final type = switch (name) {
      'start' => WatchEventType.startRequested,
      'stop' => WatchEventType.stopRequested,
      'pause' => WatchEventType.pauseRequested,
      'resume' => WatchEventType.resumeRequested,
      'status' => WatchEventType.statusChanged,
      _ => WatchEventType.unknown,
    };
    return WatchEvent(type: type, payload: map);
  }
}

class WatchStatus {
  const WatchStatus({
    required this.supported,
    required this.paired,
    required this.reachable,
    required this.appInstalled,
  });

  const WatchStatus.unsupported()
      : supported = false,
        paired = false,
        reachable = false,
        appInstalled = false;

  final bool supported;
  final bool paired;
  final bool reachable;
  final bool appInstalled;

  bool get isConnected => supported && paired && reachable;

  String get label {
    if (!supported) return 'Bu cihazda saat desteği yok';
    if (!paired) return 'Apple Watch eşleşmemiş';
    if (!appInstalled) return 'Runny Watch uygulaması yüklü değil';
    if (!reachable) return 'Saat bağlı değil (uzak)';
    return 'Apple Watch bağlı';
  }

  factory WatchStatus.fromMap(Map<String, dynamic> map) {
    return WatchStatus(
      supported: map['supported'] as bool? ?? false,
      paired: map['paired'] as bool? ?? false,
      reachable: map['reachable'] as bool? ?? false,
      appInstalled: map['appInstalled'] as bool? ?? false,
    );
  }
}
