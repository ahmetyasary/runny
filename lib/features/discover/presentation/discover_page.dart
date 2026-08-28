import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/models/profile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/route_preview.dart';
import '../../activities/data/activity_repository.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/comments_sheet.dart';
import '../../social/presentation/public_profile_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => DiscoverPageState();
}

class DiscoverPageState extends State<DiscoverPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Profile> _people = const [];
  List<Profile> _suggested = const [];
  List<Activity> _routes = const [];
  List<Activity> _matchedRoutes = const [];

  bool _loading = true;
  bool _searching = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh({bool silent = false}) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _suggested = const [];
        _routes = demoActivities;
        _loading = false;
        _error = null;
      });
      return;
    }

    if (!silent || (_routes.isEmpty && _suggested.isEmpty)) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final social = SocialRepository(client);
      final activities = ActivityRepository(client);
      final results = await Future.wait([
        social.fetchSuggestedProfiles(),
        activities.fetchFeed(limit: 20),
      ]);
      if (!mounted) return;
      setState(() {
        _suggested = results[0] as List<Profile>;
        _routes = results[1] as List<Activity>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Keşfet yüklenemedi. Aşağıya çekerek tekrar dene.';
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    setState(() => _query = query);

    final client = SupabaseService.client;
    if (client == null || query.isEmpty) {
      setState(() {
        _people = const [];
        _matchedRoutes = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final social = SocialRepository(client);
      final activities = ActivityRepository(client);
      final results = await Future.wait([
        social.searchProfiles(query),
        activities.searchPublic(query: query),
      ]);
      if (!mounted) return;
      setState(() {
        _people = results[0] as List<Profile>;
        _matchedRoutes = results[1] as List<Activity>;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _toggleLike({required bool fromSearch, required int index}) async {
    final client = SupabaseService.client;
    if (client == null) return;

    final source = fromSearch ? _matchedRoutes : _routes;
    final previous = source[index];
    final optimisticLiked = !previous.isLiked;
    final updated = List<Activity>.from(source);
    updated[index] = previous.copyWith(
      isLiked: optimisticLiked,
      likes: previous.likes + (optimisticLiked ? 1 : -1),
    );

    setState(() {
      if (fromSearch) {
        _matchedRoutes = updated;
      } else {
        _routes = updated;
      }
    });

    try {
      await SocialRepository(client).toggleLike(previous.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (fromSearch) {
          _matchedRoutes = List<Activity>.from(source)..[index] = previous;
        } else {
          _routes = List<Activity>.from(source)..[index] = previous;
        }
      });
    }
  }

  Future<void> _openComments({required bool fromSearch, required int index}) async {
    final source = fromSearch ? _matchedRoutes : _routes;
    final activity = source[index];
    await CommentsSheet.show(
      context,
      activityId: activity.id,
      onCountChanged: (count) {
        if (!mounted) return;
        setState(() {
          if (fromSearch) {
            _matchedRoutes = List<Activity>.from(_matchedRoutes)
              ..[index] = _matchedRoutes[index].copyWith(comments: count);
          } else {
            _routes = List<Activity>.from(_routes)
              ..[index] = _routes[index].copyWith(comments: count);
          }
        });
      },
    );
  }

  void _openProfile(String? userId) {
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
    final searching = _query.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        if (searching) {
          await _search(_query);
        } else {
          await refresh();
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Keşfet',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Kişi, aktivite veya konum ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ),
          if (searching)
            ..._buildSearchSlivers()
          else
            ..._buildBrowseSlivers(),
        ],
      ),
    );
  }

  List<Widget> _buildBrowseSlivers() {
    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Icon(Icons.explore_rounded, color: Color(0xFF6D62C5), size: 30),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İnsanları ve rotaları keşfet',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nickname ile ara, takip et, paylaşılan aktiviteleri gör.',
                        style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_error != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ),
      if (_suggested.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Keşfetmeye değer',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 118,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _suggested.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final person = _suggested[index];
                return _SuggestedPersonChip(
                  profile: person,
                  onTap: () => _openProfile(person.id),
                );
              },
            ),
          ),
        ),
      ],
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Son paylaşılanlar',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
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
      if (_routes.isEmpty)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Henüz herkese açık aktivite yok.\nİlk rotanı kaydet ve paylaş!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedInk, height: 1.5),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList.separated(
            itemCount: _routes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activity = _routes[index];
              return _DiscoverActivityCard(
                activity: activity,
                onOpenProfile: () => _openProfile(activity.userId),
                onLike: () => _toggleLike(fromSearch: false, index: index),
                onComment: () => _openComments(fromSearch: false, index: index),
              );
            },
          ),
        ),
    ];
  }

  List<Widget> _buildSearchSlivers() {
    if (_searching) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final empty = _people.isEmpty && _matchedRoutes.isEmpty;
    if (empty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Sonuç bulunamadı.',
              style: TextStyle(color: AppColors.mutedInk),
            ),
          ),
        ),
      ];
    }

    return [
      if (_people.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Kişiler',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverList.separated(
            itemCount: _people.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final person = _people[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.line),
                ),
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: AppColors.softGreen,
                  child: Text(
                    person.initials,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                title: Text(
                  person.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(person.handle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openProfile(person.id),
              );
            },
          ),
        ),
      ],
      if (_matchedRoutes.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Aktiviteler',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList.separated(
            itemCount: _matchedRoutes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final activity = _matchedRoutes[index];
              return _DiscoverActivityCard(
                activity: activity,
                onOpenProfile: () => _openProfile(activity.userId),
                onLike: () => _toggleLike(fromSearch: true, index: index),
                onComment: () => _openComments(fromSearch: true, index: index),
              );
            },
          ),
        ),
      ],
    ];
  }
}

class _SuggestedPersonChip extends StatelessWidget {
  const _SuggestedPersonChip({
    required this.profile,
    required this.onTap,
  });

  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.softGreen,
              child: Text(
                profile.initials,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              profile.handle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverActivityCard extends StatelessWidget {
  const _DiscoverActivityCard({
    required this.activity,
    required this.onOpenProfile,
    required this.onLike,
    required this.onComment,
  });

  final Activity activity;
  final VoidCallback onOpenProfile;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpenProfile,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: RoutePreview(
                      height: 96,
                      showLabel: false,
                      accentColor: activity.type.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activity.type.label} · ${activity.when}',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.route_rounded,
                              size: 15,
                              color: activity.type.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${activity.distance.toStringAsFixed(2)} km',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                activity.userHandle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.mutedInk,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    activity.duration,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            activity.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 17,
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
      ),
    );
  }
}
