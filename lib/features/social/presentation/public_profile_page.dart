import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/profile_options.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/route_preview.dart';
import '../../activities/data/activity_repository.dart';
import '../data/social_repository.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({super.key, required this.profileId});

  final String profileId;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  Profile? _profile;
  List<Activity> _activities = const [];
  bool _loading = true;
  bool _following = false;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    if (client == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final social = SocialRepository(client);
      final profile = await social.fetchProfileById(widget.profileId);
      final activities =
          await ActivityRepository(client).fetchByUser(widget.profileId);
      final following = await social.isFollowing(widget.profileId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _activities = activities;
        _following = following;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final client = SupabaseService.client;
    if (client == null || _profile == null) return;
    setState(() => _followBusy = true);
    try {
      final following =
          await SocialRepository(client).toggleFollow(_profile!.id);
      if (!mounted) return;
      setState(() {
        _following = following;
        _profile = _profile!.copyWith(
          followerCount: _profile!.followerCount + (following ? 1 : -1),
        );
        _followBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _followBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final me = SupabaseService.client?.auth.currentUser?.id;
    final isMe = me != null && me == widget.profileId;

    return Scaffold(
      appBar: AppBar(title: Text(profile?.handle ?? 'Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? const Center(child: Text('Profil bulunamadı'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.softGreen,
                        child: Text(
                          profile.initials,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.handle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                    if (profile.profession != null ||
                        profile.location != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (profile.profession != null) profile.profession!,
                          if (profile.age != null) '${profile.age} yaş',
                          if (profile.location != null) profile.location!,
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Stat('${profile.activityCount}', 'Aktivite'),
                        _Stat('${profile.followerCount}', 'Takipçi'),
                        _Stat('${profile.followingCount}', 'Takip'),
                      ],
                    ),
                    if (!isMe) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _followBusy ? null : _toggleFollow,
                        style: FilledButton.styleFrom(
                          backgroundColor: _following
                              ? AppColors.mutedInk
                              : AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_following ? 'Takiptesin' : 'Takip et'),
                      ),
                    ],
                    if (profile.sports.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'Sporlar',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in profile.sports)
                            if (sportById(id) != null)
                              Chip(
                                avatar: Icon(sportById(id)!.icon, size: 16),
                                label: Text(sportById(id)!.label),
                              ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    const Text(
                      'Aktiviteler',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_activities.isEmpty)
                      const Text(
                        'Henüz public aktivite yok.',
                        style: TextStyle(color: AppColors.mutedInk),
                      )
                    else
                      for (final activity in _activities) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const RoutePreview(height: 90, showLabel: false),
                                const SizedBox(height: 8),
                                Text(
                                  '${activity.distance.toStringAsFixed(2)} km · ${activity.duration} · ${activity.location}',
                                  style: const TextStyle(
                                    color: AppColors.mutedInk,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
