import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/activity.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/profile_options.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/route_preview.dart';
import '../../activities/presentation/activity_history_controller.dart';
import '../data/profile_repository.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  Profile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // InheritedWidget henüz hazır olmayabilir; ilk frame sonrası yükle.
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh({bool silent = false}) async {
    final history = ActivityHistoryScope.maybeOf(context);
    final historyFuture = history?.refresh();

    if (!SupabaseConfig.isConfigured) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _loading = false;
        _error =
            'Supabase bağlı değil.\nUygulamayı şöyle başlat:\nflutter run --dart-define-from-file=.env';
      });
      await historyFuture;
      return;
    }

    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _loading = false;
        _error = 'Profil için giriş yapmalısın.';
      });
      await historyFuture;
      return;
    }

    if (!silent || _profile == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final profile = await ProfileRepository(client).fetchCurrent();
      await historyFuture;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _error = profile == null
            ? 'Profil kaydı bulunamadı. Çıkış yapıp tekrar giriş dene.'
            : null;
      });
    } catch (_) {
      await historyFuture;
      if (!mounted) return;
      setState(() {
        _error = 'Profil yüklenemedi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ActivityHistoryScope.maybeOf(context);
    final profile = _profile;

    if (_loading && profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Profil bulunamadı',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedInk,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: refresh, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text(
                    'Profil',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openEdit(profile),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: _showSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: AnimatedBuilder(
                animation: history ?? const _IdleListenable(),
                builder: (context, _) {
                  final liveCount = history?.count ?? profile.activityCount;
                  return _Header(
                    profile: profile.copyWith(activityCount: liveCount),
                  );
                },
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: _SectionTitle(
                title: 'Yaptığım sporlar',
                actionLabel: 'Düzenle',
                onAction: () => _openEdit(profile),
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ChipWrap(
                emptyText: 'Henüz spor seçilmedi — düzenle’den ekle',
                children: [
                  for (final id in profile.sports)
                    if (sportById(id) != null)
                      _InfoChip(
                        icon: sportById(id)!.icon,
                        label: sportById(id)!.label,
                      ),
                ],
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: _SectionTitle(
                title: 'Ekipmanlarım',
                actionLabel: 'Düzenle',
                onAction: () => _openEdit(profile),
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ChipWrap(
                emptyText: 'Henüz ekipman eklenmedi — düzenle’den ekle',
                children: [
                  for (final id in profile.equipment)
                    if (equipmentById(id) != null)
                      _InfoChip(
                        icon: equipmentById(id)!.icon,
                        label: equipmentById(id)!.label,
                        soft: true,
                      ),
                ],
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: AnimatedBuilder(
                animation: history ?? const _IdleListenable(),
                builder: (context, _) {
                  final count = history?.count ?? profile.activityCount;
                  return _SectionTitle(
                    title: 'Aktivite geçmişi',
                    actionLabel: '$count',
                  );
                },
              ),
            ),
          ),
          SoftWrapToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: history == null
                  ? const _EmptyHistory()
                  : AnimatedBuilder(
                      animation: history,
                      builder: (context, _) {
                        final items = history.activities;
                        if (items.isEmpty) return const _EmptyHistory();
                        return Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _HistoryCard(activity: items[i]),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(Profile profile) async {
    final updated = await Navigator.push<Profile>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: profile)),
    );
    if (updated != null) await refresh();
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Profili düzenle'),
              onTap: () {
                Navigator.pop(context);
                if (_profile != null) _openEdit(_profile!);
              },
            ),
            if (SupabaseService.client != null)
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text(
                  'Çıkış yap',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await ProfileRepository(SupabaseService.client!).signOut();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _IdleListenable extends Listenable {
  const _IdleListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Convenience for wrapping a non-sliver widget as SliverToBoxAdapter.
class SoftWrapToBoxAdapter extends StatelessWidget {
  const SoftWrapToBoxAdapter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (profile.profession != null && profile.profession!.isNotEmpty)
        profile.profession!,
      if (profile.age != null) '${profile.age} yaş',
      if (profile.location != null && profile.location!.isNotEmpty)
        profile.location!,
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: .35),
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.softGreen,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.initials,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          profile.name,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profile.handle,
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final item in meta)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Count(value: '${profile.activityCount}', label: 'Aktivite'),
            _Count(value: '${profile.followerCount}', label: 'Takipçi'),
            _Count(value: '${profile.followingCount}', label: 'Takip'),
          ],
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null)
          onAction == null
              ? Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children, required this.emptyText});

  final List<Widget> children;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          emptyText,
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.soft = false,
  });

  final IconData icon;
  final String label;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: soft ? AppColors.lavender : AppColors.softGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: soft ? const Color(0xFF6D62C5) : AppColors.primaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: soft ? const Color(0xFF6D62C5) : AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.route_rounded, color: AppColors.mutedInk, size: 32),
          SizedBox(height: 10),
          Text(
            'Henüz aktivite yok',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'İlk kaydını oluşturunca burada görünecek.',
            style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final calories = activity.calories > 0 ? '${activity.calories}' : '--';
    final showLocation =
        activity.location.isNotEmpty && activity.location != 'Konum yok';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(activity.type.icon, color: activity.type.color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  activity.when,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RoutePreview(
              height: 110,
              showLabel: showLocation,
              locationLabel: showLocation ? activity.location : null,
              accentColor: activity.type.color,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(icon: Icons.timer_outlined, value: activity.duration),
                _Metric(
                  icon: Icons.straighten_rounded,
                  value: '${activity.distance.toStringAsFixed(2)} km',
                ),
                _Metric(
                  icon: Icons.local_fire_department_outlined,
                  value: '$calories kcal',
                ),
              ],
            ),
            if (showLocation) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppColors.mutedInk,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.location,
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.mutedInk),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
