import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/route_preview.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/presentation/activity_detail_page.dart';

class ProfileActivitiesPage extends StatefulWidget {
  const ProfileActivitiesPage({
    super.key,
    required this.profileId,
    this.title = 'Aktiviteler',
    this.isOwnProfile = false,
  });

  final String profileId;
  final String title;
  final bool isOwnProfile;

  @override
  State<ProfileActivitiesPage> createState() => _ProfileActivitiesPageState();
}

class _ProfileActivitiesPageState extends State<ProfileActivitiesPage> {
  List<Activity> _activities = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'Bağlantı yok.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ActivityRepository(client);
      final activities = widget.isOwnProfile
          ? await repo.fetchMine(limit: 50)
          : await repo.fetchByUser(widget.profileId, limit: 50);
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Aktiviteler yüklenemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                )
              : _activities.isEmpty
                  ? const Center(
                      child: Text(
                        'Henüz aktivite yok.',
                        style: TextStyle(color: AppColors.mutedInk),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: _activities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailPage(
                                      activity: activity,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          activity.type.icon,
                                          color: activity.type.color,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            activity.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          activity.when,
                                          style: const TextStyle(
                                            color: AppColors.mutedInk,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    RoutePreview(
                                      height: 100,
                                      showLabel: false,
                                      accentColor: activity.type.color,
                                      routePoints: activity.routePoints,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${activity.distance.toStringAsFixed(2)} km · ${activity.duration}',
                                      style: const TextStyle(
                                        color: AppColors.mutedInk,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
