import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../activities/presentation/activity_session_controller.dart';
import '../data/watch_bridge.dart';

/// Aktivite oturumunu Apple Watch ile senkron tutar.
class WatchSessionSync {
  WatchSessionSync(this.session);

  final ActivitySessionController session;
  StreamSubscription<WatchEvent>? _watchSub;
  Timer? _pushTimer;
  Timer? _statusTimer;
  bool _started = false;

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
    await _push(action: 'sync');
  }

  void dispose() {
    session.removeListener(_onSessionChanged);
    _watchSub?.cancel();
    _pushTimer?.cancel();
    _statusTimer?.cancel();
  }

  Future<void> _refreshWatchStatus() async {
    final status = await WatchBridge.getStatus();
    session.setWatchReachable(status.isConnected);
  }

  void _onSessionChanged() {
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(
        _push(action: session.isRecording ? 'update' : 'idle'),
      );
    });
  }

  Future<void> notifyStarted() => _push(action: 'start');

  Future<void> notifyStopped() => _push(action: 'stop');

  Future<void> _push({required String action}) async {
    final type = session.activityType ?? '';
    final last = session.points.isEmpty ? null : session.points.last;
    await WatchBridge.sendSessionUpdate(
      action: action,
      activityType: type,
      elapsedSeconds: session.elapsed.inSeconds,
      distanceMeters: session.effectiveDistanceMeters,
      isRecording: session.isRecording,
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
        // Live Activity metriklerini güncelle.
        await _push(action: 'update');
      case WatchEventType.statusChanged:
        await _refreshWatchStatus();
      case WatchEventType.pauseRequested:
      case WatchEventType.resumeRequested:
      case WatchEventType.unknown:
        break;
    }
  }
}
