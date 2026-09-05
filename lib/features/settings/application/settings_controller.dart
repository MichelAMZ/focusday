import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';

enum AppLanguagePreference { system, french, english }

class SettingsState {
  const SettingsState({
    this.completionSoundEnabled = true,
    this.scheduledProjectAlertsEnabled = true,
    this.languagePreference = AppLanguagePreference.system,
  });

  final bool completionSoundEnabled;
  final bool scheduledProjectAlertsEnabled;
  final AppLanguagePreference languagePreference;

  SettingsState copyWith({
    bool? completionSoundEnabled,
    bool? scheduledProjectAlertsEnabled,
    AppLanguagePreference? languagePreference,
  }) {
    return SettingsState(
      completionSoundEnabled:
          completionSoundEnabled ?? this.completionSoundEnabled,
      scheduledProjectAlertsEnabled:
          scheduledProjectAlertsEnabled ?? this.scheduledProjectAlertsEnabled,
      languagePreference: languagePreference ?? this.languagePreference,
    );
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final storage = ref.watch(focusDayStorageProvider);

    return SettingsState(
      completionSoundEnabled: storage?.loadCompletionSoundEnabled() ?? true,
      scheduledProjectAlertsEnabled:
          storage?.loadScheduledProjectAlertsEnabled() ?? true,
      languagePreference: switch (storage?.loadLanguagePreference()) {
        'fr' => AppLanguagePreference.french,
        'en' => AppLanguagePreference.english,
        _ => AppLanguagePreference.system,
      },
    );
  }

  Future<void> setCompletionSoundEnabled(bool enabled) async {
    state = state.copyWith(completionSoundEnabled: enabled);

    final storage = ref.read(focusDayStorageProvider);

    await storage?.saveCompletionSoundEnabled(enabled);
  }

  Future<void> setLanguagePreference(AppLanguagePreference preference) async {
    state = state.copyWith(languagePreference: preference);

    final storage = ref.read(focusDayStorageProvider);

    final storedPreference = switch (preference) {
      AppLanguagePreference.system => 'system',
      AppLanguagePreference.french => 'fr',
      AppLanguagePreference.english => 'en',
    };

    await storage?.saveLanguagePreference(storedPreference);
  }

  Future<void> setScheduledProjectAlertsEnabled(bool enabled) async {
    state = state.copyWith(scheduledProjectAlertsEnabled: enabled);

    final storage = ref.read(focusDayStorageProvider);

    await storage?.saveScheduledProjectAlertsEnabled(enabled);
  }
}
