import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/models/activity_mapping.dart';
import '../data/activity_repository.dart';

class ActivityHistoryController extends ChangeNotifier {
  List<Activity> activities = [];
  double totalKm = 0;
  int count = 0;
  String avgPace = '--:--';
  bool loading = false;
  String? error;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      // Demo / giriş yok: mevcut lokal liste kalsın.
      loading = false;
      _recomputeStats();
      notifyListeners();
      return;
    }

    try {
      final repo = ActivityRepository(client);
      final remote = await repo.fetchMine();
      final stats = await repo.fetchMyStats();

      // Uzak veri gelince lokal önbelleği onunla değiştir.
      activities = remote;
      totalKm = stats.totalKm;
      count = stats.count;
      avgPace = stats.avgPace;
      loading = false;
      notifyListeners();
    } catch (e) {
      error = 'Aktiviteler yüklenemedi.';
      loading = false;
      _recomputeStats();
      notifyListeners();
    }
  }

  void addCompleted({
    required String id,
    required String typeLabel,
    required String title,
    required double distanceMeters,
    required Duration duration,
    String location = 'Konum yok',
    int calories = 0,
    double elevationGainMeters = 0,
    int? avgHeartRate,
    int? maxHeartRate,
    List<LatLng> routePoints = const [],
  }) {
    final user = SupabaseService.client?.auth.currentUser;
    final activity = Activity(
      id: id,
      userId: user?.id,
      userName: user?.email?.split('@').first ?? 'Sen',
      userHandle: '@sen',
      type: _typeFromLabel(typeLabel),
      title: title,
      location: location,
      distance: distanceMeters / 1000,
      duration: ActivityMapping.formatDuration(duration.inSeconds),
      when: 'Az önce',
      likes: 0,
      comments: 0,
      calories: calories,
      elevationGainMeters: elevationGainMeters,
      avgHeartRate: avgHeartRate,
      maxHeartRate: maxHeartRate,
      routePoints: routePoints,
      durationSeconds: duration.inSeconds,
      startedAt: DateTime.now().subtract(duration),
    );

    activities = [activity, ...activities.where((item) => item.id != id)];
    _recomputeStats();
    notifyListeners();
  }

  void _recomputeStats() {
    count = activities.length;
    totalKm = activities.fold<double>(0, (sum, item) => sum + item.distance);
    if (totalKm <= 0 || activities.isEmpty) {
      avgPace = '--:--';
      return;
    }

    var totalSeconds = 0;
    for (final activity in activities) {
      totalSeconds += _parseDuration(activity.duration);
    }
    if (totalSeconds <= 0) {
      avgPace = '--:--';
      return;
    }
    final paceSeconds = (totalSeconds / totalKm).round();
    final minutes = paceSeconds ~/ 60;
    final secs = paceSeconds % 60;
    avgPace = '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  ActivityType _typeFromLabel(String label) => switch (label) {
        'Yürüyüş' => ActivityType.walk,
        'Bisiklet' => ActivityType.bike,
        'Yüzme' => ActivityType.swim,
        'Hiking' => ActivityType.hike,
        'Trail' => ActivityType.trail,
        'Fitness' => ActivityType.gym,
        'Yoga' => ActivityType.yoga,
        _ => ActivityType.run,
      };

  int _parseDuration(String value) {
    final parts = value.split(':').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return 0;
    if (parts.length == 3) {
      return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    }
    if (parts.length == 2) {
      return parts[0]! * 60 + parts[1]!;
    }
    return 0;
  }
}

class ActivityHistoryScope extends InheritedNotifier<ActivityHistoryController> {
  const ActivityHistoryScope({
    super.key,
    required ActivityHistoryController controller,
    required super.child,
  }) : super(notifier: controller);

  static ActivityHistoryController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ActivityHistoryScope>();
    assert(scope != null, 'ActivityHistoryScope bulunamadı');
    return scope!.notifier!;
  }

  static ActivityHistoryController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ActivityHistoryScope>()
        ?.notifier;
  }
}
