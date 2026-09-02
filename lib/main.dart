import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/focusday_storage.dart';
import 'core/storage/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();

  final storage = FocusDayStorage(preferences);

  runApp(
    ProviderScope(
      overrides: [focusDayStorageProvider.overrideWithValue(storage)],
      child: const FocusDayApp(),
    ),
  );
}
