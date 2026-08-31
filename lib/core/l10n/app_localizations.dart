import 'package:flutter/widgets.dart';

import '../settings/app_settings_controller.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('tr'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('tr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isTr => locale.languageCode == 'tr';

  String get appName => 'Runny';

  String get tabFeed => isTr ? 'Akış' : 'Feed';
  String get tabDiscover => isTr ? 'Keşfet' : 'Discover';
  String get tabGroups => isTr ? 'Gruplar' : 'Groups';
  String get tabProfile => isTr ? 'Profil' : 'Profile';

  String get profileTitle => isTr ? 'Profil' : 'Profile';
  String get editProfile => isTr ? 'Profili düzenle' : 'Edit profile';
  String get appleWatch => 'Apple Watch';
  String get appleWatchSubtitle =>
      isTr ? 'Saat bağlantısı ve durum' : 'Watch connection and status';
  String get signOut => isTr ? 'Çıkış yap' : 'Sign out';
  String get appSettings => isTr ? 'Uygulama ayarları' : 'App settings';
  String get appSettingsSubtitle =>
      isTr ? 'Dil ve görünüm' : 'Language and appearance';

  String get settingsTitle => isTr ? 'Uygulama ayarları' : 'App settings';
  String get appearanceSection => isTr ? 'Görünüm' : 'Appearance';
  String get languageSection => isTr ? 'Dil' : 'Language';
  String get themeLabel => isTr ? 'Tema' : 'Theme';
  String get languageLabel => isTr ? 'Uygulama dili' : 'App language';

  String get themeSystem => isTr ? 'Sistem' : 'System';
  String get themeLight => isTr ? 'Açık' : 'Light';
  String get themeDark => isTr ? 'Koyu' : 'Dark';

  String get languageSystem => isTr ? 'Sistem' : 'System';
  String get languageTurkish => 'Türkçe';
  String get languageEnglish => 'English';

  String get themeSystemHint => isTr
      ? 'Cihazın tema ayarını takip eder'
      : 'Follows your device theme';
  String get languageSystemHint => isTr
      ? 'Cihaz diline göre Türkçe veya İngilizce'
      : 'Turkish or English based on device language';

  String get settingsSaved =>
      isTr ? 'Ayarlar kaydedildi' : 'Settings saved';

  String get startActivity => isTr ? 'Aktivite başlat' : 'Start activity';
  String get startActivityHint => isTr
      ? 'Hareketini kaydet, rotanı arkadaşlarınla paylaş.'
      : 'Track your move and share your route with friends.';

  String get feedReadyPrompt => isTr
      ? 'Bugün hareket etmeye hazır mısın?'
      : 'Ready to move today?';

  String greeting(String firstName) {
    final hour = DateTime.now().hour;
    final hi = isTr
        ? (hour >= 5 && hour < 12
            ? 'Günaydın'
            : hour >= 12 && hour < 18
                ? 'İyi günler'
                : 'İyi akşamlar')
        : (hour >= 5 && hour < 12
            ? 'Good morning'
            : hour >= 12 && hour < 18
                ? 'Good afternoon'
                : 'Good evening');
    return '$hi, $firstName';
  }

  String themeLabelFor(AppThemePreference value) => switch (value) {
        AppThemePreference.system => themeSystem,
        AppThemePreference.light => themeLight,
        AppThemePreference.dark => themeDark,
      };

  String languageLabelFor(AppLanguage value) => switch (value) {
        AppLanguage.system => languageSystem,
        AppLanguage.turkish => languageTurkish,
        AppLanguage.english => languageEnglish,
      };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'tr' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
