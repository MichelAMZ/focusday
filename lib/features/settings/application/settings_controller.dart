import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';

class SettingsState {
  const SettingsState({this.completionSoundEnabled = true});

  final bool completionSoundEnabled;

  SettingsState copyWith({bool? completionSoundEnabled}) {
    return SettingsState(
      completionSoundEnabled:
          completionSoundEnabled ?? this.completionSoundEnabled,
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
    );
  }

  Future<void> setCompletionSoundEnabled(bool enabled) async {
    state = state.copyWith(completionSoundEnabled: enabled);

    final storage = ref.read(focusDayStorageProvider);

    await storage?.saveCompletionSoundEnabled(enabled);
  }
}
