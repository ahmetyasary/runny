import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/profile_options.dart';
import '../../../core/theme/app_theme.dart';
import '../data/club_repository.dart';
import '../models/club_models.dart';
import 'club_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => GroupsPageState();
}

class GroupsPageState extends State<GroupsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<ClubEvent> _events = const [];
  List<Club> _clubs = const [];
  bool _loadingEvents = true;
  bool _loadingClubs = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> refresh({bool silent = false}) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _events = const [];
        _clubs = const [];
        _loadingEvents = false;
        _loadingClubs = false;
        _error = null;
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loadingEvents = true;
        _loadingClubs = true;
        _error = null;
      });
    }

    final repo = ClubRepository(client);
    try {
      final events = await repo.fetchUpcomingEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loadingEvents = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        _error = _friendlyError(e, fallback: 'Etkinlikler yüklenemedi.');
      });
    }

    try {
      final clubs = await repo.fetchClubs();
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _loadingClubs = false;
        if (_error == null) _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClubs = false;
        _error ??= _friendlyError(e, fallback: 'Kulüpler yüklenemedi.');
      });
    }
  }

  String _friendlyError(Object e, {required String fallback}) {
    final raw = e.toString();
    if (raw.contains('permission denied') || raw.contains('42501')) {
      return 'Veritabanı izni yok. Supabase’de 010_clubs_grants.sql çalıştır.';
    }
    if (raw.contains('Could not find the table') ||
        raw.contains('PGRST205') ||
        raw.contains('does not exist')) {
      return 'Kulüp tabloları yok. Önce 008_clubs_events.sql çalıştır.';
    }
    if (raw.contains('JWT') || raw.contains('not authenticated')) {
      return 'Giriş gerekli.';
    }
    // PostgrestException mesajını kısaca göster
    final match = RegExp(r'message:\s*(.+)').firstMatch(raw);
    if (match != null) return '$fallback ${match.group(1)}';
    return fallback;
  }

  Future<void> _createClub() async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      _toast('Kulüp oluşturmak için giriş yap.');
      return;
    }

    final result = await showModalBottomSheet<_CreateClubResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const _CreateClubSheet(),
    );
    if (result == null || !mounted) return;

    try {
      final club = await ClubRepository(client).createClub(
        name: result.name,
        description: result.description,
        sport: result.sport,
        city: result.city,
      );
      if (!mounted) return;
      setState(() {
        _clubs = [club, ..._clubs.where((c) => c.id != club.id)];
      });
      _tabs.animateTo(1);
      _toast('Kulüp oluşturuldu.');
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClubDetailPage(clubId: club.id)),
      );
      await refresh(silent: true);
    } catch (e) {
      _toast('Kulüp oluşturulamadı.');
    }
  }

  Future<void> _toggleEventJoin(ClubEvent event) async {
    final client = SupabaseService.client;
    if (client == null) return;
    final repo = ClubRepository(client);
    try {
      if (event.isJoined) {
        await repo.leaveEvent(event.id);
      } else {
        await repo.joinEvent(event.id);
      }
      await refresh(silent: true);
    } catch (_) {
      _toast('İşlem başarısız.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gruplar',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Toplu etkinlikler ve kulüpler.',
                      style: TextStyle(color: AppColors.mutedInk, fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                onPressed: _createClub,
                tooltip: 'Kulüp oluştur',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.mutedInk,
          indicatorColor: AppColors.primaryDark,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'Toplu Aktiviteler'),
            Tab(text: 'Kulüpler'),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFE15B64), fontSize: 13),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _EventsTab(
                loading: _loadingEvents,
                events: _events,
                onRefresh: refresh,
                onToggleJoin: _toggleEventJoin,
                onOpenClub: (clubId) async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClubDetailPage(clubId: clubId),
                    ),
                  );
                  await refresh(silent: true);
                },
              ),
              _ClubsTab(
                loading: _loadingClubs,
                clubs: _clubs,
                onRefresh: refresh,
                onCreate: _createClub,
                onOpen: (club) async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClubDetailPage(clubId: club.id),
                    ),
                  );
                  await refresh(silent: true);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.loading,
    required this.events,
    required this.onRefresh,
    required this.onToggleJoin,
    required this.onOpenClub,
  });

  final bool loading;
  final List<ClubEvent> events;
  final Future<void> Function({bool silent}) onRefresh;
  final Future<void> Function(ClubEvent event) onToggleJoin;
  final Future<void> Function(String clubId) onOpenClub;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => onRefresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.event_outlined, size: 42, color: AppColors.mutedInk),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Yaklaşan toplu aktivite yok.\nKulüplerden etkinlik oluştur veya katıl.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedInk, height: 1.45),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return _EventCard(
            event: event,
            onJoin: () => onToggleJoin(event),
            onOpenClub: () => onOpenClub(event.clubId),
          );
        },
      ),
    );
  }
}

class _ClubsTab extends StatelessWidget {
  const _ClubsTab({
    required this.loading,
    required this.clubs,
    required this.onRefresh,
    required this.onCreate,
    required this.onOpen,
  });

  final bool loading;
  final List<Club> clubs;
  final Future<void> Function({bool silent}) onRefresh;
  final VoidCallback onCreate;
  final Future<void> Function(Club club) onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Material(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onCreate,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, color: AppColors.primaryDark),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kendi kulübünü oluştur',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.add_rounded, color: AppColors.primaryDark),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (clubs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(
                'Henüz kulüp yok.\nİlk kulübü sen oluştur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedInk, height: 1.45),
              ),
            )
          else
            ...clubs.map(
              (club) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClubCard(club: club, onTap: () => onOpen(club)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onJoin,
    required this.onOpenClub,
  });

  final ClubEvent event;
  final VoidCallback onJoin;
  final VoidCallback onOpenClub;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpenClub,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.sport,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatWhen(event.startsAt),
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.clubName,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (event.locationName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  event.locationName,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${event.participantCount} katılımcı',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(
                      backgroundColor: event.isJoined
                          ? AppColors.line
                          : AppColors.primaryDark,
                      foregroundColor:
                          event.isJoined ? AppColors.ink : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: Text(event.isJoined ? 'Ayrıl' : 'Katıl'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatWhen(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Bugün $time';
    if (day == today.add(const Duration(days: 1))) return 'Yarın $time';
    return '${at.day}.${at.month}.${at.year} $time';
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({required this.club, required this.onTap});

  final Club club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.softGreen,
                child: Text(
                  club.name.isEmpty ? 'K' : club.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        club.sport,
                        if (club.city.isNotEmpty) club.city,
                        '${club.memberCount} üye',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (club.isMember)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primaryDark, size: 22)
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.mutedInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateClubResult {
  const _CreateClubResult({
    required this.name,
    required this.description,
    required this.sport,
    required this.city,
  });

  final String name;
  final String description;
  final String sport;
  final String city;
}

class _CreateClubSheet extends StatefulWidget {
  const _CreateClubSheet();

  @override
  State<_CreateClubSheet> createState() => _CreateClubSheetState();
}

class _CreateClubSheetState extends State<_CreateClubSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  String _sport = 'Koşu';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Yeni kulüp',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Kulüp adı',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'Şehir',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _sport,
              decoration: const InputDecoration(
                labelText: 'Spor',
                border: OutlineInputBorder(),
              ),
              items: profileSportOptions
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.label,
                      child: Text(s.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _sport = v);
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                  context,
                  _CreateClubResult(
                    name: name,
                    description: _description.text.trim(),
                    sport: _sport,
                    city: _city.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
