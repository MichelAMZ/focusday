import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/window/window_mode_controller.dart';
import 'features/today/presentation/mini_bar_page.dart';
import 'features/today/presentation/today_page.dart';

class FocusDayApp extends ConsumerWidget {
  const FocusDayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowMode = ref.watch(focusWindowModeProvider);

    return MaterialApp(
      title: 'FocusDay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: windowMode == FocusWindowMode.mini
          ? const MiniBarPage()
          : const TodayPage(),
    );
  }
}
