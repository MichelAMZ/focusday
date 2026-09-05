import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Param\u00e8tres')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Focus', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: settings.completionSoundEnabled,
              onChanged: (enabled) {
                ref
                    .read(settingsProvider.notifier)
                    .setCompletionSoundEnabled(enabled);
              },
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Son de fin de focus'),
              subtitle: const Text(
                'Joue un son lorsque le minuteur atteint 00:00.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
