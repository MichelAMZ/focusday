import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/platform_support.dart';

class FocusWindowManager {
  const FocusWindowManager._();

  static const normalSize = Size(1200, 760);
  static const double miniHeight = 82;
  static const double miniPreferredWidth = 640;
  static const double miniHorizontalMargin = 20;
  static const double miniMinimumWidth = 420;

  static Size _miniSizeForVisibleArea(Size visibleSize) {
    final availableWidth = (visibleSize.width - (miniHorizontalMargin * 2))
        .clamp(miniMinimumWidth, miniPreferredWidth);

    return Size(availableWidth.toDouble(), miniHeight);
  }

  static Future<void> initialize() async {
    if (!isWindowsDesktop()) {
      return;
    }

    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: normalSize,
      minimumSize: Size(720, 520),
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
    if (!isWindowsDesktop()) {
      return;
    }

    final display = await screenRetriever.getPrimaryDisplay();

    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;

    // First move the window safely onto the primary display so Windows can
    // update the Flutter window DPI before the final mini-bar positioning.
    await windowManager.setPosition(
      Offset(visiblePosition.dx + 20, visiblePosition.dy + 20),
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final miniSize = _miniSizeForVisibleArea(visibleSize);

    await windowManager.setMinimumSize(miniSize);
    await windowManager.setMaximumSize(miniSize);
    await windowManager.setSize(miniSize);

    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(false);

    final position = Offset(
      visiblePosition.dx +
          visibleSize.width -
          miniSize.width -
          miniHorizontalMargin,
      visiblePosition.dy + visibleSize.height - miniSize.height,
    );

    await windowManager.setPosition(position);

    await windowManager.focus();
  }

  static Future<void> restoreNormalMode() async {
    if (!isWindowsDesktop()) {
      return;
    }

    await windowManager.setAlwaysOnTop(false);
    await windowManager.setMaximumSize(const Size(10000, 10000));
    await windowManager.setMinimumSize(const Size(720, 520));
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
    if (!isWindowsDesktop()) {
      return;
    }

    await windowManager.destroy();
  }
}
