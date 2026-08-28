import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/supabase_config.dart';
import '../../watch/data/watch_bridge.dart';
import '../data/activity_repository.dart';

class ActivityStopResult {
  const ActivityStopResult({
    required this.message,
    required this.localId,
    required this.typeLabel,
    required this.title,
    required this.distanceMeters,
    required this.duration,
    this.cloudId,
  });

  final String message;
  final String localId;
  final String typeLabel;
  final String title;
  final double distanceMeters;
  final Duration duration;
  final String? cloudId;
}

class ActivitySessionController extends ChangeNotifier {
  String? activityType;
  final List<LatLng> points = [];
  Duration elapsed = Duration.zero;
  double distanceMeters = 0;
  bool isRecording = false;
  bool isMinimized = false;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;

  bool get hasActiveSession =>
      isRecording || (points.isNotEmpty && elapsed > Duration.zero);

  String get formattedElapsed {
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String get formattedDistance =>
      '${(distanceMeters / 1000).toStringAsFixed(2)} km';

  Future<bool> start(String type) async {
    if (!await _ensurePermission()) return false;

    try {
      final position = await Geolocator.getCurrentPosition();
      points
        ..clear()
        ..add(LatLng(position.latitude, position.longitude));
      distanceMeters = 0;
      elapsed = Duration.zero;
      activityType = type;
    } catch (_) {
      return false;
    }

    isRecording = true;
    isMinimized = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed += const Duration(seconds: 1);
      notifyListeners();
    });

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final point = LatLng(position.latitude, position.longitude);
      if (points.isNotEmpty) {
        distanceMeters += const Distance().as(
          LengthUnit.Meter,
          points.last,
          point,
        );
      }
      points.add(point);
      notifyListeners();
    });

    notifyListeners();
    await WatchBridge.sendSessionUpdate(
      action: 'start',
      activityType: type,
      elapsedSeconds: 0,
      distanceMeters: 0,
      isRecording: true,
    );
    return true;
  }

  void minimize() {
    if (!isRecording) return;
    isMinimized = true;
    notifyListeners();
  }

  void expand() {
    isMinimized = false;
    notifyListeners();
  }

  Future<ActivityStopResult> stop({bool save = true}) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _timer?.cancel();
    _timer = null;
    isRecording = false;

    final typeLabel = activityType ?? 'Aktivite';
    final title = '$typeLabel aktivitesi';
    final distance = distanceMeters;
    final duration = elapsed;
    final snapshotPoints = List<LatLng>.from(points);
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    var message = 'Aktivite kaydı tamamlandı.';
    String? cloudId;

    if (save) {
      final client = SupabaseService.client;
      if (client != null && client.auth.currentUser != null) {
        try {
          cloudId = await ActivityRepository(client).createActivity(
            type: typeLabel,
            title: title,
            points: snapshotPoints,
            distanceMeters: distance,
            duration: duration,
          );
          message = 'Aktivite kaydedildi.';
        } catch (_) {
          message = 'Aktivite cihazda kaydedildi, buluta aktarım başarısız.';
        }
      } else {
        message = 'Aktivite cihazda kaydedildi.';
      }
    }

    activityType = null;
    points.clear();
    distanceMeters = 0;
    elapsed = Duration.zero;
    isMinimized = false;
    notifyListeners();

    await WatchBridge.sendSessionUpdate(
      action: 'stop',
      activityType: typeLabel,
      elapsedSeconds: duration.inSeconds,
      distanceMeters: distance,
      isRecording: false,
    );

    return ActivityStopResult(
      message: message,
      localId: cloudId ?? localId,
      typeLabel: typeLabel,
      title: title,
      distanceMeters: distance,
      duration: duration,
      cloudId: cloudId,
    );
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
