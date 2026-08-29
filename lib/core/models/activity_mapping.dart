import '../../../core/models/activity.dart';

abstract final class ActivityMapping {
  static ActivityType typeFromDb(String value) => switch (value) {
        'walk' => ActivityType.walk,
        'bike' => ActivityType.bike,
        'hike' => ActivityType.hike,
        'swim' => ActivityType.swim,
        'trail' => ActivityType.trail,
        'gym' => ActivityType.gym,
        'yoga' => ActivityType.yoga,
        _ => ActivityType.run,
      };

  static String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static String relativeWhen(DateTime date) {
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day}.${date.month}.${date.year}';
  }

  static Activity fromSupabase(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final likes = json['likes'];
    final comments = json['comments'];

    var likeCount = 0;
    var isLiked = false;
    if (likes is List) {
      if (likes.isNotEmpty && likes.first is Map && likes.first.containsKey('count')) {
        likeCount = (likes.first['count'] as num?)?.toInt() ?? 0;
      } else {
        likeCount = likes.length;
        if (currentUserId != null) {
          isLiked = likes.any(
            (like) => like is Map && like['user_id'] == currentUserId,
          );
        }
      }
    }

    final commentCount = comments is List && comments.isNotEmpty
        ? (comments.first['count'] as num?)?.toInt() ?? comments.length
        : 0;
    final startedAt = DateTime.parse(
      (json['started_at'] ?? json['created_at']) as String,
    );
    final nickname = profile?['nickname'] as String? ?? 'runny';
    final displayName = profile?['display_name'] as String?;

    return Activity(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName
          : nickname,
      userHandle: '@$nickname',
      type: typeFromDb(json['type'] as String),
      title: json['title'] as String,
      location: (json['location_name'] as String?) ?? 'Konum yok',
      distance: ((json['distance_meters'] as num?)?.toDouble() ?? 0) / 1000,
      duration: formatDuration((json['duration_seconds'] as num?)?.toInt() ?? 0),
      when: relativeWhen(startedAt),
      likes: likeCount,
      comments: commentCount,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      elevationGainMeters:
          (json['elevation_gain_meters'] as num?)?.toDouble() ?? 0,
      avgHeartRate: (json['avg_heart_rate'] as num?)?.toInt(),
      maxHeartRate: (json['max_heart_rate'] as num?)?.toInt(),
      isLiked: isLiked,
    );
  }
}
