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
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Aktivite kaydetmek için giriş yapılmalı.');
    }

    final activity = await client
        .from('activities')
        .insert({
          'user_id': user.id,
          'type': _databaseType(type),
          'title': title,
          'distance_meters': distanceMeters,
          'duration_seconds': duration.inSeconds,
          'started_at': DateTime.now()
              .subtract(duration)
              .toUtc()
              .toIso8601String(),
        })
        .select('id')
        .single();

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
