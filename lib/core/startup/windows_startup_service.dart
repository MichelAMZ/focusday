import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

class WindowsStartupService {
  const WindowsStartupService();

  Future<void> initialize() async {
    if (!Platform.isWindows) {
      return;
    }

    launchAtStartup.setup(
      appName: 'FocusDay',
      appPath: Platform.resolvedExecutable,
    );
  }

  Future<bool> isEnabled() async {
    if (!Platform.isWindows) {
      return false;
    }

    return launchAtStartup.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }

    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }
}
