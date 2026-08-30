import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club_models.dart';

class ClubRepository {
  const ClubRepository(this.client);

  final SupabaseClient client;

  String? get _uid => client.auth.currentUser?.id;

  Future<List<Club>> fetchClubs({int limit = 40}) async {
    final uid = _uid;
    final rows = await client
        .from('clubs')
        .select(
          'id, owner_id, name, description, sport, city, is_public, cover_url, created_at, '
          'profiles:owner_id ( display_name, nickname )',
        )
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit);

    final clubs = <Club>[];
    for (final row in rows) {
      clubs.add(await _mapClub(Map<String, dynamic>.from(row), uid));
    }
    return clubs;
  }

  Future<Club?> fetchClub(String clubId) async {
    final uid = _uid;
    final row = await client
        .from('clubs')
        .select(
          'id, owner_id, name, description, sport, city, is_public, cover_url, created_at, '
          'profiles:owner_id ( display_name, nickname )',
        )
        .eq('id', clubId)
        .maybeSingle();
    if (row == null) return null;
    return _mapClub(Map<String, dynamic>.from(row), uid);
  }

  Future<Club> createClub({
    required String name,
    required String description,
    required String sport,
    required String city,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Kulüp oluşturmak için giriş gerekli.');

    final inserted = await client
        .from('clubs')
        .insert({
          'owner_id': uid,
          'name': name.trim(),
          'description': description.trim(),
          'sport': sport.trim().isEmpty ? 'Koşu' : sport.trim(),
          'city': city.trim(),
          'is_public': true,
        })
        .select(
          'id, owner_id, name, description, sport, city, is_public, cover_url, created_at, '
          'profiles:owner_id ( display_name, nickname )',
        )
        .single();

    final clubId = inserted['id'] as String;
    await client.from('club_members').upsert({
      'club_id': clubId,
      'user_id': uid,
      'role': 'owner',
    });

    return _mapClub(Map<String, dynamic>.from(inserted), uid);
  }

  Future<void> joinClub(String clubId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Katılmak için giriş gerekli.');
    await client.from('club_members').upsert({
      'club_id': clubId,
      'user_id': uid,
      'role': 'member',
    });
  }

  Future<void> leaveClub(String clubId) async {
    final uid = _uid;
    if (uid == null) return;
    await client
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', uid);
  }

  Future<List<ClubEvent>> fetchUpcomingEvents({int limit = 40}) async {
    final uid = _uid;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await client
        .from('club_events')
        .select(
          'id, club_id, created_by, title, description, sport, location_name, starts_at, '
          'clubs:club_id ( name, is_public )',
        )
        .gte('starts_at', now)
        .order('starts_at', ascending: true)
        .limit(limit);

    return _mapEvents(rows, uid);
  }

  Future<List<ClubEvent>> fetchClubEvents(String clubId) async {
    final uid = _uid;
    final rows = await client
        .from('club_events')
        .select(
          'id, club_id, created_by, title, description, sport, location_name, starts_at, '
          'clubs:club_id ( name, is_public )',
        )
        .eq('club_id', clubId)
        .order('starts_at', ascending: true)
        .limit(50);

    return _mapEvents(rows, uid);
  }

  Future<ClubEvent> createEvent({
    required String clubId,
    required String title,
    required String description,
    required String sport,
    required String locationName,
    required DateTime startsAt,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Etkinlik oluşturmak için giriş gerekli.');

    final inserted = await client
        .from('club_events')
        .insert({
          'club_id': clubId,
          'created_by': uid,
          'title': title.trim(),
          'description': description.trim(),
          'sport': sport.trim().isEmpty ? 'Koşu' : sport.trim(),
          'location_name': locationName.trim(),
          'starts_at': startsAt.toUtc().toIso8601String(),
        })
        .select(
          'id, club_id, created_by, title, description, sport, location_name, starts_at, '
          'clubs:club_id ( name, is_public )',
        )
        .single();

    final eventId = inserted['id'] as String;
    await client.from('club_event_participants').upsert({
      'event_id': eventId,
      'user_id': uid,
    });

    final mapped = await _mapEvents([inserted], uid);
    return mapped.first;
  }

  Future<void> joinEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Katılmak için giriş gerekli.');
    await client.from('club_event_participants').upsert({
      'event_id': eventId,
      'user_id': uid,
    });
  }

  Future<void> leaveEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return;
    await client
        .from('club_event_participants')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', uid);
  }

  Future<Club> _mapClub(Map<String, dynamic> row, String? uid) async {
    final clubId = row['id'] as String;
    final ownerId = row['owner_id'] as String;
    final profile = row['profiles'] as Map<String, dynamic>?;
    final displayName = profile?['display_name'] as String?;
    final nickname = profile?['nickname'] as String? ?? 'runny';
    final ownerName =
        (displayName != null && displayName.trim().isNotEmpty)
            ? displayName
            : nickname;

    final memberCount = await client
        .from('club_members')
        .count(CountOption.exact)
        .eq('club_id', clubId);

    var isMember = false;
    if (uid != null) {
      final mine = await client
          .from('club_members')
          .select('user_id')
          .eq('club_id', clubId)
          .eq('user_id', uid)
          .maybeSingle();
      isMember = mine != null;
    }

    return Club(
      id: clubId,
      ownerId: ownerId,
      name: row['name'] as String? ?? 'Kulüp',
      description: row['description'] as String? ?? '',
      sport: row['sport'] as String? ?? 'Koşu',
      city: row['city'] as String? ?? '',
      isPublic: row['is_public'] as bool? ?? true,
      coverUrl: row['cover_url'] as String?,
      memberCount: memberCount,
      isMember: isMember,
      isOwner: uid != null && uid == ownerId,
      ownerName: ownerName,
    );
  }

  Future<List<ClubEvent>> _mapEvents(List<dynamic> rows, String? uid) async {
    final events = <ClubEvent>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final eventId = row['id'] as String;
      final club = row['clubs'] as Map<String, dynamic>?;
      if (club != null && club['is_public'] == false) {
        // Üye değilsek private kulüp etkinliğini atla (RLS zaten engeller).
      }

      final participantCount = await client
          .from('club_event_participants')
          .count(CountOption.exact)
          .eq('event_id', eventId);

      var isJoined = false;
      if (uid != null) {
        final mine = await client
            .from('club_event_participants')
            .select('user_id')
            .eq('event_id', eventId)
            .eq('user_id', uid)
            .maybeSingle();
        isJoined = mine != null;
      }

      events.add(
        ClubEvent(
          id: eventId,
          clubId: row['club_id'] as String,
          clubName: club?['name'] as String? ?? 'Kulüp',
          createdBy: row['created_by'] as String,
          title: row['title'] as String? ?? 'Etkinlik',
          description: row['description'] as String? ?? '',
          sport: row['sport'] as String? ?? 'Koşu',
          locationName: row['location_name'] as String? ?? '',
          startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
          participantCount: participantCount,
          isJoined: isJoined,
        ),
      );
    }
    return events;
  }
}
