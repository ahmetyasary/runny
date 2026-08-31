import '../../../core/models/activity.dart';
import 'watch_bridge.dart';

/// Telefon aktivitelerini Watch özet formatına çevirir (son 30 gün).
abstract final class WatchRecentActivitiesSync {
  static Future<void> push(
    List<Activity> activities, {
    int days = 30,
    int maxItems = 80,
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    final filtered = activities.where((activity) {
      final started = activity.startedAt?.toUtc();
      if (started == null) return true;
      return !started.isBefore(cutoff);
    }).toList(growable: false);

    final items = filtered
        .take(maxItems)
        .map(_toMap)
        .toList(growable: false);
    await WatchBridge.syncRecentActivities(items);
  }

  static Map<String, dynamic> _toMap(Activity activity) {
    return {
      'id': activity.id,
      'type': activity.type.label,
      'typeKey': activity.type.name,
      'title': activity.title,
      'distanceKm': double.parse(activity.distance.toStringAsFixed(2)),
      'durationSeconds': activity.durationSeconds,
      'durationLabel': activity.duration,
      'calories': activity.calories,
      'elevationGainMeters': activity.elevationGainMeters.round(),
      'avgHeartRate': ?activity.avgHeartRate,
      'maxHeartRate': ?activity.maxHeartRate,
      'paceLabel': ?activity.paceLabel,
      'when': activity.when,
      'startedAt': ?activity.startedAt?.toUtc().toIso8601String(),
      'location': activity.location,
    };
  }
}
