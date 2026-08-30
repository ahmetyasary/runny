import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  final _picker = ImagePicker();

  String? _avatarUrl;
  XFile? _localAvatar;
  bool _removeAvatar = false;
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
    _avatarUrl = profile.avatarUrl;
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

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _localAvatar = picked;
        _removeAvatar = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = source == ImageSource.camera
            ? 'Kamera açılamadı. İzinleri kontrol et.'
            : 'Galeri açılamadı. İzinleri kontrol et.';
      });
    }
  }

  void _showPhotoOptions() {
    final hasPhoto = _localAvatar != null ||
        (!_removeAvatar && (_avatarUrl != null && _avatarUrl!.isNotEmpty));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  'Fotoğrafı kaldır',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _localAvatar = null;
                    _removeAvatar = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider? get _avatarImage {
    if (_localAvatar != null) {
      return FileImage(File(_localAvatar!.path));
    }
    if (!_removeAvatar && _avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
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
    final avatarImage = _avatarImage;

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
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isLoading ? null : _showPhotoOptions,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
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
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Text(
                                  widget.profile.initials,
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : _showPhotoOptions,
                  child: const Text('Fotoğraf ekle veya değiştir'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
          avatarUrl: _removeAvatar ? null : _avatarUrl,
          clearAvatarUrl: _removeAvatar,
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

      final repo = ProfileRepository(client);
      String? nextAvatarUrl;
      if (_localAvatar != null) {
        final bytes = await _localAvatar!.readAsBytes();
        final mime = _localAvatar!.mimeType ?? 'image/jpeg';
        nextAvatarUrl = await repo.uploadAvatar(
          bytes: bytes,
          contentType: mime,
        );
      } else if (_removeAvatar) {
        nextAvatarUrl = '';
      }

      final updated = await repo.updateProfile(
        nickname: _nicknameController.text,
        displayName: _displayNameController.text,
        bio: _bioController.text,
        profession: _professionController.text,
        age: age,
        location: _locationController.text,
        sports: _sports.toList(),
        equipment: _equipment.toList(),
        sportGoals: goals,
        avatarUrl: nextAvatarUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on StorageException catch (error) {
      setState(() {
        _error = error.message.isNotEmpty
            ? 'Fotoğraf yüklenemedi: ${error.message}'
            : 'Fotoğraf yüklenemedi. Storage (avatars) bucket’ını kontrol et.';
      });
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
