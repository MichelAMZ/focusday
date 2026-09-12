import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../application/ai_provider_settings.dart';

class AiProviderSettingsSection extends ConsumerStatefulWidget {
  const AiProviderSettingsSection({super.key});
  @override
  ConsumerState<AiProviderSettingsSection> createState() =>
      _AiProviderSettingsSectionState();
}

class _AiProviderSettingsSectionState
    extends ConsumerState<AiProviderSettingsSection> {
  bool _failed = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(aiProviderSettingsProvider);
    final controller = ref.read(aiProviderSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.aiProviderTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<AiProviderMode>(
                  key: ValueKey(settings.mode),
                  initialValue: settings.mode == AiProviderMode.personalOpenAi
                      ? AiProviderMode.focusday
                      : settings.mode,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.aiProviderTitle),
                  items: [
                    DropdownMenuItem(
                      value: AiProviderMode.disabled,
                      child: Text(l10n.aiProviderDisabled),
                    ),
                    DropdownMenuItem(
                      value: AiProviderMode.chatgpt,
                      child: Text(l10n.aiProviderChatgpt),
                    ),
                    DropdownMenuItem(
                      value: AiProviderMode.focusday,
                      child: Text(l10n.aiAssistantTitle),
                    ),
                  ],
                  onChanged: (mode) async {
                    if (mode == null) return;
                    setState(() => _failed = false);
                    try {
                      await controller.setMode(mode);
                    } catch (_) {
                      if (mounted) setState(() => _failed = true);
                    }
                  },
                ),
                // FocusDay V2: personal OpenAI API key configuration
                if (_failed) Text(l10n.aiErrorServer),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
