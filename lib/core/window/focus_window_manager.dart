import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
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
      title: 'FocusDay',
    );

    final position = await _centeredPositionOnPrimaryDisplay(normalSize);

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPosition(position);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> enterMiniMode() async {
    if (!Platform.isWindows) {
      return;
    }

    final display = await screenRetriever.getPrimaryDisplay();

    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;

    // First move the window safely onto the primary display so Windows can
    // update the Flutter window DPI before the final mini-bar positioning.
    await windowManager.setPosition(
      Offset(
        visiblePosition.dx + 20,
        visiblePosition.dy + 20,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));

    await windowManager.setMinimumSize(miniSize);
    await windowManager.setMaximumSize(miniSize);
    await windowManager.setSize(miniSize);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(false);

    final position = Offset(
      visiblePosition.dx + visibleSize.width - miniSize.width - 20,
      visiblePosition.dy + visibleSize.height - miniSize.height,
    );

    await windowManager.setPosition(position);

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

    final position = await _centeredPositionOnPrimaryDisplay(normalSize);
    await windowManager.setPosition(position);

    await windowManager.focus();
  }

  static Future<Offset> _centeredPositionOnPrimaryDisplay(
    Size windowSize,
  ) async {
    final display = await screenRetriever.getPrimaryDisplay();

    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;

    return Offset(
      visiblePosition.dx + (visibleSize.width - windowSize.width) / 2,
      visiblePosition.dy + (visibleSize.height - windowSize.height) / 2,
    );
  }

  static Future<void> closeApp() async {
    if (!Platform.isWindows) {
      return;
    }

    await windowManager.destroy();
  }
}
