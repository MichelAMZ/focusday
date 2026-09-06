import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/account_page.dart';
import '../application/settings_controller.dart';
import '../application/startup_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final startupState = ref.watch(startupEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.languageSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: DropdownButtonFormField<AppLanguagePreference>(
                initialValue: settings.languagePreference,
                decoration: InputDecoration(
                  labelText: l10n.languagePreferenceTitle,
                  prefixIcon: const Icon(Icons.language_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: AppLanguagePreference.system,
                    child: Text(l10n.languageAutomatic),
                  ),
                  DropdownMenuItem(
                    value: AppLanguagePreference.french,
                    child: Text(l10n.languageFrench),
                  ),
                  DropdownMenuItem(
                    value: AppLanguagePreference.english,
                    child: Text(l10n.languageEnglish),
                  ),
                ],
                onChanged: (preference) {
                  if (preference == null) {
                    return;
                  }

                  ref
                      .read(settingsProvider.notifier)
                      .setLanguagePreference(preference);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.focusSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.completionSoundEnabled,
                  onChanged: (enabled) {
                    ref
                        .read(settingsProvider.notifier)
                        .setCompletionSoundEnabled(enabled);
                  },
                  secondary: const Icon(Icons.music_note_outlined),
                  title: Text(l10n.completionSoundTitle),
                  subtitle: Text(l10n.completionSoundSubtitle),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: settings.scheduledProjectAlertsEnabled,
                  onChanged: (enabled) {
                    ref
                        .read(settingsProvider.notifier)
                        .setScheduledProjectAlertsEnabled(enabled);
                  },
                  secondary: const Icon(Icons.alarm_outlined),
                  title: Text(l10n.scheduledAlertsTitle),
                  subtitle: Text(l10n.scheduledAlertsSubtitle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Compte & Cloud',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Compte & Cloud'),
              subtitle: const Text(
                'Connexion et sauvegarde de vos données FocusDay.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AccountPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.windowsStartupSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: startupState.value ?? false,
              onChanged: startupState.isLoading
                  ? null
                  : (enabled) async {
                      await ref
                          .read(startupEnabledProvider.notifier)
                          .setEnabled(enabled);
                    },
              secondary: const Icon(Icons.power_settings_new_outlined),
              title: Text(l10n.windowsStartupTitle),
              subtitle: Text(l10n.windowsStartupSubtitle),
            ),
          ),
        ],
      ),
    );
  }
}
