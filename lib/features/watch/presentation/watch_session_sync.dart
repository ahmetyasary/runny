import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../activities/presentation/activity_session_controller.dart';
import '../data/watch_bridge.dart';

/// Aktivite oturumunu Apple Watch + Live Activity ile senkron tutar.
///
/// Asıl kaynak: aktiviteyi başlatan cihaz.
/// Stop her iki taraftan da kesin; health asla yeni kayıt başlatmaz.
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
      await _push(action: session.isWatchPrimary ? 'update' : 'start');
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

    if (becameReachable && session.isRecording && session.isPhonePrimary) {
      await _push(action: 'update');
    }
  }

  void _onSessionChanged() {
    final recording = session.isRecording;
    if (recording && !_wasRecording) {
      _wasRecording = true;
      _stopping = false;
      _startRecordingKeepAlives();
      if (session.isPhonePrimary) {
        unawaited(_push(action: 'start'));
        unawaited(
          WatchBridge.launchWatchWorkout(session.activityType ?? 'Koşu'),
        );
      } else {
        unawaited(_push(action: 'update'));
      }
    } else if (!recording && _wasRecording) {
      _wasRecording = false;
      _stopRecordingKeepAlives();
    }
  }

  void _startRecordingKeepAlives() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!session.isRecording || _stopping) return;
      unawaited(_push(action: 'update'));
    });

    _watchKeepAliveTimer?.cancel();
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
    if (!session.isRecording || _stopping) return;
    if (session.isWatchPrimary) return;
    final status = await WatchBridge.getStatus();
    session.setWatchReachable(status.isConnected);
    if (!status.isConnected) {
      await WatchBridge.launchWatchWorkout(session.activityType ?? 'Koşu');
      await _push(action: 'update');
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
    if (watchElapsed is num && session.isWatchPrimary) {
      session.setElapsedFromWatchPrimary(watchElapsed.round());
    }
  }

  Future<void> _onWatchEvent(WatchEvent event) async {
    switch (event.type) {
      case WatchEventType.startRequested:
        if (_stopping || session.isIgnoringWatchStart) break;
        if (session.isPhonePrimary && session.isRecording) {
          await _applyWatchMetrics(event.payload);
          break;
        }
        final type = event.payload['activityType'] as String? ?? 'Koşu';
        if (!session.isRecording) {
          final ok = await session.start(
            type,
            origin: ActivitySessionOrigin.watch,
            announceToWatch: false,
          );
          debugPrint('Watch start → phone (watch primary): $ok type=$type');
          if (ok) {
            await session.adoptWatchSnapshot(
              {...event.payload, 'isRecording': true},
              allowStart: false,
            );
            session.minimize();
            await _push(action: 'update');
            await WatchBridge.notifyLocal(
              title: 'Runny',
              body: '$type saatten başladı.',
            );
          }
        } else if (session.isWatchPrimary) {
          await _applyWatchMetrics(event.payload);
        }

      case WatchEventType.sync:
        if (_stopping || session.isIgnoringWatchStart) break;
        final watchRecording = event.payload['isRecording'] as bool? ?? true;
        if (!watchRecording) break;
        if (session.isRecording) {
          await _applyWatchMetrics(event.payload);
        } else if (session.isPhonePrimary) {
          // Telefon asılken kapalıysa sync ile zorla açma.
          break;
        } else {
          // Reconnect: saat hâlâ kayıttaysa telefonda mirror aç.
          final startedNow = await session.adoptWatchSnapshot(
            event.payload,
            allowStart: true,
          );
          if (startedNow) {
            session.minimize();
            await WatchBridge.notifyLocal(
              title: 'Runny',
              body: 'Saat aktivitesi senkronize edildi.',
            );
          }
          if (session.isRecording) await _push(action: 'update');
        }

      case WatchEventType.healthUpdate:
        // Health asla yeni kayıt başlatmaz.
        if (_stopping || !session.isRecording) break;
        if (session.isPhonePrimary || session.isWatchPrimary) {
          await _applyWatchMetrics(event.payload);
        }

      case WatchEventType.stopRequested:
        await _handleRemoteStop(event.payload);

      case WatchEventType.statusChanged:
        await _refreshWatchStatus();
        if (session.isRecording &&
            session.isPhonePrimary &&
            !session.watchReachable) {
          unawaited(_ensureWatchWorkoutAlive());
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
      // Yine de saate stop teyidi gönder.
      await notifyStopped();
      return;
    }
    _stopping = true;
    _stopRecordingKeepAlives();
    try {
      session.applyWatchHealth(payload);
      final watchElapsed = payload['elapsedSeconds'];
      if (watchElapsed is num && session.isWatchPrimary) {
        session.setElapsedFromWatchPrimary(watchElapsed.round());
      } else if (watchElapsed is num) {
        session.catchUpElapsedFromWatch(watchElapsed.round());
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
