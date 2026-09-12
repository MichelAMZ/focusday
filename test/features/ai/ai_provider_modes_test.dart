import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/core/storage/storage_provider.dart';
import 'package:focusday/features/ai/application/ai_assistant_controller.dart';
import 'package:focusday/features/ai/application/ai_assistant_gateway.dart';
import 'package:focusday/features/ai/application/ai_assistant_context_builder.dart';
import 'package:focusday/features/ai/application/ai_provider_settings.dart';
import 'package:focusday/features/ai/application/chatgpt_export.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/presentation/ai_assistant_panel.dart';
import 'package:focusday/features/ai/presentation/ai_provider_settings_section.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/l10n/app_localizations.dart';

final ownerProvider = NotifierProvider<_Owner, String?>(_Owner.new);

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';
  void change(String? value) => state = value;
}

class _Gateway implements AiAssistantGateway {
  int calls = 0;
  Completer<AiResponse>? pending;
  @override
  Future<AiResponse> respond(AiRequest request) async {
    calls++;
    return pending?.future ??
        const AiResponse(
          text: 'Advice',
          proposedActions: [
            AiProposedAction(
              type: AiProposedActionType.addTask,
              title: 'Proposal',
            ),
          ],
        );
  }
}

void main() {
  const project = FocusProject(
    id: 'private-project',
    name: 'Active',
    durationMinutes: 25,
    status: FocusProjectStatus.active,
    notes: 'Notes',
    tasks: [
      FocusTask(id: 'private-task', title: 'Draft'),
      FocusTask(id: 'private-done', title: 'Done', isCompleted: true),
    ],
  );
  const timer = FocusTimerState(
    projectId: 'private-project',
    initialSeconds: 1500,
    remainingSeconds: 720,
  );
  const other = FocusProject(
    id: 'private-other',
    name: 'Hidden project',
    durationMinutes: 10,
    tasks: [],
  );
  final context = const AiAssistantContextBuilder().build(
    language: 'fr',
    projects: [project, other],
    timer: timer,
  );
  ProviderContainer container(_Gateway gateway, {FocusDayStorage? storage}) {
    final value = ProviderContainer(
      overrides: [
        aiAssistantGatewayProvider.overrideWithValue(gateway),
        focusDayStorageProvider.overrideWithValue(storage),
        aiSessionOwnerProvider.overrideWith((ref) => ref.watch(ownerProvider)),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  Widget ui(ProviderContainer value, Widget child, {String language = 'fr'}) =>
      UncontrolledProviderScope(
        container: value,
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox(width: 360, height: 700, child: child)),
        ),
      );
  const panel = AiAssistantPanel(projects: [project, other], timer: timer);

  test(
    'disabled and ChatGPT export never call gateway or apply proposals',
    () async {
      final gateway = _Gateway();
      final c = container(gateway);
      await c
          .read(aiProviderSettingsProvider.notifier)
          .setMode(AiProviderMode.disabled);
      final assistant = c.read(aiAssistantControllerProvider.notifier);
      await assistant.send('Help', context);
      await c
          .read(aiProviderSettingsProvider.notifier)
          .setMode(AiProviderMode.chatgpt);
      await assistant.send('Help', context);
      assistant.confirmProposals();
      expect(gateway.calls, 0);
      expect(c.read(aiAssistantControllerProvider).proposedActions, isEmpty);
    },
  );
  test('personal key required and proposals remain pending', () async {
    final gateway = _Gateway();
    final c = container(gateway);
    final settings = c.read(aiProviderSettingsProvider.notifier);
    await settings.setMode(AiProviderMode.personalOpenAi);
    final assistant = c.read(aiAssistantControllerProvider.notifier);
    await assistant.send('Help', context);
    expect(gateway.calls, 0);
    expect(settings.configureKey('offline-key'), isTrue);
    await assistant.send('Help', context);
    expect(gateway.calls, 1);
    expect(
      c.read(aiAssistantControllerProvider).proposalStatus,
      AiProposalStatus.pending,
    );
  });
  test(
    'switch clears key, history and late replies and prevents retry',
    () async {
      final gateway = _Gateway()..pending = Completer<AiResponse>();
      final c = container(gateway);
      final settings = c.read(aiProviderSettingsProvider.notifier);
      await settings.setMode(AiProviderMode.personalOpenAi);
      settings.configureKey('offline-key');
      final assistant = c.read(aiAssistantControllerProvider.notifier);
      final response = assistant.send('Help', context);
      await settings.setMode(AiProviderMode.disabled);
      gateway.pending!.complete(
        const AiResponse(
          text: 'Late',
          proposedActions: [
            AiProposedAction(type: AiProposedActionType.addTask, title: 'Late'),
          ],
        ),
      );
      await response;
      await assistant.retry();
      expect(gateway.calls, 1);
      expect(c.read(aiAssistantControllerProvider).messages, isEmpty);
      expect(c.read(aiAssistantControllerProvider).proposedActions, isEmpty);
      expect(c.read(sessionAiKeyProvider).forOwner('owner-a'), isNull);
    },
  );
  test(
    'only mode persists across reload and cloud revision stays unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = FocusDayStorage(prefs);
      final c = container(_Gateway(), storage: storage);
      final settings = c.read(aiProviderSettingsProvider.notifier);
      await settings.setMode(AiProviderMode.chatgpt);
      await settings.setMode(AiProviderMode.personalOpenAi);
      settings.configureKey('offline-key');
      expect(prefs.getKeys(), {'focusday.local.aiProvider'});
      expect(prefs.getString('focusday.local.aiProvider'), 'personalOpenAi');
      expect(storage.loadSettingsRevision(), 0);
      expect(
        c.read(aiProviderSettingsProvider).toString(),
        isNot(contains('offline-key')),
      );
      expect(
        c.read(sessionAiKeyProvider).toString(),
        isNot(contains('offline-key')),
      );
      final reloaded = container(_Gateway(), storage: storage);
      expect(
        reloaded.read(aiProviderSettingsProvider).mode,
        AiProviderMode.focusday,
      );
      expect(reloaded.read(aiProviderSettingsProvider).keyConfigured, isFalse);
      expect(reloaded.read(sessionAiKeyProvider).forOwner('owner-a'), isNull);
    },
  );
  test(
    'key is cleared on account switch and cannot be reused by another owner',
    () async {
      final c = container(_Gateway());
      final settings = c.read(aiProviderSettingsProvider.notifier);
      await settings.setMode(AiProviderMode.personalOpenAi);
      settings.configureKey('offline-key');
      expect(c.read(sessionAiKeyProvider).forOwner('owner-b'), isNull);
      c.read(ownerProvider.notifier).change('owner-b');
      await c.pump();
      expect(c.read(aiProviderSettingsProvider).keyConfigured, isFalse);
      expect(c.read(sessionAiKeyProvider).forOwner('owner-a'), isNull);
      c.read(ownerProvider.notifier).change(null);
      await c.pump();
      expect(settings.configureKey('offline-key'), isFalse);
    },
  );
  for (final mode in [AiProviderMode.chatgpt, AiProviderMode.disabled]) {
    test(
      'switch to ${mode.name} invalidates pending proposals and confirmation',
      () async {
        final c = container(_Gateway());
        final settings = c.read(aiProviderSettingsProvider.notifier);
        await settings.setMode(AiProviderMode.personalOpenAi);
        settings.configureKey('offline-key');
        final assistant = c.read(aiAssistantControllerProvider.notifier);
        await assistant.send('Help', context);
        expect(
          c.read(aiAssistantControllerProvider).proposalStatus,
          AiProposalStatus.pending,
        );
        await settings.setMode(mode);
        assistant.confirmProposals();
        expect(c.read(aiAssistantControllerProvider).proposedActions, isEmpty);
        expect(c.read(aiAssistantControllerProvider).conversationId, isNull);
        expect(c.read(aiAssistantControllerProvider).proposalStatus, isNull);
      },
    );
  }
  for (final mode in AiProviderMode.values) {
    testWidgets('${mode.name} English UI remains usable at compact width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = container(_Gateway());
      await c.read(aiProviderSettingsProvider.notifier).setMode(mode);
      await tester.pumpWidget(ui(c, panel, language: 'en'));
      expect(tester.takeException(), isNull);
      if (mode == AiProviderMode.disabled) {
        expect(find.text('AI assistant disabled'), findsOneWidget);
      }
      if (mode == AiProviderMode.chatgpt) {
        expect(find.textContaining('Project: Active'), findsOneWidget);
        expect(find.byKey(const Key('ai-copy-chatgpt')), findsOneWidget);
      }
    });
  }
  test('key deletion resets conversation and leaves selected mode', () async {
    final c = container(_Gateway());
    final settings = c.read(aiProviderSettingsProvider.notifier);
    await settings.setMode(AiProviderMode.personalOpenAi);
    settings.configureKey('offline-key');
    await c.read(aiAssistantControllerProvider.notifier).send('Help', context);
    settings.deleteKey();
    expect(
      c.read(aiProviderSettingsProvider).mode,
      AiProviderMode.personalOpenAi,
    );
    expect(c.read(aiAssistantControllerProvider).messages, isEmpty);
  });
  test(
    'ChatGPT export is human readable and excludes IDs and other projects',
    () {
      final text = buildChatGptExport(context);
      expect(text, contains('Projet: Active'));
      expect(text, contains('12 min 0 s'));
      expect(text, contains('- [ ] Draft'));
      expect(text, contains('- [x] Done'));
      expect(text, contains('Notes'));
      expect(text, isNot(contains('private-')));
      expect(text, isNot(contains('Hidden project')));
    },
  );
  testWidgets('disabled UI has no composer or proposals', (tester) async {
    final c = container(_Gateway());
    await c
        .read(aiProviderSettingsProvider.notifier)
        .setMode(AiProviderMode.disabled);
    await tester.pumpWidget(ui(c, panel));
    expect(find.text('Assistant IA désactivé'), findsOneWidget);
    expect(find.byKey(const Key('ai-message-input')), findsNothing);
    expect(find.byKey(const Key('ai-proposal-card')), findsNothing);
  });
  testWidgets('ChatGPT copies preview without a gateway call', (tester) async {
    final gateway = _Gateway();
    final c = container(gateway);
    await c
        .read(aiProviderSettingsProvider.notifier)
        .setMode(AiProviderMode.chatgpt);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(ui(c, panel));
    await tester.ensureVisible(find.byKey(const Key('ai-copy-chatgpt')));
    await tester.tap(find.byKey(const Key('ai-copy-chatgpt')));
    await tester.pump();
    expect(copied, buildChatGptExport(context));
    expect(gateway.calls, 0);
    expect(find.byKey(const Key('ai-send-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('personal mode without key links to settings', (tester) async {
    final c = container(_Gateway());
    await c
        .read(aiProviderSettingsProvider.notifier)
        .setMode(AiProviderMode.personalOpenAi);
    await tester.pumpWidget(ui(c, panel, language: 'en'));
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.byKey(const Key('ai-message-input')), findsNothing);
  });
  for (final language in ['fr', 'en']) {
    testWidgets('V1 settings excludes personal key controls ($language)', (
      tester,
    ) async {
      final c = container(_Gateway());
      await tester.pumpWidget(
        ui(
          c,
          const SingleChildScrollView(child: AiProviderSettingsSection()),
          language: language,
        ),
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<AiProviderMode>));
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'fr' ? 'Ma clé OpenAI API' : 'My OpenAI API key'),
        findsNothing,
      );
      final dropdown = tester.widget<DropdownButtonFormField<AiProviderMode>>(
        find.byType(DropdownButtonFormField<AiProviderMode>),
      );
      expect(dropdown.initialValue, AiProviderMode.focusday);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('V1 default assistant sends without a personal key', (
    tester,
  ) async {
    final gateway = _Gateway();
    final c = container(gateway);
    await tester.pumpWidget(ui(c, panel));
    expect(find.byKey(const Key('ai-message-input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Help');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);
    expect(find.text('Advice'), findsOneWidget);
    expect(c.read(sessionAiKeyProvider).forOwner('owner-a'), isNull);
  });
}
