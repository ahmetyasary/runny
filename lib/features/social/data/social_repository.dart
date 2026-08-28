import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/profile.dart';

class CommentItem {
  const CommentItem({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.userName,
    required this.userHandle,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String userName;
  final String userHandle;
}

class SocialRepository {
  const SocialRepository(this.client);

  final SupabaseClient client;

  String? get _uid => client.auth.currentUser?.id;

  Future<bool> toggleLike(String activityId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Beğenmek için giriş gerekli.');

    final existing = await client
        .from('likes')
        .select('user_id')
        .eq('activity_id', activityId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('likes')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', uid);
      return false;
    }

    await client.from('likes').insert({
      'activity_id': activityId,
      'user_id': uid,
    });
    return true;
  }

  Future<List<CommentItem>> fetchComments(String activityId) async {
    final rows = await client
        .from('comments')
        .select(
          'id, body, created_at, profiles:user_id ( nickname, display_name )',
        )
        .eq('activity_id', activityId)
        .order('created_at', ascending: true);

    return rows.map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final nickname = profile?['nickname'] as String? ?? 'runny';
      final displayName = profile?['display_name'] as String?;
      return CommentItem(
        id: row['id'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        userName: (displayName != null && displayName.trim().isNotEmpty)
            ? displayName
            : nickname,
        userHandle: '@$nickname',
      );
    }).toList();
  }

  Future<CommentItem> addComment({
    required String activityId,
    required String body,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Yorum için giriş gerekli.');

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Yorum boş olamaz.');
    }

    final row = await client
        .from('comments')
        .insert({
          'activity_id': activityId,
          'user_id': uid,
          'body': trimmed,
        })
        .select(
          'id, body, created_at, profiles:user_id ( nickname, display_name )',
        )
        .single();

    final profile = row['profiles'] as Map<String, dynamic>?;
    final nickname = profile?['nickname'] as String? ?? 'runny';
    final displayName = profile?['display_name'] as String?;

    return CommentItem(
      id: row['id'] as String,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      userName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName
          : nickname,
      userHandle: '@$nickname',
    );
  }

  Future<bool> isFollowing(String profileId) async {
    final uid = _uid;
    if (uid == null) return false;

    final row = await client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', profileId)
        .maybeSingle();

    return row != null;
  }

  Future<bool> toggleFollow(String profileId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Takip için giriş gerekli.');
    if (uid == profileId) {
      throw ArgumentError('Kendini takip edemezsin.');
    }

    final existing = await client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', uid)
        .eq('following_id', profileId)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('follows')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', profileId);
      return false;
    }

    await client.from('follows').insert({
      'follower_id': uid,
      'following_id': profileId,
    });
    return true;
  }

  Future<List<Profile>> searchProfiles(String query, {int limit = 20}) async {
    final cleaned = _sanitizeSearch(query);
    if (cleaned.isEmpty) return const [];

    final pattern = '%$cleaned%';
    final rows = await client
        .from('profiles')
        .select()
        .or('nickname.ilike."$pattern",display_name.ilike."$pattern"')
        .limit(limit);

    return rows.map(Profile.fromJson).toList();
  }

  /// Keşfet için önerilen kullanıcılar (kendisi hariç, yeni kayıtlar önce).
  Future<List<Profile>> fetchSuggestedProfiles({int limit = 12}) async {
    final uid = _uid;
    final filter = client.from('profiles').select();
    final rows = uid == null
        ? await filter.order('created_at', ascending: false).limit(limit)
        : await filter
            .neq('id', uid)
            .order('created_at', ascending: false)
            .limit(limit);

    return rows.map(Profile.fromJson).toList();
  }

  String _sanitizeSearch(String query) {
    return query
        .trim()
        .replaceAll('@', '')
        .replaceAll(RegExp(r'[%_,."]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<Profile?> fetchProfileById(String id) async {
    final row =
        await client.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;

    final activityCount = await client
        .from('activities')
        .count(CountOption.exact)
        .eq('user_id', id);
    final followerCount = await client
        .from('follows')
        .count(CountOption.exact)
        .eq('following_id', id);
    final followingCount = await client
        .from('follows')
        .count(CountOption.exact)
        .eq('follower_id', id);

    return Profile.fromJson({
      ...row,
      'activity_count': activityCount,
      'follower_count': followerCount,
      'following_count': followingCount,
    });
  }
}
