import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../activities/presentation/activity_session_controller.dart';
import '../data/watch_bridge.dart';

/// Aktivite oturumunu Apple Watch + Live Activity ile senkron tutar.
///
/// Kayıt boyunca:
/// - Live Activity / Watch metrikleri ~1 sn'de bir güncellenir
/// - Watch uzaksa periyodik `startWatchApp` ile workout yeniden uyandırılır
/// - Live Activity yalnızca `stop` ile kapanır (iOS tarafı)
class WatchSessionSync {
  WatchSessionSync(this.session);

  final ActivitySessionController session;
  StreamSubscription<WatchEvent>? _watchSub;
  Timer? _statusTimer;
  Timer? _heartbeatTimer;
  Timer? _watchKeepAliveTimer;
  bool _started = false;
  bool _wasRecording = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WatchBridge.ensureListening();
    session.addListener(_onSessionChanged);
    _watchSub = WatchBridge.events.listen(_onWatchEvent);
    await _refreshWatchStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshWatchStatus()),
    );
    // Uygulama açılışında kayıt yoksa Live Activity'ye dokunma.
    if (session.isRecording) {
      _wasRecording = true;
      _startRecordingKeepAlives();
      await _push(action: 'start');
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
    session.setWatchReachable(status.isConnected);
  }

  void _onSessionChanged() {
    final recording = session.isRecording;
    if (recording && !_wasRecording) {
      _wasRecording = true;
      _startRecordingKeepAlives();
      // Controller zaten start gönderir; yine de emin ol.
      unawaited(_push(action: 'start'));
      unawaited(
        WatchBridge.launchWatchWorkout(session.activityType ?? 'Koşu'),
      );
    } else if (!recording && _wasRecording) {
      _wasRecording = false;
      _stopRecordingKeepAlives();
      // Controller stop gönderir; ekstra idle ile LA kapatma.
    }
    // Kayıt sırasında metrikler heartbeat (1 sn) ile gider.
  }

  void _startRecordingKeepAlives() {
    _heartbeatTimer?.cancel();
    // Live Activity stale olmasın diye düzenli update.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!session.isRecording) return;
      unawaited(_push(action: 'update'));
    });

    _watchKeepAliveTimer?.cancel();
    // Watch workout düştüyse / saat uzağa düştüyse yeniden uyandır.
    _watchKeepAliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_ensureWatchWorkoutAlive());
    });
  }

  void _stopRecordingKeepAlives() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _watchKeepAliveTimer?.cancel();
    _watchKeepAliveTimer = null;
  }

  Future<void> _ensureWatchWorkoutAlive() async {
    if (!session.isRecording) return;
    final status = await WatchBridge.getStatus();
    session.setWatchReachable(status.isConnected);
    if (!status.isConnected) {
      await WatchBridge.launchWatchWorkout(session.activityType ?? 'Koşu');
      // Bağlantı gelince start payload tekrar gitsin.
      await _push(action: 'start');
    }
  }

  Future<void> notifyStarted() => _push(action: 'start');

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
      latitude: last?.latitude,
      longitude: last?.longitude,
      heartRateBpm: session.heartRateBpm,
      elevationGainMeters: session.elevationGainMeters,
    );
  }

  Future<void> _onWatchEvent(WatchEvent event) async {
    switch (event.type) {
      case WatchEventType.startRequested:
        final type = event.payload['activityType'] as String? ?? 'Koşu';
        if (!session.isRecording) {
          final ok = await session.start(type);
          debugPrint('Watch start → phone: $ok');
          if (ok) {
            session.minimize();
            await notifyStarted();
            await WatchBridge.notifyLocal(
              title: 'Runny',
              body: '$type saatten başladı — canlı kayıt açık.',
            );
          }
        }
      case WatchEventType.stopRequested:
        if (session.isRecording || session.hasActiveSession) {
          await session.stop(save: true);
          await notifyStopped();
          await WatchBridge.notifyLocal(
            title: 'Runny',
            body: 'Aktivite saatten bitirildi.',
          );
        }
      case WatchEventType.healthUpdate:
        session.applyWatchHealth(event.payload);
        session.setWatchReachable(true);
        // Live Activity metriklerini hemen tazele.
        if (session.isRecording) {
          await _push(action: 'update');
        }
      case WatchEventType.statusChanged:
        await _refreshWatchStatus();
        if (session.isRecording && !session.watchReachable) {
          unawaited(_ensureWatchWorkoutAlive());
        }
      case WatchEventType.pauseRequested:
      case WatchEventType.resumeRequested:
      case WatchEventType.unknown:
        break;
    }
  }
}
