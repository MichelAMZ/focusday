import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import '../../../core/storage/focusday_storage.dart';
import '../../../core/cloud/account_sync_models.dart';
import '../../../core/cloud/sync_mutation_bus.dart';

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
  Future<void> _persistence = Future.value();
  int _mutationGeneration = 0;

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
    if (state.completionSoundEnabled == enabled) return;
    state = state.copyWith(completionSoundEnabled: enabled);
    await _persistLocalMutation();
  }

  Future<void> setLanguagePreference(AppLanguagePreference preference) async {
    if (state.languagePreference == preference) return;
    state = state.copyWith(languagePreference: preference);

    await _persistLocalMutation();
  }

  Future<void> setScheduledProjectAlertsEnabled(bool enabled) async {
    if (state.scheduledProjectAlertsEnabled == enabled) return;
    state = state.copyWith(scheduledProjectAlertsEnabled: enabled);

    await _persistLocalMutation();
  }

  Future<bool> replaceFromCloud(SyncedSettings value, int expectedRevision) {
    final storage = ref.read(focusDayStorageProvider);
    if (storage == null || storage.loadSettingsRevision() != expectedRevision) {
      return Future.value(false);
    }
    final expectedGeneration = _mutationGeneration;
    final language = switch (value.languagePreference) {
      'fr' => AppLanguagePreference.french,
      'en' => AppLanguagePreference.english,
      _ => AppLanguagePreference.system,
    };
    final downloaded = SettingsState(
      completionSoundEnabled: value.completionSoundEnabled,
      scheduledProjectAlertsEnabled: value.scheduledProjectAlertsEnabled,
      languagePreference: language,
    );
    final operation = _persistence.then((_) async {
      if (_mutationGeneration != expectedGeneration ||
          storage.loadSettingsRevision() != expectedRevision) {
        return false;
      }
      await _saveState(storage, downloaded);
      if (_mutationGeneration != expectedGeneration ||
          storage.loadSettingsRevision() != expectedRevision) {
        await _saveState(storage, state);
        return false;
      }
      state = downloaded;
      return true;
    });
    _persistence = operation.then<void>((_) {});
    return operation;
  }

  Future<void> _persistLocalMutation() {
    final storage = ref.read(focusDayStorageProvider);
    if (storage == null) return Future.value();
    final snapshot = state;
    _mutationGeneration++;
    final operation = _persistence.then((_) async {
      await _saveState(storage, snapshot);
      await storage.incrementSettingsRevision();
      ref.read(syncMutationBusProvider).notify(SyncDomain.settings);
    });
    _persistence = operation;
    return operation;
  }

  Future<void> _saveState(FocusDayStorage storage, SettingsState value) async {
    await storage.saveCompletionSoundEnabled(value.completionSoundEnabled);
    await storage.saveScheduledProjectAlertsEnabled(
      value.scheduledProjectAlertsEnabled,
    );
    await storage.saveLanguagePreference(switch (value.languagePreference) {
      AppLanguagePreference.system => 'system',
      AppLanguagePreference.french => 'fr',
      AppLanguagePreference.english => 'en',
    });
  }
}
