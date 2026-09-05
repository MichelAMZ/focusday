import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/startup/windows_startup_service.dart';

final startupEnabledProvider = AsyncNotifierProvider<StartupController, bool>(
  StartupController.new,
);

class StartupController extends AsyncNotifier<bool> {
  final WindowsStartupService _startupService = const WindowsStartupService();

  @override
  Future<bool> build() {
    return _startupService.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    final previousValue = state.value ?? false;

    state = AsyncData(enabled);

    try {
      await _startupService.setEnabled(enabled);
      final actualValue = await _startupService.isEnabled();
      state = AsyncData(actualValue);
    } catch (error, stackTrace) {
      state = AsyncData(previousValue);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
