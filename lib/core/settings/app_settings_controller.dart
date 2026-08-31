import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { system, turkish, english }

extension AppLanguageX on AppLanguage {
  String get storageValue => name;

  static AppLanguage fromStorage(String? raw) {
    return AppLanguage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppLanguage.system,
    );
  }

  Locale? get localeOverride => switch (this) {
        AppLanguage.system => null,
        AppLanguage.turkish => const Locale('tr'),
        AppLanguage.english => const Locale('en'),
      };
}

enum AppThemePreference { system, light, dark }

extension AppThemePreferenceX on AppThemePreference {
  String get storageValue => name;

  static AppThemePreference fromStorage(String? raw) {
    return AppThemePreference.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppThemePreference.system,
    );
  }

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();

  static const _themeKey = 'app_theme_preference';
  static const _languageKey = 'app_language';

  SharedPreferences? _prefs;
  AppThemePreference themePreference = AppThemePreference.system;
  AppLanguage language = AppLanguage.system;
  bool ready = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themePreference =
        AppThemePreferenceX.fromStorage(_prefs?.getString(_themeKey));
    language = AppLanguageX.fromStorage(_prefs?.getString(_languageKey));
    ready = true;
    notifyListeners();
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    if (themePreference == value) return;
    themePreference = value;
    await _prefs?.setString(_themeKey, value.storageValue);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (language == value) return;
    language = value;
    await _prefs?.setString(_languageKey, value.storageValue);
    notifyListeners();
  }

  Locale resolveLocale(Locale? deviceLocale) {
    final override = language.localeOverride;
    if (override != null) return override;
    final code = deviceLocale?.languageCode;
    if (code == 'tr') return const Locale('tr');
    return const Locale('en');
  }
}
