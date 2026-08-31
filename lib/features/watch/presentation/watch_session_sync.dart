import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../activities/presentation/activity_session_controller.dart';
import '../data/watch_bridge.dart';

/// Aktivite oturumunu Apple Watch + Live Activity ile senkron tutar.
///
/// Asıl kaynak kuralı: aktivite nereden başladıysa o cihaz süre/mesafe için
/// otoritedir. Diğeri takipçi olarak metrik alır / gösterir.
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
      _startRecordingKeepAlives();
      if (session.isPhonePrimary) {
        unawaited(_push(action: 'start'));
        unawaited(
          WatchBridge.launchWatchWorkout(session.activityType ?? 'Koşu'),
        );
      } else {
        // Saat asıl — telefonda mirror; saati yeniden başlatma.
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
      if (!session.isRecording) return;
      // Watch asılken Live Activity için update; saat süresini ezmemek için owner gider.
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
    if (!session.isRecording) return;
    // Saat asılken telefonda workout'u zorla yeniden başlatma.
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

  Future<void> _adoptFromWatch(
    Map<String, dynamic> payload, {
    bool announce = false,
  }) async {
    // Telefon asılken saatten gelen start/sync kayıt çalmasın; sadece health uygula.
    if (session.isPhonePrimary && session.isRecording) {
      session.applyWatchHealth(payload);
      session.setWatchReachable(true);
      await _push(action: 'update');
      return;
    }

    final type = payload['activityType'] as String? ?? 'Koşu';
    final startedNow = await session.adoptWatchSnapshot(payload);
    session.setWatchReachable(true);
    if (startedNow) {
      session.minimize();
      if (announce) {
        await WatchBridge.notifyLocal(
          title: 'Runny',
          body: '$type saatten başladı — saat asıl kaynak.',
        );
      }
    }
    if (session.isRecording) {
      await _push(action: 'update');
    }
  }

  Future<void> _onWatchEvent(WatchEvent event) async {
    switch (event.type) {
      case WatchEventType.startRequested:
        if (session.isPhonePrimary && session.isRecording) {
          // Telefon zaten asıl — saatin start'ı yok say / health al.
          session.applyWatchHealth(event.payload);
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
            await session.adoptWatchSnapshot({
              ...event.payload,
              'isRecording': true,
            });
            session.minimize();
            await _push(action: 'update');
            await WatchBridge.notifyLocal(
              title: 'Runny',
              body: '$type saatten başladı — saat asıl kaynak.',
            );
          }
        } else {
          await _adoptFromWatch(event.payload);
        }
      case WatchEventType.sync:
        await _adoptFromWatch(
          event.payload,
          announce: !session.isRecording,
        );
      case WatchEventType.healthUpdate:
        await _adoptFromWatch(event.payload);
      case WatchEventType.stopRequested:
        // Stop her iki taraftan da geçerli.
        if (session.isRecording || session.hasActiveSession) {
          session.applyWatchHealth(event.payload);
          final watchElapsed = event.payload['elapsedSeconds'];
          if (watchElapsed is num && session.isWatchPrimary) {
            session.setElapsedFromWatchPrimary(watchElapsed.round());
          } else if (watchElapsed is num) {
            session.catchUpElapsedFromWatch(watchElapsed.round());
          }
          await session.stop(save: true);
          await notifyStopped();
          await WatchBridge.notifyLocal(
            title: 'Runny',
            body: 'Aktivite saatten bitirildi.',
          );
        }
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
}
