import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/models/profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/runny_logo.dart';
import '../../../shared/widgets/route_preview.dart';
import '../../activities/data/activity_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/comments_sheet.dart';
import '../../social/presentation/public_profile_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  Profile? _profile;
  List<Activity> _activities = demoActivities;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _profile = const Profile(
          id: 'demo',
          nickname: 'ahmetyasary',
          displayName: 'Ahmet Yaşar',
        );
        _activities = demoActivities;
        _loading = false;
      });
      return;
    }

    if (!silent || _profile == null) {
      setState(() => _loading = true);
    }
    try {
      final profile = await ProfileRepository(client).fetchCurrent();
      final feed = await ActivityRepository(client).fetchFeed();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _activities = feed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final firstName = (_profile?.name ?? 'koşucu').split(' ').first;

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
                          'Günaydın, $firstName 👋',
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
                    icon: Icons.notifications_none_rounded,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 9),
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.softGreen,
                    child: Text(
                      _profile?.initials ?? 'RN',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            sliver: SliverToBoxAdapter(child: _WeeklyProgressCard()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            sliver: SliverToBoxAdapter(
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
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Henüz paylaşılmış aktivite yok.\nİlk rotanı kaydet ve paylaş!',
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

class _WeeklyProgressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haftalık hedefin',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '32,4 / 40 km',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
            child: const LinearProgressIndicator(
              value: .81,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(Color(0xFFFFD166)),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bu hafta 4 aktivite',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '%81 tamamlandı',
                style: TextStyle(
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
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.ink, size: 21),
        ),
      ),
    );
  }
}
