import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';

class SettingsState {
  const SettingsState({
    this.completionSoundEnabled = true,
    this.scheduledProjectAlertsEnabled = true,
  });

  final bool completionSoundEnabled;
  final bool scheduledProjectAlertsEnabled;

  SettingsState copyWith({
    bool? completionSoundEnabled,
    bool? scheduledProjectAlertsEnabled,
  }) {
    return SettingsState(
      completionSoundEnabled:
          completionSoundEnabled ?? this.completionSoundEnabled,
      scheduledProjectAlertsEnabled:
          scheduledProjectAlertsEnabled ?? this.scheduledProjectAlertsEnabled,
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
    );
  }

  Future<void> setCompletionSoundEnabled(bool enabled) async {
    state = state.copyWith(completionSoundEnabled: enabled);

    final storage = ref.read(focusDayStorageProvider);

    await storage?.saveCompletionSoundEnabled(enabled);
  }

  Future<void> setScheduledProjectAlertsEnabled(bool enabled) async {
    state = state.copyWith(scheduledProjectAlertsEnabled: enabled);

    final storage = ref.read(focusDayStorageProvider);

    await storage?.saveScheduledProjectAlertsEnabled(enabled);
  }
}
