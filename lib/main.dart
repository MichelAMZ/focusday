import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/startup/windows_startup_service.dart';
import 'core/storage/focusday_storage.dart';
import 'core/storage/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const startupService = WindowsStartupService();
  await startupService.initialize();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 760),
      minimumSize: Size(900, 600),
      center: true,
      title: 'FocusDay',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final preferences = await SharedPreferences.getInstance();

  final storage = FocusDayStorage(preferences);

  runApp(
    ProviderScope(
      overrides: [focusDayStorageProvider.overrideWithValue(storage)],
      child: const FocusDayApp(),
    ),
  );
}
