import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../activities/presentation/activity_session_controller.dart';
import '../data/watch_bridge.dart';

/// Telefon ↔ Apple Watch aktivite senkronu.
///
/// Bağlıyken:
/// - Kim başlatırsa başlatsın diğeri aynalar (bildirim + metrikler)
/// - Aktif kayıt varken saat workout'u ZORUNLU ayakta tutulur
/// - Stop her iki taraftan da kesin; health asla yeni kayıt açmaz
class WatchSessionSync {
  WatchSessionSync(this.session);

  final ActivitySessionController session;
  StreamSubscription<WatchEvent>? _watchSub;
  Timer? _statusTimer;
  Timer? _heartbeatTimer;
  Timer? _watchKeepAliveTimer;
  bool _started = false;
  bool _wasRecording = false;
  bool _wasWatchReachable = false;
  bool _stopping = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WatchBridge.ensureListening();
    session.addListener(_onSessionChanged);
    _watchSub = WatchBridge.events.listen(_onWatchEvent);
    await _refreshWatchStatus();
    _wasWatchReachable = session.watchReachable;
    _statusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshWatchStatus()),
    );
    if (session.isRecording) {
      _wasRecording = true;
      _startRecordingKeepAlives();
      await _forceWatchActive(reason: 'bootstrap');
    }
  }

  void dispose() {
    session.removeListener(_onSessionChanged);
    _watchSub?.cancel();
    _statusTimer?.cancel();
    _stopRecordingKeepAlives();
  }

  Future<void> _refreshWatchStatus() async {
    final status = await WatchBridge.getStatus();
    final connected = status.isConnected;
    final becameReachable = connected && !_wasWatchReachable;
    session.setWatchReachable(connected);
    _wasWatchReachable = connected;

    // Saat yeniden görünür olduysa aktif koşuyu zorla senkronla.
    if (becameReachable && session.isRecording && !_stopping) {
      await _forceWatchActive(reason: 'reachable');
    }
  }

  void _onSessionChanged() {
    final recording = session.isRecording;
    if (recording && !_wasRecording) {
      _wasRecording = true;
      _stopping = false;
      _startRecordingKeepAlives();
      unawaited(_forceWatchActive(reason: 'session-start'));
    } else if (!recording && _wasRecording) {
      _wasRecording = false;
      _stopRecordingKeepAlives();
    }
  }

  void _startRecordingKeepAlives() {
    _heartbeatTimer?.cancel();
    // Live Activity + saat metrik senkronu.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!session.isRecording || _stopping) return;
      unawaited(_push(action: 'update'));
    });

    _watchKeepAliveTimer?.cancel();
    // Aktif koşuda saat workout düşmesin — periyodik uyandır.
    _watchKeepAliveTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_forceWatchActive(reason: 'keepalive'));
    });
  }

  void _stopRecordingKeepAlives() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _watchKeepAliveTimer?.cancel();
    _watchKeepAliveTimer = null;
  }

  /// Aktif kayıt varken saati zorla kayıt UI + HK workout'a alır.
  Future<void> _forceWatchActive({required String reason}) async {
    if (!session.isRecording || _stopping) return;
    final type = session.activityType ?? 'Koşu';
    debugPrint('Watch force-active ($reason) type=$type');
    await WatchBridge.launchWatchWorkout(type);
    await _push(action: 'start');
  }

  Future<void> notifyStarted() => _forceWatchActive(reason: 'notify-started');

  Future<void> notifyStopped() => _push(action: 'stop');

  Future<void> _push({required String action}) async {
    final type = session.activityType ?? '';
    final last = session.points.isEmpty ? null : session.points.last;
    await WatchBridge.sendSessionUpdate(
      action: action,
      activityType: type.isEmpty ? 'Aktivite' : type,
      elapsedSeconds: session.elapsed.inSeconds,
      distanceMeters: session.effectiveDistanceMeters,
      isRecording: session.isRecording || action == 'start',
      sessionOwner: session.origin?.name,
      latitude: last?.latitude,
      longitude: last?.longitude,
      heartRateBpm: session.heartRateBpm,
      elevationGainMeters: session.elevationGainMeters,
    );
  }

  Future<void> _applyWatchMetrics(Map<String, dynamic> payload) async {
    if (!session.isRecording || _stopping) return;
    session.applyWatchHealth(payload);
    session.setWatchReachable(true);

    final watchElapsed = payload['elapsedSeconds'];
    if (watchElapsed is! num) return;

    // Bağlıyken süreleri birleştir: kim öndeyse onu al (geri alma).
    if (session.isWatchPrimary) {
      session.setElapsedFromWatchPrimary(watchElapsed.round());
    } else {
      session.catchUpElapsedFromWatch(watchElapsed.round());
    }
  }

  Future<void> _mirrorWatchStart(Map<String, dynamic> payload) async {
    if (_stopping || session.isIgnoringWatchStart) return;
    final type = payload['activityType'] as String? ?? 'Koşu';

    if (!session.isRecording) {
      final ok = await session.start(
        type,
        origin: ActivitySessionOrigin.watch,
        announceToWatch: false,
      );
      if (!ok) return;
      await session.adoptWatchSnapshot(
        {...payload, 'isRecording': true},
        allowStart: false,
      );
      session.minimize();
      await WatchBridge.notifyLocal(
        title: 'Runny',
        body: '$type saatten başladı — telefon senkron.',
      );
    } else {
      await _applyWatchMetrics(payload);
    }

    // Saat zaten kayıttaysa bile workout'u teyit et.
    await _forceWatchActive(reason: 'mirror-watch-start');
  }

  Future<void> _onWatchEvent(WatchEvent event) async {
    switch (event.type) {
      case WatchEventType.startRequested:
        await _mirrorWatchStart(event.payload);

      case WatchEventType.sync:
        if (_stopping || session.isIgnoringWatchStart) break;
        final watchRecording = event.payload['isRecording'] as bool? ?? true;
        if (!watchRecording) break;
        if (session.isRecording) {
          await _applyWatchMetrics(event.payload);
          // Sync geldiyse saat ayakta; yine de teyit.
          unawaited(_forceWatchActive(reason: 'sync'));
        } else {
          // Saat offline kayda devam etmiş → telefonda aç.
          await _mirrorWatchStart(event.payload);
        }

      case WatchEventType.healthUpdate:
        if (_stopping || !session.isRecording) break;
        await _applyWatchMetrics(event.payload);

      case WatchEventType.stopRequested:
        await _handleRemoteStop(event.payload);

      case WatchEventType.statusChanged:
        await _refreshWatchStatus();
        if (session.isRecording && !_stopping) {
          unawaited(_forceWatchActive(reason: 'status'));
        }

      case WatchEventType.pauseRequested:
      case WatchEventType.resumeRequested:
      case WatchEventType.unknown:
        break;
    }
  }

  Future<void> _handleRemoteStop(Map<String, dynamic> payload) async {
    if (_stopping) return;
    if (!session.isRecording && !session.hasActiveSession) {
      await notifyStopped();
      return;
    }
    _stopping = true;
    _stopRecordingKeepAlives();
    try {
      session.applyWatchHealth(payload);
      final watchElapsed = payload['elapsedSeconds'];
      if (watchElapsed is num) {
        if (session.isWatchPrimary) {
          session.setElapsedFromWatchPrimary(watchElapsed.round());
        } else {
          session.catchUpElapsedFromWatch(watchElapsed.round());
        }
      }
      await session.stop(save: true);
      await notifyStopped();
      await WatchBridge.notifyLocal(
        title: 'Runny',
        body: 'Aktivite bitirildi.',
      );
    } finally {
      _stopping = false;
    }
  }
}
