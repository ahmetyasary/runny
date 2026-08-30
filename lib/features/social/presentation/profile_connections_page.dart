import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/profile.dart';
import '../../../core/theme/app_theme.dart';
import '../data/social_repository.dart';
import 'public_profile_page.dart';

enum ProfileConnectionMode { followers, following }

class ProfileConnectionsPage extends StatefulWidget {
  const ProfileConnectionsPage({
    super.key,
    required this.profileId,
    required this.mode,
    this.title,
  });

  final String profileId;
  final ProfileConnectionMode mode;
  final String? title;

  @override
  State<ProfileConnectionsPage> createState() => _ProfileConnectionsPageState();
}

class _ProfileConnectionsPageState extends State<ProfileConnectionsPage> {
  List<Profile> _people = const [];
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
      final social = SocialRepository(client);
      final people = widget.mode == ProfileConnectionMode.followers
          ? await social.fetchFollowers(widget.profileId)
          : await social.fetchFollowing(widget.profileId);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Liste yüklenemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        (widget.mode == ProfileConnectionMode.followers ? 'Takipçi' : 'Takip');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                  ),
                )
              : _people.isEmpty
                  ? Center(
                      child: Text(
                        widget.mode == ProfileConnectionMode.followers
                            ? 'Henüz takipçi yok.'
                            : 'Henüz takip edilen yok.',
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        itemCount: _people.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                              backgroundImage: person.avatarUrl != null
                                  ? NetworkImage(person.avatarUrl!)
                                  : null,
                              child: person.avatarUrl == null
                                  ? Text(
                                      person.initials,
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              person.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(person.handle),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PublicProfilePage(profileId: person.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
