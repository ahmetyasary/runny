import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/profile.dart';
import '../../../core/models/sport_goal.dart';

class ProfileRepository {
  const ProfileRepository(this.client);

  final SupabaseClient client;

  static const _avatarBucket = 'avatars';

  Future<Profile?> fetchCurrent() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;

    final activityCount = await client
        .from('activities')
        .count(CountOption.exact)
        .eq('user_id', user.id);

    final followerCount = await client
        .from('follows')
        .count(CountOption.exact)
        .eq('following_id', user.id);

    final followingCount = await client
        .from('follows')
        .count(CountOption.exact)
        .eq('follower_id', user.id);

    return Profile.fromJson({
      ...row,
      'activity_count': activityCount,
      'follower_count': followerCount,
      'following_count': followingCount,
    });
  }

  Future<Profile> updateProfile({
    required String nickname,
    String? displayName,
    String? bio,
    String? profession,
    int? age,
    String? location,
    String? avatarUrl,
    List<String> sports = const [],
    List<String> equipment = const [],
    Map<String, SportGoal> sportGoals = const {},
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Profil güncellemek için giriş yapılmalı.');
    }

    final cleaned =
        nickname.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (cleaned.length < 3) {
      throw ArgumentError('Nickname en az 3 karakter olmalı (a-z, 0-9, _).');
    }

    final filteredGoals = <String, SportGoal>{
      for (final id in sports)
        if (sportGoals[id]?.hasTarget == true) id: sportGoals[id]!,
    };

    final payload = <String, dynamic>{
      'nickname': cleaned,
      'display_name': _nullable(displayName),
      'bio': _nullable(bio),
      'profession': _nullable(profession),
      'age': age,
      'location': _nullable(location),
      'sports': sports,
      'equipment': equipment,
      'sport_goals': SportGoal.mapToJson(filteredGoals),
    };
    if (avatarUrl != null) {
      // Boş string = fotoğrafı kaldır.
      payload['avatar_url'] = avatarUrl.isEmpty ? null : avatarUrl;
    }

    final row = await client
        .from('profiles')
        .update(payload)
        .eq('id', user.id)
        .select()
        .single();

    return Profile.fromJson(row);
  }

  /// Kameradan / galeriden seçilen bytes'ı yükler, public URL döner.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Fotoğraf yüklemek için giriş yapılmalı.');
    }

    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
            ? 'webp'
            : 'jpg';
    final path = '${user.id}/avatar.$ext';

    try {
      await client.storage.from(_avatarBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType.startsWith('image/')
                  ? contentType
                  : 'image/jpeg',
              cacheControl: '3600',
            ),
          );
    } on StorageException catch (error) {
      // Bucket yok / RLS → daha anlaşılır mesaj.
      final msg = error.message.toLowerCase();
      if (msg.contains('bucket') ||
          msg.contains('not found') ||
          msg.contains('row-level security') ||
          msg.contains('unauthorized') ||
          error.statusCode == '404' ||
          error.statusCode == '403') {
        throw StorageException(
          'avatars bucket / izin eksik. Supabase’de 009_avatars_storage.sql çalıştır.',
          statusCode: error.statusCode,
        );
      }
      rethrow;
    }

    final publicUrl = client.storage.from(_avatarBucket).getPublicUrl(path);
    // Cache-bust so UI refreshes immediately after replace.
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> signOut() => client.auth.signOut();

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
