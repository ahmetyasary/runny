import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/profile_options.dart';
import '../../../core/theme/app_theme.dart';
import '../data/club_repository.dart';
import '../models/club_models.dart';

class ClubDetailPage extends StatefulWidget {
  const ClubDetailPage({super.key, required this.clubId});

  final String clubId;

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> {
  Club? _club;
  List<ClubEvent> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    if (client == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final repo = ClubRepository(client);
    try {
      final club = await repo.fetchClub(widget.clubId);
      final events = await repo.fetchClubEvents(widget.clubId);
      if (!mounted) return;
      setState(() {
        _club = club;
        _events = events;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleMembership() async {
    final client = SupabaseService.client;
    final club = _club;
    if (client == null || club == null) return;
    if (club.isOwner) {
      _toast('Kurucu kulüpten ayrılamaz.');
      return;
    }
    final repo = ClubRepository(client);
    try {
      if (club.isMember) {
        await repo.leaveClub(club.id);
      } else {
        await repo.joinClub(club.id);
      }
      await _load();
    } catch (_) {
      _toast('İşlem başarısız.');
    }
  }

  Future<void> _createEvent() async {
    final client = SupabaseService.client;
    final club = _club;
    if (client == null || club == null) return;
    if (!club.isMember && !club.isOwner) {
      _toast('Etkinlik oluşturmak için önce kulübe katıl.');
      return;
    }

    final result = await showModalBottomSheet<_CreateEventResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _CreateEventSheet(defaultSport: club.sport),
    );
    if (result == null || !mounted) return;

    try {
      await ClubRepository(client).createEvent(
        clubId: club.id,
        title: result.title,
        description: result.description,
        sport: result.sport,
        locationName: result.location,
        startsAt: result.startsAt,
      );
      _toast('Etkinlik oluşturuldu.');
      await _load();
    } catch (_) {
      _toast('Etkinlik oluşturulamadı.');
    }
  }

  Future<void> _toggleEvent(ClubEvent event) async {
    final client = SupabaseService.client;
    if (client == null) return;
    final repo = ClubRepository(client);
    try {
      if (event.isJoined) {
        await repo.leaveEvent(event.id);
      } else {
        await repo.joinEvent(event.id);
      }
      await _load();
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
    final club = _club;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(club?.name ?? 'Kulüp'),
        actions: [
          if (club != null && (club.isMember || club.isOwner))
            IconButton(
              tooltip: 'Etkinlik oluştur',
              onPressed: _createEvent,
              icon: const Icon(Icons.event_available_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : club == null
              ? const Center(child: Text('Kulüp bulunamadı.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF247A40),
                              Color(0xFF49B86A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          club.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        [
                          club.sport,
                          if (club.city.isNotEmpty) club.city,
                          '${club.memberCount} üye',
                          club.isPublic ? 'Herkese açık' : 'Özel',
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (club.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          club.description,
                          style: const TextStyle(
                            color: AppColors.ink,
                            height: 1.45,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: club.isOwner ? null : _toggleMembership,
                              icon: Icon(
                                club.isMember
                                    ? Icons.check_rounded
                                    : Icons.group_add_rounded,
                              ),
                              label: Text(
                                club.isOwner
                                    ? 'Kurucu'
                                    : club.isMember
                                        ? 'Üyesin · Ayrıl'
                                        : 'Katıl',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                disabledBackgroundColor: AppColors.softGreen,
                                disabledForegroundColor: AppColors.primaryDark,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _createEvent,
                            icon: const Icon(Icons.event_rounded),
                            label: const Text('Etkinlik'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Etkinlikler',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_events.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'Henüz etkinlik yok. İlk etkinliği sen oluştur.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mutedInk),
                          ),
                        )
                      else
                        ..._events.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DetailEventTile(
                              event: event,
                              onToggle: () => _toggleEvent(event),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _DetailEventTile extends StatelessWidget {
  const _DetailEventTile({
    required this.event,
    required this.onToggle,
  });

  final ClubEvent event;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final at = event.startsAt;
    final when =
        '${at.day}.${at.month}.${at.year} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      when,
                      event.sport,
                      if (event.locationName.isNotEmpty) event.locationName,
                      '${event.participantCount} kişi',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onToggle,
              child: Text(event.isJoined ? 'Ayrıl' : 'Katıl'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateEventResult {
  const _CreateEventResult({
    required this.title,
    required this.description,
    required this.sport,
    required this.location,
    required this.startsAt,
  });

  final String title;
  final String description;
  final String sport;
  final String location;
  final DateTime startsAt;
}

class _CreateEventSheet extends StatefulWidget {
  const _CreateEventSheet({required this.defaultSport});

  final String defaultSport;

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  late String _sport;
  DateTime _startsAt = DateTime.now().add(const Duration(days: 1)).copyWith(
        hour: 9,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );

  @override
  void initState() {
    super.initState();
    _sport = widget.defaultSport;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final label =
        '${_startsAt.day}.${_startsAt.month}.${_startsAt.year} · '
        '${_startsAt.hour.toString().padLeft(2, '0')}:${_startsAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Yeni etkinlik',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
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
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Konum',
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(label),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final title = _title.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(
                  context,
                  _CreateEventResult(
                    title: title,
                    description: _description.text.trim(),
                    sport: _sport,
                    location: _location.text.trim(),
                    startsAt: _startsAt,
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
