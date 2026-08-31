import '../../../core/models/activity.dart';
import 'watch_bridge.dart';

/// Telefon aktivitelerini Watch özet formatına çevirir.
abstract final class WatchRecentActivitiesSync {
  static Future<void> push(List<Activity> activities, {int limit = 5}) async {
    final items = activities.take(limit).map(_toMap).toList(growable: false);
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
