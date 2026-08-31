import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_settings_controller.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);

        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _SectionTitle(l10n.appearanceSection),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _OptionTile(
                    title: l10n.themeLabel,
                    subtitle: l10n.themeLabelFor(settings.themePreference),
                    icon: Icons.brightness_6_outlined,
                    onTap: () => _pickTheme(context, settings, l10n),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(l10n.languageSection),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _OptionTile(
                    title: l10n.languageLabel,
                    subtitle: l10n.languageLabelFor(settings.language),
                    icon: Icons.language_rounded,
                    onTap: () => _pickLanguage(context, settings, l10n),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    AppSettingsController settings,
    AppLocalizations l10n,
  ) async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in AppThemePreference.values)
              ListTile(
                leading: Icon(switch (value) {
                  AppThemePreference.system => Icons.brightness_auto_outlined,
                  AppThemePreference.light => Icons.light_mode_outlined,
                  AppThemePreference.dark => Icons.dark_mode_outlined,
                }),
                title: Text(l10n.themeLabelFor(value)),
                subtitle: value == AppThemePreference.system
                    ? Text(l10n.themeSystemHint)
                    : null,
                trailing: settings.themePreference == value
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) await settings.setThemePreference(selected);
  }

  Future<void> _pickLanguage(
    BuildContext context,
    AppSettingsController settings,
    AppLocalizations l10n,
  ) async {
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in AppLanguage.values)
              ListTile(
                leading: Icon(switch (value) {
                  AppLanguage.system => Icons.phone_iphone_outlined,
                  AppLanguage.turkish => Icons.translate_rounded,
                  AppLanguage.english => Icons.translate_rounded,
                }),
                title: Text(l10n.languageLabelFor(value)),
                subtitle: value == AppLanguage.system
                    ? Text(l10n.languageSystemHint)
                    : null,
                trailing: settings.language == value
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) await settings.setLanguage(selected);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
