import 'package:flutter/material.dart';

import 'features/today/presentation/today_page.dart';

class FocusDayApp extends StatelessWidget {
  const FocusDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusDay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const TodayPage(),
    );
  }
}
