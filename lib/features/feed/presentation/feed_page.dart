import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/profile_options.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/runny_logo.dart';
import '../../../shared/widgets/route_preview.dart';
import '../../activities/data/activity_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/comments_sheet.dart';
import '../../social/presentation/public_profile_page.dart';
import 'notifications_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    this.onOpenOwnProfile,
  });

  final VoidCallback? onOpenOwnProfile;

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  Profile? _profile;
  List<Activity> _activities = const [];
  Map<String, ({double km, int count})> _weeklyProgress = const {};
  bool _loading = true;

  int _pendingNewCount = 0;
  Set<String> _followingIds = {};
  final Set<String> _seenActivityIds = {};
  final List<FeedNotificationItem> _notifications = [];
  RealtimeChannel? _feedChannel;

  static String greetingForNow([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 12) return 'Günaydın';
    if (hour >= 12 && hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  int get _unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    unawaited(_teardownRealtime());
    super.dispose();
  }

  Future<void> _teardownRealtime() async {
    final channel = _feedChannel;
    _feedChannel = null;
    if (channel == null) return;
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      await client.removeChannel(channel);
    } catch (_) {}
  }

  Future<void> _setupRealtime() async {
    final client = SupabaseService.client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) {
      await _teardownRealtime();
      return;
    }

    await _teardownRealtime();

    final channel = client.channel('feed-activities-$uid');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'activities',
      callback: _onActivityInserted,
    );
    channel.subscribe();
    _feedChannel = channel;
  }

  void _onActivityInserted(PostgresChangePayload payload) {
    final row = payload.newRecord;
    final activityId = row['id'] as String?;
    final userId = row['user_id'] as String?;
    final isPublic = row['is_public'] as bool? ?? true;
    final me = SupabaseService.client?.auth.currentUser?.id;

    if (activityId == null || userId == null) return;
    if (userId == me) return;
    if (!isPublic) return;
    if (!_followingIds.contains(userId)) return;
    if (_seenActivityIds.contains(activityId)) return;

    _seenActivityIds.add(activityId);

    final typeLabel = (row['type'] as String?) ?? 'Aktivite';
    final title = (row['title'] as String?) ?? '$typeLabel aktivitesi';
    final distanceMeters = (row['distance_meters'] as num?)?.toDouble();
    final createdRaw = row['created_at'] as String?;
    final createdAt = createdRaw != null
        ? DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    if (!mounted) return;
    setState(() {
      _pendingNewCount += 1;
      _notifications.insert(
        0,
        FeedNotificationItem(
          activityId: activityId,
          userId: userId,
          userName: 'Takip ettiğin biri',
          activityType: typeLabel,
          title: title,
          createdAt: createdAt,
          distanceKm:
              distanceMeters == null ? null : distanceMeters / 1000,
          isRead: false,
        ),
      );
    });
    unawaited(_enrichNotification(activityId, userId));
  }

  Future<void> _enrichNotification(String activityId, String userId) async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      final profile = await SocialRepository(client).fetchProfileById(userId);
      if (profile == null || !mounted) return;
      setState(() {
        final index =
            _notifications.indexWhere((n) => n.activityId == activityId);
        if (index < 0) return;
        final prev = _notifications[index];
        _notifications[index] = FeedNotificationItem(
          activityId: prev.activityId,
          userId: prev.userId,
          userName: profile.name,
          avatarUrl: profile.avatarUrl,
          activityType: prev.activityType,
          title: prev.title,
          createdAt: prev.createdAt,
          distanceKm: prev.distanceKm,
          isRead: prev.isRead,
        );
      });
    } catch (_) {}
  }

  void _syncNotificationsFromFeed(List<Activity> feed) {
    final existingIds = _notifications.map((n) => n.activityId).toSet();
    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.activityId)
        .toSet();

    final merged = <FeedNotificationItem>[
      // Önce okunmamış (realtime) bildirimleri koru.
      ..._notifications.where((n) => !n.isRead),
    ];
    final mergedIds = merged.map((n) => n.activityId).toSet();

    for (final activity in feed) {
      final userId = activity.userId;
      if (userId == null) continue;
      if (mergedIds.contains(activity.id)) continue;
      merged.add(
        FeedNotificationItem(
          activityId: activity.id,
          userId: userId,
          userName: activity.userName,
          activityType: activity.type.label,
          title: activity.title,
          createdAt: activity.startedAt ?? DateTime.now(),
          distanceKm: activity.distance,
          isRead: !unreadIds.contains(activity.id),
        ),
      );
      mergedIds.add(activity.id);
    }

    // Eski okunmuşları da tut (feed'de yoksa silinmesin diye sınırlı).
    for (final n in _notifications) {
      if (mergedIds.contains(n.activityId)) continue;
      if (existingIds.contains(n.activityId)) {
        merged.add(n);
        mergedIds.add(n.activityId);
      }
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (merged.length > 50) {
      merged.removeRange(50, merged.length);
    }
    _notifications
      ..clear()
      ..addAll(merged);
  }

  Future<void> refresh({bool silent = false}) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      await _teardownRealtime();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _activities = const [];
        _weeklyProgress = const {};
        _followingIds = {};
        _pendingNewCount = 0;
        _seenActivityIds.clear();
        _notifications.clear();
        _loading = false;
      });
      return;
    }

    if (!silent || _profile == null) {
      setState(() => _loading = true);
    }
    try {
      final profileRepo = ProfileRepository(client);
      final activityRepo = ActivityRepository(client);
      final social = SocialRepository(client);

      Profile? profile;
      Map<String, ({double km, int count})> weekly = const {};
      List<Activity> feed = const [];
      var following = <String>{};

      try {
        final results = await Future.wait([
          profileRepo.fetchCurrent(),
          activityRepo.fetchWeeklySportProgress(),
          social.fetchFollowingIds(),
        ]);
        profile = results[0] as Profile?;
        weekly = results[1] as Map<String, ({double km, int count})>;
        following = results[2] as Set<String>;
      } catch (_) {}

      try {
        feed = await activityRepo.fetchFeed();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _weeklyProgress = weekly;
        _activities = feed;
        _followingIds = following;
        _pendingNewCount = 0;
        _seenActivityIds
          ..clear()
          ..addAll(feed.map((a) => a.id));
        _syncNotificationsFromFeed(feed);
        _loading = false;
      });
      await _setupRealtime();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadNewActivities() async {
    await refresh(silent: true);
  }

  Future<void> _toggleLike(int index) async {
    final client = SupabaseService.client;
    if (client == null) return;
    final previous = _activities[index];
    final optimisticLiked = !previous.isLiked;

    setState(() {
      _activities[index] = previous.copyWith(
        isLiked: optimisticLiked,
        likes: previous.likes + (optimisticLiked ? 1 : -1),
      );
    });

    try {
      await SocialRepository(client).toggleLike(previous.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activities[index] = previous);
    }
  }

  Future<void> _openComments(int index) async {
    final activity = _activities[index];
    await CommentsSheet.show(
      context,
      activityId: activity.id,
      onCountChanged: (count) {
        if (!mounted) return;
        setState(() {
          _activities[index] = _activities[index].copyWith(comments: count);
        });
      },
    );
  }

  void _openProfile(Activity activity) {
    final userId = activity.userId;
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(profileId: userId),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          items: List<FeedNotificationItem>.from(_notifications),
          onMarkAllRead: () {
            if (!mounted) return;
            setState(() {
              for (final n in _notifications) {
                n.isRead = true;
              }
              _pendingNewCount = 0;
            });
          },
          onOpenActivity: (_) {
            // Profil sayfasına gider; akış banner'ı da temizlensin.
            if (!mounted) return;
            setState(() => _pendingNewCount = 0);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_profile?.name ?? 'koşucu').split(' ').first;
    final greeting = FeedPageState.greetingForNow();
    final unread = _unreadNotificationCount;

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RunnyLogo(height: 26),
                        const SizedBox(height: 14),
                        Text(
                          '$greeting, $firstName 👋',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Bugün hareket etmeye hazır mısın?',
                          style: TextStyle(color: AppColors.mutedInk, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    icon: unread > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    badgeCount: unread,
                    onPressed: _openNotifications,
                  ),
                  const SizedBox(width: 9),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onOpenOwnProfile,
                      child: CircleAvatar(
                        radius: 21,
                        backgroundColor: AppColors.softGreen,
                        backgroundImage: _profile?.avatarUrl != null
                            ? NetworkImage(_profile!.avatarUrl!)
                            : null,
                        child: _profile?.avatarUrl == null
                            ? Text(
                                _profile?.initials ?? 'RN',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_pendingNewCount > 0)
            SoftWrapToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _NewActivitiesBanner(
                  count: _pendingNewCount,
                  onTap: _loadNewActivities,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            sliver: SliverToBoxAdapter(
              child: _WeeklyProgressCard(
                profile: _profile,
                progress: _weeklyProgress,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            sliver: SoftWrapToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Arkadaşlarından',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('Yenile'),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_activities.isEmpty)
            const SoftWrapFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Henüz takip ettiğin kimse yok.\nKeşfet’ten insan bulup takip ettiğinde paylaşımları burada görünür.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedInk, height: 1.5),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.separated(
                itemCount: _activities.length,
                itemBuilder: (context, index) => _ActivityCard(
                  activity: _activities[index],
                  onLike: () => _toggleLike(index),
                  onComment: () => _openComments(index),
                  onOpenProfile: () => _openProfile(_activities[index]),
                ),
                separatorBuilder: (context, index) => const SizedBox(height: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class SoftWrapToBoxAdapter extends StatelessWidget {
  const SoftWrapToBoxAdapter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class SoftWrapFillRemaining extends StatelessWidget {
  const SoftWrapFillRemaining({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SliverFillRemaining(hasScrollBody: false, child: child);
}

class _NewActivitiesBanner extends StatelessWidget {
  const _NewActivitiesBanner({
    required this.count,
    required this.onTap,
  });

  final int count;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        count <= 1 ? 'Yeni aktiviteler' : 'Yeni aktiviteler ($count)';

    return Material(
      color: AppColors.primaryDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.fiber_new_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const Text(
                'Yenile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.profile,
    required this.progress,
  });

  final Profile? profile;
  final Map<String, ({double km, int count})> progress;

  static String _formatKm(double value) {
    final rounded = value == value.roundToDouble();
    return value.toStringAsFixed(rounded ? 0 : 1);
  }

  /// Profilim'deki "Haftalık hedefler" ile aynı kaynak / aynı mantık.
  List<_WeeklyGoalLine> _goalLines() {
    final profile = this.profile;
    if (profile == null) return const [];

    final lines = <_WeeklyGoalLine>[];
    final seen = <String>{};

    // Önce seçili sporlar (Profil sırası), sonra ekstra hedefler.
    final orderedIds = <String>[
      ...profile.sports,
      for (final id in profile.sportGoals.keys)
        if (!profile.sports.contains(id)) id,
    ];

    for (final id in orderedIds) {
      if (!seen.add(id)) continue;
      final sport = sportById(id);
      final goal = profile.sportGoals[id];
      if (goal == null || !goal.hasTarget) continue;

      final done = progress[id];
      final useDistance =
          (sport == null || sport.usesDistance) && goal.weeklyKm != null;

      if (useDistance) {
        final target = goal.weeklyKm!;
        final current = done?.km ?? 0;
        final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
        lines.add(
          _WeeklyGoalLine(
            label: sport?.label ?? id,
            headline: '${_formatKm(current)} / ${_formatKm(target)} km',
            progress: ratio,
            activityCount: done?.count ?? 0,
          ),
        );
      } else if (goal.weeklyCount != null && goal.weeklyCount! > 0) {
        final target = goal.weeklyCount!;
        final current = done?.count ?? 0;
        final ratio = (current / target).clamp(0.0, 1.0);
        lines.add(
          _WeeklyGoalLine(
            label: sport?.label ?? id,
            headline: '$current / $target seans',
            progress: ratio,
            activityCount: current,
          ),
        );
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _goalLines();
    final totalActivities =
        lines.fold<int>(0, (sum, line) => sum + line.activityCount);

    // Tek kartta özet: birden fazla hedef varsa birleştirilmiş km/seans oranı.
    late final String headline;
    late final double ratio;
    late final bool hasGoal;

    if (lines.isEmpty) {
      headline = 'Hedef yok';
      ratio = 0;
      hasGoal = false;
    } else if (lines.length == 1) {
      headline = lines.first.headline;
      ratio = lines.first.progress;
      hasGoal = true;
    } else {
      // Birden fazla hedef: ortalama tamamlanma + ilk hedefin metni öne.
      ratio = lines.map((l) => l.progress).reduce((a, b) => a + b) /
          lines.length;
      headline = lines.map((l) => '${l.label}: ${l.headline}').join(' · ');
      hasGoal = true;
    }

    final percent = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F6F3B), Color(0xFF49B86A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Haftalık hedefin',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lines.length <= 1
                          ? headline
                          : '%$percent tamamlandı',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (lines.length > 1) ...[
                      const SizedBox(height: 8),
                      for (final line in lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${line.label}: ${line.headline}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD166),
                  size: 27,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: hasGoal ? ratio : 0,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD166)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bu hafta $totalActivities aktivite',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                hasGoal ? '%$percent tamamlandı' : 'Profil’den hedef ekle',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoalLine {
  const _WeeklyGoalLine({
    required this.label,
    required this.headline,
    required this.progress,
    required this.activityCount,
  });

  final String label;
  final String headline;
  final double progress;
  final int activityCount;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onLike,
    required this.onComment,
    required this.onOpenProfile,
  });

  final Activity activity;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final initials = activity.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: activity.type.color.withValues(alpha: .15),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: activity.type.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.userName,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${activity.type.label} · ${activity.when}',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(activity.type.icon, color: activity.type.color),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              activity.title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 15, color: AppColors.mutedInk),
                const SizedBox(width: 4),
                Text(
                  activity.location,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 13),
            RoutePreview(
              height: 135,
              locationLabel: activity.location,
              accentColor: activity.type.color,
              routePoints: activity.routePoints,
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _Metric(
                  label: 'Mesafe',
                  value: '${activity.distance.toStringAsFixed(2)} km',
                ),
                _Metric(label: 'Süre', value: activity.duration),
                const Spacer(),
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          activity.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 19,
                          color: activity.isLiked
                              ? Colors.redAccent
                              : AppColors.mutedInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.likes}',
                          style: TextStyle(
                            color: activity.isLiked
                                ? Colors.redAccent
                                : AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: onComment,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: AppColors.mutedInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.comments}',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedInk, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppColors.ink, size: 21),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE15B64),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
