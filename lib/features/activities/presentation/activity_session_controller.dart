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
    this.calories = 0,
    this.elevationGainMeters = 0,
    this.avgHeartRateBpm,
    this.maxHeartRateBpm,
    this.routePoints = const [],
  });

  final String message;
  final String localId;
  final String typeLabel;
  final String title;
  final double distanceMeters;
  final Duration duration;
  final String? cloudId;
  final int calories;
  final double elevationGainMeters;
  final int? avgHeartRateBpm;
  final int? maxHeartRateBpm;
  final List<LatLng> routePoints;
}

class ActivitySessionController extends ChangeNotifier {
  String? activityType;
  final List<LatLng> points = [];
  Duration elapsed = Duration.zero;
  double distanceMeters = 0;
  bool isRecording = false;
  bool isMinimized = false;
  /// Apple Watch WCSession ulaşılabilir mi?
  bool watchReachable = false;

  /// Saat (HealthKit / altimetre) metrikleri.
  double? heartRateBpm;
  double? averageHeartRateBpm;
  double? maxHeartRateBpm;
  double elevationGainMeters = 0;
  double? altitudeMeters;
  double activeEnergyKcal = 0;
  double watchDistanceMeters = 0;
  DateTime? lastWatchHealthAt;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;

  bool get hasActiveSession =>
      isRecording || (points.isNotEmpty && elapsed > Duration.zero);

  bool get hasWatchHealth =>
      lastWatchHealthAt != null ||
      heartRateBpm != null ||
      activeEnergyKcal > 0 ||
      elevationGainMeters > 0 ||
      watchDistanceMeters > 0;

  /// Telefon GPS + saat mesafesinin büyüğü.
  double get effectiveDistanceMeters =>
      distanceMeters > watchDistanceMeters ? distanceMeters : watchDistanceMeters;

  String get formattedElapsed {
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String get formattedDistance =>
      '${(effectiveDistanceMeters / 1000).toStringAsFixed(2)} km';

  String get formattedHeartRate =>
      heartRateBpm == null ? '—' : '${heartRateBpm!.round()}';

  String get formattedAvgHeartRate =>
      averageHeartRateBpm == null ? '—' : '${averageHeartRateBpm!.round()}';

  String get formattedMaxHeartRate =>
      maxHeartRateBpm == null ? '—' : '${maxHeartRateBpm!.round()}';

  String get formattedElevation => '${elevationGainMeters.round()} m';

  String get formattedAltitude =>
      altitudeMeters == null ? '—' : '${altitudeMeters!.round()} m';

  String get formattedCalories =>
      activeEnergyKcal <= 0 ? '—' : '${activeEnergyKcal.round()}';

  String get formattedPace {
    final meters = effectiveDistanceMeters;
    if (meters < 20 || elapsed.inSeconds <= 0) return "--'--\"";
    final secPerKm = elapsed.inSeconds / (meters / 1000);
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  void setWatchReachable(bool value) {
    if (watchReachable == value) return;
    watchReachable = value;
    notifyListeners();
  }

  void applyWatchHealth(Map<String, dynamic> payload) {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final hr = asDouble(payload['heartRateBpm']);
    if (hr != null) heartRateBpm = hr;
    final avg = asDouble(payload['averageHeartRateBpm']);
    if (avg != null) averageHeartRateBpm = avg;
    final maxHr = asDouble(payload['maxHeartRateBpm']);
    if (maxHr != null) maxHeartRateBpm = maxHr;
    final elev = asDouble(payload['elevationGainMeters']);
    if (elev != null) elevationGainMeters = elev;
    final alt = asDouble(payload['altitudeMeters']);
    if (alt != null) altitudeMeters = alt;
    final kcal = asDouble(payload['activeEnergyKcal']);
    if (kcal != null) activeEnergyKcal = kcal;
    final watchDist = asDouble(payload['watchDistanceMeters']);
    if (watchDist != null) watchDistanceMeters = watchDist;
    lastWatchHealthAt = DateTime.now();
    notifyListeners();
  }

  void _resetHealth() {
    heartRateBpm = null;
    averageHeartRateBpm = null;
    maxHeartRateBpm = null;
    elevationGainMeters = 0;
    altitudeMeters = null;
    activeEnergyKcal = 0;
    watchDistanceMeters = 0;
    lastWatchHealthAt = null;
  }

  Future<bool> start(String type) async {
    if (!await _ensurePermission()) return false;

    try {
      final position = await Geolocator.getCurrentPosition();
      points
        ..clear()
        ..add(LatLng(position.latitude, position.longitude));
      distanceMeters = 0;
      elapsed = Duration.zero;
      _resetHealth();
      if (position.altitude.isFinite) {
        altitudeMeters = position.altitude;
      }
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
      if (position.altitude.isFinite) {
        altitudeMeters = position.altitude;
      }
      notifyListeners();
    });

    notifyListeners();
    final last = points.isEmpty ? null : points.last;
    await WatchBridge.sendSessionUpdate(
      action: 'start',
      activityType: type,
      elapsedSeconds: 0,
      distanceMeters: 0,
      isRecording: true,
      latitude: last?.latitude,
      longitude: last?.longitude,
    );
    await WatchBridge.launchWatchWorkout(type);
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
    final distance = effectiveDistanceMeters;
    final duration = elapsed;
    final snapshotPoints = List<LatLng>.from(points);
    final calories = activeEnergyKcal.round();
    final elevation = elevationGainMeters;
    final avgHr = averageHeartRateBpm?.round();
    final maxHr = maxHeartRateBpm?.round();
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
            calories: calories,
            elevationGainMeters: elevation,
            avgHeartRateBpm: avgHr,
            maxHeartRateBpm: maxHr,
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
    _resetHealth();
    isMinimized = false;
    notifyListeners();

    final last = snapshotPoints.isEmpty ? null : snapshotPoints.last;
    await WatchBridge.sendSessionUpdate(
      action: 'stop',
      activityType: typeLabel,
      elapsedSeconds: duration.inSeconds,
      distanceMeters: distance,
      isRecording: false,
      latitude: last?.latitude,
      longitude: last?.longitude,
    );

    return ActivityStopResult(
      message: message,
      localId: cloudId ?? localId,
      typeLabel: typeLabel,
      title: title,
      distanceMeters: distance,
      duration: duration,
      cloudId: cloudId,
      calories: calories,
      elevationGainMeters: elevation,
      avgHeartRateBpm: avgHr,
      maxHeartRateBpm: maxHr,
      routePoints: snapshotPoints,
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
