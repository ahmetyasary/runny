class Profile {
  const Profile({
    required this.id,
    required this.nickname,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.profession,
    this.age,
    this.location,
    this.sports = const [],
    this.equipment = const [],
    this.activityCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  final String id;
  final String nickname;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? profession;
  final int? age;
  final String? location;
  final List<String> sports;
  final List<String> equipment;
  final int activityCount;
  final int followerCount;
  final int followingCount;

  String get handle => '@$nickname';

  String get name =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : nickname;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get needsNicknameSetup => nickname.startsWith('user_');

  Profile copyWith({
    String? nickname,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? profession,
    int? age,
    String? location,
    List<String>? sports,
    List<String>? equipment,
    int? activityCount,
    int? followerCount,
    int? followingCount,
  }) {
    return Profile(
      id: id,
      nickname: nickname ?? this.nickname,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      profession: profession ?? this.profession,
      age: age ?? this.age,
      location: location ?? this.location,
      sports: sports ?? this.sports,
      equipment: equipment ?? this.equipment,
      activityCount: activityCount ?? this.activityCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      profession: json['profession'] as String?,
      age: (json['age'] as num?)?.toInt(),
      location: json['location'] as String?,
      sports: _stringList(json['sports']),
      equipment: _stringList(json['equipment']),
      activityCount: (json['activity_count'] as num?)?.toInt() ?? 0,
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }
}
