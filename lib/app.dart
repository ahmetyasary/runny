import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_localizations.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';

class RunnyApp extends StatelessWidget {
  const RunnyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Runny',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themePreference.themeMode,
          locale: settings.language.localeOverride,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (deviceLocale, supported) {
            return settings.resolveLocale(deviceLocale);
          },
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            AppColors.bind(Theme.of(context).brightness);
            return child ?? const SizedBox.shrink();
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
