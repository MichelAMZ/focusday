import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class FocusWindowManager {
  const FocusWindowManager._();

  static const normalSize = Size(1200, 760);
  static const miniSize = Size(640, 82);

  static Future<void> initialize() async {
    if (!Platform.isWindows) {
      return;
    }

    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: normalSize,
      minimumSize: Size(900, 600),
      center: true,
      title: 'FocusDay',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> enterMiniMode() async {
    if (!Platform.isWindows) {
      return;
    }

    await windowManager.setMinimumSize(miniSize);
    await windowManager.setMaximumSize(miniSize);
    await windowManager.setSize(miniSize);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(false);

    // Placement provisoire.
    // La phase suivante utilisera la zone de travail réelle Windows.
    await windowManager.setPosition(Offset(20, 20));

    await windowManager.focus();
  }

  static Future<void> restoreNormalMode() async {
    if (!Platform.isWindows) {
      return;
    }

    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMaximumSize(const Size(10000, 10000));
    await windowManager.setMinimumSize(const Size(900, 600));
    await windowManager.setSize(normalSize);
    await windowManager.center();
    await windowManager.focus();
  }

  static Future<void> closeApp() async {
    if (!Platform.isWindows) {
      return;
    }

    await windowManager.destroy();
  }
}
