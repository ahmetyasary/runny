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
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WatchBridge.ensureListening();
    session.addListener(_onSessionChanged);
    _watchSub = WatchBridge.events.listen(_onWatchEvent);
    await _push(action: 'sync');
  }

  void dispose() {
    session.removeListener(_onSessionChanged);
    _watchSub?.cancel();
    _pushTimer?.cancel();
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
    await WatchBridge.sendSessionUpdate(
      action: action,
      activityType: type,
      elapsedSeconds: session.elapsed.inSeconds,
      distanceMeters: session.distanceMeters,
      isRecording: session.isRecording,
    );
  }

  Future<void> _onWatchEvent(WatchEvent event) async {
    switch (event.type) {
      case WatchEventType.startRequested:
        final type = event.payload['activityType'] as String? ?? 'Koşu';
        if (!session.isRecording) {
          final ok = await session.start(type);
          debugPrint('Watch start → phone: $ok');
          if (ok) await notifyStarted();
        }
      case WatchEventType.stopRequested:
        if (session.isRecording || session.hasActiveSession) {
          await session.stop(save: true);
          await notifyStopped();
        }
      case WatchEventType.pauseRequested:
      case WatchEventType.resumeRequested:
      case WatchEventType.statusChanged:
      case WatchEventType.unknown:
        break;
    }
  }
}
