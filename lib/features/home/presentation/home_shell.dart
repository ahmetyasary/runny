import 'package:flutter/material.dart';

import '../../../core/models/profile_options.dart';
import '../../../core/theme/app_theme.dart';
import '../../activities/presentation/activity_history_controller.dart';
import '../../activities/presentation/activity_page.dart';
import '../../activities/presentation/activity_recorder_page.dart';
import '../../activities/presentation/activity_session_controller.dart';
import '../../activities/presentation/floating_activity_bubble.dart';
import '../../discover/presentation/discover_page.dart';
import '../../feed/presentation/feed_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../watch/presentation/watch_session_sync.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final _session = ActivitySessionController();
  final _history = ActivityHistoryController();
  final _feedKey = GlobalKey<FeedPageState>();
  final _discoverKey = GlobalKey<DiscoverPageState>();
  final _profileKey = GlobalKey<ProfilePageState>();
  late final WatchSessionSync _watchSync;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _watchSync = WatchSessionSync(_session);
    _watchSync.start();
    _history.refresh();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _watchSync.dispose();
    _session.dispose();
    _history.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _refreshTab(int index) {
    switch (index) {
      case 0:
        _feedKey.currentState?.refresh(silent: true);
      case 1:
        _discoverKey.currentState?.refresh(silent: true);
      case 2:
        _history.refresh();
      case 3:
        _profileKey.currentState?.refresh(silent: true);
    }
  }

  Future<void> _completeActivity(ActivityStopResult result) async {
    await _watchSync.notifyStopped();
    _history.addCompleted(
      id: result.localId,
      typeLabel: result.typeLabel,
      title: result.title,
      distanceMeters: result.distanceMeters,
      duration: result.duration,
      calories: result.calories,
      elevationGainMeters: result.elevationGainMeters,
      avgHeartRate: result.avgHeartRateBpm,
      maxHeartRate: result.maxHeartRateBpm,
      routePoints: result.routePoints,
    );
    // Uzak listeyi de senkronla (buluta yazıldıysa).
    await _history.refresh();
    // Diğer sekmeler de güncel kalsın.
    _feedKey.currentState?.refresh(silent: true);
    _discoverKey.currentState?.refresh(silent: true);
    _profileKey.currentState?.refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final showFab = !_session.isRecording || !_session.isMinimized;

    return ActivityHistoryScope(
      controller: _history,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  FeedPage(key: _feedKey),
                  DiscoverPage(key: _discoverKey),
                  const ActivityPage(),
                  ProfilePage(key: _profileKey),
                ],
              ),
            ),
            FloatingActivityBubble(
              session: _session,
              onCompleted: _completeActivity,
            ),
          ],
        ),
        floatingActionButton: showFab
            ? FloatingActionButton(
                onPressed: () {
                  if (_session.isRecording && !_session.isMinimized) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityRecorderPage(
                          activityType: _session.activityType ?? 'Aktivite',
                          session: _session,
                          onCompleted: _completeActivity,
                        ),
                      ),
                    );
                    return;
                  }
                  _showStartActivitySheet(context);
                },
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: Icon(
                  _session.isRecording
                      ? Icons.graphic_eq_rounded
                      : Icons.add_rounded,
                  size: 30,
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            _refreshTab(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Akış',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Keşfet',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Aktiviteler',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  void _showStartActivitySheet(BuildContext context) {
    if (_session.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devam eden bir aktivite var. Önce onu bitir.'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aktivite başlat',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hareketini kaydet, rotanı arkadaşlarınla paylaş.',
                style: TextStyle(color: AppColors.mutedInk, fontSize: 13),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profileSportOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final sport = profileSportOptions[index];
                  return _ActivityOption(
                    icon: sport.icon,
                    label: sport.label,
                    color: sport.color,
                    onTap: () => _openRecorder(context, sport.label),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRecorder(BuildContext context, String type) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityRecorderPage(
          activityType: type,
          session: _session,
          onCompleted: _completeActivity,
        ),
      ),
    ).then((_) {
      if (_session.isRecording) {
        _watchSync.notifyStarted();
      }
    });
  }
}

class _ActivityOption extends StatelessWidget {
  const _ActivityOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
