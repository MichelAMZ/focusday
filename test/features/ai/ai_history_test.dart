import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/core/storage/storage_provider.dart';
import 'package:focusday/features/ai/application/ai_assistant_controller.dart';
import 'package:focusday/features/ai/application/ai_assistant_gateway.dart';
import 'package:focusday/features/ai/application/ai_provider_settings.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/infrastructure/ai_chat_history_store.dart';
import 'package:focusday/features/ai/presentation/ai_assistant_panel.dart';
import 'package:focusday/features/today/application/today_controller.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/l10n/app_localizations.dart';

class _Gateway implements AiAssistantGateway {
  final started = Completer<void>();
  Completer<AiResponse>? pending;
  int calls = 0;
  @override
  Future<AiResponse> respond(AiRequest request) async {
    calls++;
    if (!started.isCompleted) started.complete();
    return pending?.future ??
        const AiResponse(
          text: 'Advice',
          conversationId: 'remote-private-id',
          proposedActions: [
            AiProposedAction(
              type: AiProposedActionType.addTask,
              title: 'Pending task',
            ),
          ],
        );
  }
}

class _FailingStore extends AiChatHistoryStore {
  _FailingStore(super.preferences);
  @override
  Future<bool> save(List<AiChatMessage> messages) async => false;
  @override
  Future<bool> clear() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  const context = AiAssistantContext(
    language: 'fr',
    focusRemainingSeconds: 60,
    activeProject: AiAssistantProjectContext(
      name: 'Bogoka',
      localProjectId: 'bogoka',
      tasks: [],
    ),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  ProviderContainer create(_Gateway gateway, {AiChatHistoryStore? store}) {
    final c = ProviderContainer(
      overrides: [
        focusDayStorageProvider.overrideWithValue(FocusDayStorage(prefs)),
        aiAssistantGatewayProvider.overrideWithValue(gateway),
        if (store != null) aiChatHistoryStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  List<dynamic> saved() =>
      (jsonDecode(prefs.getString(AiChatHistoryStore.key)!) as Map)['messages']
          as List;
  Future<void> send(ProviderContainer c, [String text = 'Help']) =>
      c.read(aiAssistantControllerProvider.notifier).send(text, context);
  AiChatMessage message(String id) => AiChatMessage(
    id: id,
    role: AiChatRole.user,
    text: 'Message $id',
    createdAt: DateTime.utc(2026, 9, 11),
    projectId: 'bogoka',
  );

  test(
    'user message is persisted before the response, with timestamp and project',
    () async {
      final gateway = _Gateway()..pending = Completer<AiResponse>();
      final c = create(gateway);
      final request = send(c);
      await gateway.started.future;
      expect(saved(), hasLength(1));
      expect(saved().single['role'], 'user');
      expect(saved().single['text'], 'Help');
      expect(saved().single['projectId'], 'bogoka');
      expect(saved().single['projectName'], 'Bogoka');
      expect(DateTime.tryParse(saved().single['createdAt']), isNotNull);
      gateway.pending!.complete(const AiResponse(text: 'Done'));
      await request;
    },
  );
  test(
    'assistant message persists in order and restores after provider recreation',
    () async {
      final c = create(_Gateway());
      await send(c);
      final previous = c
          .read(aiAssistantControllerProvider)
          .messages
          .map((m) => m.toJson())
          .toList();
      expect(saved().map((m) => m['role']), ['user', 'assistant']);
      expect(saved().last['text'], 'Advice');
      await prefs.reload();
      final gateway = _Gateway();
      final restored = create(gateway);
      expect(
        restored
            .read(aiAssistantControllerProvider)
            .messages
            .map((m) => m.toJson())
            .toList(),
        previous,
      );
      expect(gateway.calls, 0);
      expect(restored.read(aiAssistantControllerProvider).isSending, isFalse);
    },
  );
  test('missing history is empty and performs no AI request', () {
    final gateway = _Gateway();
    final c = create(gateway);
    expect(c.read(aiAssistantControllerProvider).messages, isEmpty);
    expect(c.read(aiAssistantControllerProvider).historyError, isFalse);
    expect(gateway.calls, 0);
  });
  for (final raw in [
    'broken JSON',
    '[]',
    '{"version":2,"messages":[]}',
    '{"version":1,"messages":[{"id":"a","role":"system"}]}',
    '{"version":1,"messages":[],"Authorization":"private-fixture"}',
  ]) {
    test(
      'corrupt history ${raw.length} is handled without a request or execution',
      () async {
        await prefs.setString(AiChatHistoryStore.key, raw);
        final gateway = _Gateway();
        final c = create(gateway);
        expect(c.read(aiAssistantControllerProvider).messages, isEmpty);
        expect(c.read(aiAssistantControllerProvider).historyError, isTrue);
        c.read(aiAssistantControllerProvider.notifier).confirmProposals();
        expect(gateway.calls, 0);
      },
    );
  }
  test(
    'duplicate IDs are restored once and new messages have fresh IDs',
    () async {
      await prefs.setString(
        AiChatHistoryStore.key,
        jsonEncode({
          'version': 1,
          'messages': [
            message('message-8').toJson(),
            message('message-8').toJson(),
          ],
        }),
      );
      final c = create(_Gateway());
      expect(c.read(aiAssistantControllerProvider).messages, hasLength(1));
      c.invalidate(aiAssistantControllerProvider);
      expect(c.read(aiAssistantControllerProvider).messages, hasLength(1));
      await send(c);
      final ids = c
          .read(aiAssistantControllerProvider)
          .messages
          .map((m) => m.id);
      expect(ids.toSet(), hasLength(3));
      expect(saved(), hasLength(3));
    },
  );
  test(
    'pending 15D actions and remote conversation state never restore',
    () async {
      final c = create(_Gateway());
      await send(c);
      expect(
        c.read(aiAssistantControllerProvider).proposalStatus,
        AiProposalStatus.pending,
      );
      final gateway = _Gateway();
      final restored = create(gateway);
      final before = restored
          .read(todayProjectsProvider)
          .map((p) => p.toJson())
          .toList();
      final state = restored.read(aiAssistantControllerProvider);
      expect(state.messages, hasLength(2));
      expect(state.proposedActions, isEmpty);
      expect(state.proposalStatus, isNull);
      expect(state.conversationId, isNull);
      restored.read(aiAssistantControllerProvider.notifier).confirmProposals();
      await restored.read(aiAssistantControllerProvider.notifier).retry();
      expect(
        restored.read(todayProjectsProvider).map((p) => p.toJson()).toList(),
        before,
      );
      expect(gateway.calls, 0);
    },
  );
  test(
    'strict storage schema excludes credentials, headers, request context and actions',
    () async {
      final c = create(_Gateway());
      c.read(sessionAiKeyProvider).configure('private-key-fixture', 'owner');
      await send(c);
      final raw = prefs.getString(AiChatHistoryStore.key)!;
      for (final forbidden in [
        'private-key-fixture',
        'remote-private-id',
        'Pending task',
        'OPENAI_API_KEY',
        'Authorization',
        'token',
        'safety',
        'proposedActions',
        'focusRemainingSeconds',
      ]) {
        expect(raw, isNot(contains(forbidden)));
      }
      expect((saved().first as Map).keys.toSet(), {
        'id',
        'role',
        'text',
        'createdAt',
        'projectId',
        'projectName',
      });
      expect(prefs.getKeys(), {AiChatHistoryStore.key});
    },
  );
  test(
    'clear removes only history and prevents a late response from restoring it',
    () async {
      await prefs.setString('unrelated', 'untouched');
      final gateway = _Gateway()..pending = Completer<AiResponse>();
      final c = create(gateway);
      final request = send(c);
      await gateway.started.future;
      await c.read(aiAssistantControllerProvider.notifier).clearHistory();
      gateway.pending!.complete(const AiResponse(text: 'Late reply'));
      await request;
      expect(c.read(aiAssistantControllerProvider).messages, isEmpty);
      expect(prefs.containsKey(AiChatHistoryStore.key), isFalse);
      expect(prefs.getString('unrelated'), 'untouched');
      expect(
        create(_Gateway()).read(aiAssistantControllerProvider).messages,
        isEmpty,
      );
    },
  );
  test(
    'serialized writes finish before clear and cannot resurrect history',
    () async {
      final store = AiChatHistoryStore(prefs);
      final first = store.save([message('message-1')]);
      final second = store.save([message('message-1'), message('message-2')]);
      final clear = store.clear();
      expect(await Future.wait([first, second, clear]), [true, true, true]);
      expect(prefs.containsKey(AiChatHistoryStore.key), isFalse);
    },
  );
  test(
    'history is bounded to the last 100 messages in original order',
    () async {
      final store = AiChatHistoryStore(prefs);
      await store.save(List.generate(110, (i) => message('message-$i')));
      final history = store.load().messages;
      expect(history, hasLength(100));
      expect(history.first.id, 'message-10');
      expect(history.last.id, 'message-109');
    },
  );
  test('save failure is visible and clear failure retains messages', () async {
    final c = create(_Gateway(), store: _FailingStore(prefs));
    await send(c);
    expect(c.read(aiAssistantControllerProvider).historyError, isTrue);
    expect(c.read(aiAssistantControllerProvider).messages, hasLength(2));
    await c.read(aiAssistantControllerProvider.notifier).clearHistory();
    expect(c.read(aiAssistantControllerProvider).historyError, isTrue);
    expect(c.read(aiAssistantControllerProvider).messages, hasLength(2));
    expect(c.read(aiAssistantControllerProvider).proposedActions, isEmpty);
  });
  test('changing mode does not delete saved FocusDay history', () async {
    final c = create(_Gateway());
    await send(c);
    await c
        .read(aiProviderSettingsProvider.notifier)
        .setMode(AiProviderMode.disabled);
    expect(saved(), hasLength(2));
    await c
        .read(aiProviderSettingsProvider.notifier)
        .setMode(AiProviderMode.focusday);
    expect(c.read(aiAssistantControllerProvider).messages, hasLength(2));
    expect(c.read(aiAssistantControllerProvider).proposedActions, isEmpty);
  });
  for (final language in ['fr', 'en']) {
    testWidgets('clear history requires explicit confirmation ($language)', (
      tester,
    ) async {
      final c = create(_Gateway());
      await send(c);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AiAssistantPanel(
                projects: c.read(todayProjectsProvider),
                timer: const FocusTimerState(
                  projectId: 'bogoka',
                  initialSeconds: 1500,
                  remainingSeconds: 1500,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('ai-history-clear')));
      await tester.pumpAndSettle();
      expect(saved(), hasLength(2));
      await tester.tap(find.text(language == 'fr' ? 'Annuler' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(saved(), hasLength(2));
      await tester.tap(find.byKey(const Key('ai-history-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai-history-clear-confirm')));
      await tester.pumpAndSettle();
      expect(c.read(aiAssistantControllerProvider).messages, isEmpty);
      expect(prefs.containsKey(AiChatHistoryStore.key), isFalse);
      expect(find.byKey(const Key('ai-proposal-confirm')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
