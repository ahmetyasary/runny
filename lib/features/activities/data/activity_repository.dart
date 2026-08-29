import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/activity.dart';
import '../../../core/models/activity_mapping.dart';

class ActivityRepository {
  const ActivityRepository(this.client);

  final SupabaseClient client;

  static const _select = '''
    id,
    user_id,
    type,
    title,
    location_name,
    distance_meters,
    duration_seconds,
    calories,
    elevation_gain_meters,
    avg_heart_rate,
    max_heart_rate,
    started_at,
    created_at,
    profiles:user_id ( nickname, display_name ),
    likes ( user_id ),
    comments ( count )
  ''';

  Future<String> createActivity({
    required String type,
    required String title,
    required List<LatLng> points,
    required double distanceMeters,
    required Duration duration,
    int calories = 0,
    double elevationGainMeters = 0,
    int? avgHeartRateBpm,
    int? maxHeartRateBpm,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Aktivite kaydetmek için giriş yapılmalı.');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'type': _databaseType(type),
      'title': title,
      'distance_meters': distanceMeters,
      'duration_seconds': duration.inSeconds,
      'calories': calories > 0 ? calories : null,
      'elevation_gain_meters': elevationGainMeters,
      'avg_heart_rate': avgHeartRateBpm,
      'max_heart_rate': maxHeartRateBpm,
      'started_at': DateTime.now()
          .subtract(duration)
          .toUtc()
          .toIso8601String(),
    };

    Map<String, dynamic> activity;
    try {
      activity = await client
          .from('activities')
          .insert(payload)
          .select('id')
          .single();
    } catch (_) {
      // Eski şema: sağlık kolonları yoksa sade insert.
      payload.remove('elevation_gain_meters');
      payload.remove('avg_heart_rate');
      payload.remove('max_heart_rate');
      activity = await client
          .from('activities')
          .insert(payload)
          .select('id')
          .single();
    }

    final id = activity['id'] as String;

    if (points.isNotEmpty) {
      await client.from('activity_points').insert([
        for (var index = 0; index < points.length; index++)
          {
            'activity_id': id,
            'sequence_number': index,
            'latitude': points[index].latitude,
            'longitude': points[index].longitude,
            'recorded_at': DateTime.now().toUtc().toIso8601String(),
          },
      ]);
    }

    return id;
  }

  Future<List<Activity>> fetchFeed({int limit = 30}) async {
    final rows = await client
        .from('activities')
        .select(_select)
        .eq('is_public', true)
        .order('started_at', ascending: false)
        .limit(limit);

    final uid = client.auth.currentUser?.id;
    return rows
        .map((row) => ActivityMapping.fromSupabase(row, currentUserId: uid))
        .toList();
  }

  Future<List<Activity>> searchPublic({
    required String query,
    int limit = 20,
  }) async {
    final cleaned = query
        .trim()
        .replaceAll(RegExp(r'[%_,".]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];

    final pattern = '%$cleaned%';
    final rows = await client
        .from('activities')
        .select(_select)
        .eq('is_public', true)
        .or('title.ilike."$pattern",location_name.ilike."$pattern"')
        .order('started_at', ascending: false)
        .limit(limit);

    final uid = client.auth.currentUser?.id;
    return rows
        .map((row) => ActivityMapping.fromSupabase(row, currentUserId: uid))
        .toList();
  }

  Future<List<Activity>> fetchMine({int limit = 30}) async {
    final user = client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await client
          .from('activities')
          .select(_select)
          .eq('user_id', user.id)
          .order('started_at', ascending: false)
          .limit(limit);

      return rows
          .map((row) => ActivityMapping.fromSupabase(row, currentUserId: user.id))
          .toList();
    } catch (_) {
      final rows = await client
          .from('activities')
          .select(
            'id, user_id, type, title, location_name, distance_meters, duration_seconds, calories, started_at, created_at',
          )
          .eq('user_id', user.id)
          .order('started_at', ascending: false)
          .limit(limit);

      return rows
          .map((row) => ActivityMapping.fromSupabase(row, currentUserId: user.id))
          .toList();
    }
  }

  Future<List<Activity>> fetchByUser(String userId, {int limit = 30}) async {
    final rows = await client
        .from('activities')
        .select(_select)
        .eq('user_id', userId)
        .eq('is_public', true)
        .order('started_at', ascending: false)
        .limit(limit);

    final uid = client.auth.currentUser?.id;
    return rows
        .map((row) => ActivityMapping.fromSupabase(row, currentUserId: uid))
        .toList();
  }

  Future<({double totalKm, int count, String avgPace})> fetchMyStats() async {
    final user = client.auth.currentUser;
    if (user == null) {
      return (totalKm: 0.0, count: 0, avgPace: '--:--');
    }

    final rows = await client
        .from('activities')
        .select('distance_meters, duration_seconds')
        .eq('user_id', user.id);

    if (rows.isEmpty) {
      return (totalKm: 0.0, count: 0, avgPace: '--:--');
    }

    var meters = 0.0;
    var seconds = 0;
    for (final row in rows) {
      meters += (row['distance_meters'] as num?)?.toDouble() ?? 0;
      seconds += (row['duration_seconds'] as num?)?.toInt() ?? 0;
    }

    final km = meters / 1000;
    String avgPace = '--:--';
    if (km > 0 && seconds > 0) {
      final paceSeconds = (seconds / km).round();
      final minutes = paceSeconds ~/ 60;
      final secs = paceSeconds % 60;
      avgPace = '$minutes:${secs.toString().padLeft(2, '0')}';
    }

    return (totalKm: km, count: rows.length, avgPace: avgPace);
  }

  /// Bu haftanın spor bazlı ilerlemesi: type -> (km, seans).
  Future<Map<String, ({double km, int count})>> fetchWeeklySportProgress() async {
    final user = client.auth.currentUser;
    if (user == null) return const {};

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final rows = await client
        .from('activities')
        .select('type, distance_meters, started_at')
        .eq('user_id', user.id)
        .gte('started_at', weekStart.toUtc().toIso8601String());

    final progress = <String, ({double km, int count})>{};
    for (final row in rows) {
      final type = row['type'] as String? ?? 'run';
      final km = ((row['distance_meters'] as num?)?.toDouble() ?? 0) / 1000;
      final previous = progress[type];
      progress[type] = (
        km: (previous?.km ?? 0) + km,
        count: (previous?.count ?? 0) + 1,
      );
    }
    return progress;
  }

  String _databaseType(String type) => switch (type) {
        'Koşu' => 'run',
        'Yürüyüş' => 'walk',
        'Bisiklet' => 'bike',
        'Yüzme' => 'swim',
        'Hiking' => 'hike',
        'Trail' => 'trail',
        'Fitness' => 'gym',
        'Yoga' => 'yoga',
        _ => 'run',
      };
}
