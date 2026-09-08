import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import '../platform/platform_support.dart';

class WindowsStartupService {
  const WindowsStartupService();

  Future<void> initialize() async {
    if (!isWindowsDesktop()) {
      return;
    }

    launchAtStartup.setup(
      appName: 'FocusDay',
      appPath: Platform.resolvedExecutable,
    );
  }

  Future<bool> isEnabled() async {
    if (!isWindowsDesktop()) {
      return false;
    }

    return launchAtStartup.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isWindowsDesktop()) {
      return;
    }

    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
