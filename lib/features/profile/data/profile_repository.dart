import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/profile.dart';

class ProfileRepository {
  const ProfileRepository(this.client);

  final SupabaseClient client;

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
    List<String> sports = const [],
    List<String> equipment = const [],
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

    final row = await client
        .from('profiles')
        .update({
          'nickname': cleaned,
          'display_name': _nullable(displayName),
          'bio': _nullable(bio),
          'profession': _nullable(profession),
          'age': age,
          'location': _nullable(location),
          'sports': sports,
          'equipment': equipment,
        })
        .eq('id', user.id)
        .select()
        .single();

    return Profile.fromJson(row);
  }

  Future<void> signOut() => client.auth.signOut();

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
