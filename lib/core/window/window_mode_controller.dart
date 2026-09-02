import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focus_window_manager.dart';

enum FocusWindowMode { normal, mini }

final focusWindowModeProvider =
    NotifierProvider<FocusWindowModeController, FocusWindowMode>(
      FocusWindowModeController.new,
    );

class FocusWindowModeController extends Notifier<FocusWindowMode> {
  @override
  FocusWindowMode build() {
    return FocusWindowMode.normal;
  }

  Future<void> enterMiniMode() async {
    await FocusWindowManager.enterMiniMode();
    state = FocusWindowMode.mini;
  }

  Future<void> restoreNormalMode() async {
    await FocusWindowManager.restoreNormalMode();
    state = FocusWindowMode.normal;
  }

  Future<void> closeApp() async {
    await FocusWindowManager.closeApp();
  }
}
