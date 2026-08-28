import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/profile_options.dart';
import '../../../core/models/sport_goal.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final Profile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _professionController;
  late final TextEditingController _ageController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  late Set<String> _sports;
  late Set<String> _equipment;
  final Map<String, TextEditingController> _goalControllers = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nicknameController = TextEditingController(text: profile.nickname);
    _displayNameController = TextEditingController(text: profile.displayName ?? '');
    _professionController = TextEditingController(text: profile.profession ?? '');
    _ageController = TextEditingController(
      text: profile.age?.toString() ?? '',
    );
    _locationController = TextEditingController(text: profile.location ?? '');
    _bioController = TextEditingController(text: profile.bio ?? '');
    _sports = {...profile.sports};
    _equipment = {...profile.equipment};
    for (final id in _sports) {
      _ensureGoalController(id, profile.sportGoals[id]);
    }
  }

  void _ensureGoalController(String sportId, [SportGoal? goal]) {
    if (_goalControllers.containsKey(sportId)) return;
    final sport = sportById(sportId);
    final text = sport == null || sport.usesDistance
        ? (goal?.weeklyKm?.toString() ?? '')
        : (goal?.weeklyCount?.toString() ?? '');
    _goalControllers[sportId] = TextEditingController(text: text);
  }

  void _disposeUnusedGoalControllers() {
    final removable = _goalControllers.keys
        .where((id) => !_sports.contains(id))
        .toList();
    for (final id in removable) {
      _goalControllers.remove(id)?.dispose();
    }
  }

  Map<String, SportGoal> _collectGoals() {
    final goals = <String, SportGoal>{};
    for (final id in _sports) {
      final sport = sportById(id);
      final raw = _goalControllers[id]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      if (sport == null || sport.usesDistance) {
        final km = double.tryParse(raw.replaceAll(',', '.'));
        if (km != null && km > 0) {
          goals[id] = SportGoal(weeklyKm: km);
        }
      } else {
        final count = int.tryParse(raw);
        if (count != null && count > 0) {
          goals[id] = SportGoal(weeklyCount: count);
        }
      }
    }
    return goals;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _displayNameController.dispose();
    _professionController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    for (final controller in _goalControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedSports = profileSportOptions
        .where((sport) => _sports.contains(sport.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili düzenle'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Label('Kimlik'),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              prefixText: '@',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(labelText: 'İsim'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _professionController,
            decoration: const InputDecoration(labelText: 'Meslek'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Yaş'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Konum'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          const _Label('Yaptığım sporlar'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sport in profileSportOptions)
                FilterChip(
                  selected: _sports.contains(sport.id),
                  avatar: Icon(sport.icon, size: 16),
                  label: Text(sport.label),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _sports.add(sport.id);
                        _ensureGoalController(sport.id);
                      } else {
                        _sports.remove(sport.id);
                        _disposeUnusedGoalControllers();
                      }
                    });
                  },
                ),
            ],
          ),
          if (selectedSports.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _Label('Haftalık hedefler'),
            const SizedBox(height: 6),
            const Text(
              'Seçtiğin sporlar için bu haftanın hedefini yaz.',
              style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final sport in selectedSports) ...[
              TextField(
                controller: _goalControllers[sport.id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: sport.usesDistance
                      ? '${sport.label} — haftalık km'
                      : '${sport.label} — haftalık seans',
                  prefixIcon: Icon(sport.icon, color: sport.color),
                  suffixText: sport.usesDistance ? 'km' : 'seans',
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 14),
          const _Label('Ekipmanlarım'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in profileEquipmentOptions)
                FilterChip(
                  selected: _equipment.contains(item.id),
                  avatar: Icon(item.icon, size: 16),
                  label: Text(item.label),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _equipment.add(item.id);
                      } else {
                        _equipment.remove(item.id);
                      }
                    });
                  },
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text('Değişiklikleri kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final goals = _collectGoals();
    final client = SupabaseService.client;
    if (client == null) {
      final age = int.tryParse(_ageController.text.trim());
      Navigator.pop(
        context,
        widget.profile.copyWith(
          nickname: _nicknameController.text.trim().toLowerCase(),
          displayName: _displayNameController.text,
          profession: _professionController.text,
          age: age,
          location: _locationController.text,
          bio: _bioController.text,
          sports: _sports.toList(),
          equipment: _equipment.toList(),
          sportGoals: goals,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ageText = _ageController.text.trim();
      final age = ageText.isEmpty ? null : int.tryParse(ageText);
      if (ageText.isNotEmpty && (age == null || age < 10 || age > 100)) {
        throw ArgumentError('Yaş 10–100 arasında olmalı.');
      }

      final updated = await ProfileRepository(client).updateProfile(
        nickname: _nicknameController.text,
        displayName: _displayNameController.text,
        bio: _bioController.text,
        profession: _professionController.text,
        age: age,
        location: _locationController.text,
        sports: _sports.toList(),
        equipment: _equipment.toList(),
        sportGoals: goals,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on PostgrestException catch (error) {
      setState(() {
        _error = error.code == '23505'
            ? 'Bu nickname kullanılıyor. Başka bir tane dene.'
            : error.message;
      });
    } on ArgumentError catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
