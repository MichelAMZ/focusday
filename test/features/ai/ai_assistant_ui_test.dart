import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/ai/application/ai_assistant_controller.dart';
import 'package:focusday/features/ai/application/ai_assistant_gateway.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/infrastructure/fake_ai_assistant_gateway.dart';
import 'package:focusday/features/ai/presentation/ai_assistant_panel.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/features/today/application/focus_timer_controller.dart';
import 'package:focusday/features/today/application/today_controller.dart';
import 'package:focusday/l10n/app_localizations.dart';

void main() {
  const project = FocusProject(
    id: 'bogoka',
    name: 'FocusDay',
    durationMinutes: 25,
    status: FocusProjectStatus.active,
    notes: 'Private note',
    tasks: [FocusTask(id: 'bogoka-1', title: 'Review')],
  );
  const timer = FocusTimerState(
    projectId: 'bogoka',
    initialSeconds: 1500,
    remainingSeconds: 600,
  );

  Widget app(
    AiAssistantGateway gateway, {
    Locale locale = const Locale('fr'),
    bool dedicated = false,
    double width = 360,
  }) {
    return ProviderScope(
      overrides: [aiAssistantGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 700,
            child: AiAssistantPanel(
              projects: const [project],
              timer: timer,
              isDedicatedPage: dedicated,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows localized empty state and four quick suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(app(_FakeGateway()));
    expect(find.text('Que voulez-vous faire maintenant ?'), findsOneWidget);
    expect(find.text('Contexte : FocusDay'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(4));
    expect(find.text('Quelle est ma prochaine action ?'), findsOneWidget);
  });

  testWidgets('English UI is localized', (tester) async {
    await tester.pumpWidget(app(_FakeGateway(), locale: const Locale('en')));
    expect(find.text('What would you like to do now?'), findsOneWidget);
    expect(find.text('What is my next action?'), findsOneWidget);
    expect(find.text('Context: FocusDay'), findsOneWidget);
  });

  testWidgets('sends and displays user and fake assistant messages', (
    tester,
  ) async {
    await tester.pumpWidget(app(_FakeGateway()));
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Bonjour',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Réponse fake'), findsOneWidget);
    expect(find.byKey(const Key('ai-user-bubble')), findsOneWidget);
    expect(find.byKey(const Key('ai-assistant-bubble')), findsOneWidget);
  });

  testWidgets('dedicated wide layout uses two suggestion columns', (
    tester,
  ) async {
    await tester.pumpWidget(app(_FakeGateway(), dedicated: true, width: 1200));
    final first = tester.getTopLeft(find.byKey(const Key('ai-suggestion-0')));
    final second = tester.getTopLeft(find.byKey(const Key('ai-suggestion-1')));
    expect(first.dy, second.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(
      tester.getSize(find.byKey(const Key('ai-composer'))).width,
      lessThanOrEqualTo(920),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows loading and prevents double send', (tester) async {
    final completer = Completer<AiResponse>();
    final gateway = _FakeGateway(completer: completer);
    await tester.pumpWidget(app(gateway));
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Bonjour',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pump();
    expect(find.text('Réflexion en cours…'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('ai-send-button')))
          .onPressed,
      isNull,
    );
    completer.complete(const AiResponse(text: 'Réponse fake'));
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);
  });

  for (final entry in {
    AiAssistantErrorCategory.timeout:
        'La réponse prend trop de temps. Réessayez.',
    AiAssistantErrorCategory.rateLimited:
        'Trop de demandes. Réessayez plus tard.',
    AiAssistantErrorCategory.unauthenticated:
        'Connectez-vous pour utiliser l’assistant.',
  }.entries) {
    testWidgets('maps typed error to a safe localized message', (tester) async {
      await tester.pumpWidget(app(_FakeGateway(error: entry.key)));
      await tester.enterText(find.byKey(const Key('ai-message-input')), 'Test');
      await tester.tap(find.byKey(const Key('ai-send-button')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  }

  testWidgets('retry succeeds after a transient error', (tester) async {
    final gateway = _FakeGateway(failOnce: true);
    await tester.pumpWidget(app(gateway));
    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Test');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Réponse fake'), findsOneWidget);
    expect(gateway.calls, 2);
  });

  testWidgets('passes active allowlisted context and conversation id', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(app(gateway));
    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Un');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Deux');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final sent = gateway.requests.last;
    final serialized = sent.context.toJson().toString();
    expect(sent.context.activeProject?.name, 'FocusDay');
    expect(sent.context.focusRemainingSeconds, 600);
    expect(sent.conversationId, 'conversation-1');
    expect(serialized, isNot(contains('bogoka')));
    expect(serialized, isNot(contains('bogoka-1')));
    expect(serialized, isNot(contains('email')));
    expect(serialized, isNot(contains('uid')));
  });

  testWidgets('compact width renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(_FakeGateway()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('controller does not mutate project task timer or notes', () async {
    final gateway = _FakeGateway();
    final container = ProviderContainer(
      overrides: [aiAssistantGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final projectsBefore = project.toJson();
    final timerBefore = timer.toJson();
    const context = AiAssistantContext(
      language: 'fr',
      focusRemainingSeconds: 600,
    );
    await container
        .read(aiAssistantControllerProvider.notifier)
        .send('Aide', context);
    expect(project.toJson(), projectsBefore);
    expect(timer.toJson(), timerBefore);
  });

  testWidgets(
    'proposal is pending and causes no mutation before confirmation',
    (tester) async {
      final gateway = _FakeGateway(
        proposedActions: const [
          AiProposedAction(
            type: AiProposedActionType.addTask,
            title: 'Nouvelle tâche',
          ),
        ],
      );
      await tester.pumpWidget(app(gateway));
      await tester.enterText(
        find.byKey(const Key('ai-message-input')),
        'Découpe',
      );
      await tester.tap(find.byKey(const Key('ai-send-button')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantPanel)),
      );
      final before = container.read(todayProjectsProvider);
      expect(find.byKey(const Key('ai-proposal-card')), findsOneWidget);
      expect(find.text('Projet : FocusDay'), findsOneWidget);
      expect(find.textContaining('Nouvelle tâche'), findsOneWidget);
      expect(find.textContaining('bogoka-1'), findsNothing);
      await tester.pump();
      expect(container.read(todayProjectsProvider), same(before));
    },
  );

  testWidgets('add batch applies once only after explicit confirmation', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      proposedActions: const [
        AiProposedAction(type: AiProposedActionType.addTask, title: 'One'),
        AiProposedAction(type: AiProposedActionType.addTask, title: 'Two'),
      ],
    );
    await tester.pumpWidget(app(gateway));
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Découpe',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    final initialCount = container
        .read(todayProjectsProvider)
        .first
        .tasks
        .length;
    await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
    await tester.tap(
      find.byKey(const Key('ai-proposal-confirm')),
      warnIfMissed: false,
    );
    await tester.pump();
    final tasks = container.read(todayProjectsProvider).first.tasks;
    expect(tasks.length, initialCount + 2);
    expect(tasks.where((task) => task.title == 'One'), hasLength(1));
    expect(find.text('Proposition appliquée'), findsOneWidget);
    expect(find.byKey(const Key('ai-proposal-confirm')), findsNothing);
  });

  testWidgets('reject keeps data unchanged and performs no network call', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      proposedActions: const [
        AiProposedAction(type: AiProposedActionType.addTask, title: 'Never'),
      ],
    );
    await tester.pumpWidget(app(gateway));
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Découpe',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    final before = container.read(todayProjectsProvider);
    await tester.tap(find.byKey(const Key('ai-proposal-reject')));
    await tester.pump();
    expect(container.read(todayProjectsProvider), same(before));
    expect(gateway.calls, 1);
    expect(find.text('Proposition refusée'), findsOneWidget);
  });

  testWidgets('complete applies with ordering and stale proposal expires', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      proposedActions: const [
        AiProposedAction(
          type: AiProposedActionType.completeTask,
          taskId: 'bogoka-1',
        ),
      ],
    );
    await tester.pumpWidget(app(gateway));
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Termine',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    expect(
      container.read(todayProjectsProvider).first.tasks.first.isCompleted,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
    await tester.pump();
    expect(
      container.read(todayProjectsProvider).first.tasks.last.id,
      'bogoka-1',
    );
    expect(
      container.read(todayProjectsProvider).first.tasks.last.isCompleted,
      isTrue,
    );

    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Encore');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final before = container.read(todayProjectsProvider);
    await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
    await tester.pump();
    expect(container.read(todayProjectsProvider), same(before));
    expect(
      find.text("Cette proposition n'est plus applicable."),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders human previews for all action kinds in French and English',
    (tester) async {
      final actions = [
        const AiProposedAction(
          type: AiProposedActionType.renameTask,
          taskId: 'bogoka-1',
          newTitle: 'Review final',
        ),
        const AiProposedAction(
          type: AiProposedActionType.reopenTask,
          taskId: 'bogoka-1',
        ),
        const AiProposedAction(
          type: AiProposedActionType.updateProjectNotes,
          newNotes: 'After note',
        ),
        const AiProposedAction(
          type: AiProposedActionType.setFocusDuration,
          durationMinutes: 45,
        ),
      ];
      await tester.pumpWidget(app(_FakeGateway(proposedActions: actions)));
      await tester.enterText(
        find.byKey(const Key('ai-message-input')),
        'Propose',
      );
      await tester.tap(find.byKey(const Key('ai-send-button')));
      await tester.pumpAndSettle();
      expect(find.text('Renommer une tâche'), findsOneWidget);
      expect(find.text('Review → Review final'), findsOneWidget);
      expect(find.textContaining('Avant: Private note'), findsOneWidget);
      expect(find.text('25 min → 45 min'), findsOneWidget);
      expect(find.textContaining('bogoka-1'), findsNothing);

      await tester.pumpWidget(
        app(_FakeGateway(proposedActions: actions), locale: const Locale('en')),
      );
      await tester.enterText(
        find.byKey(const Key('ai-message-input')),
        'Propose',
      );
      await tester.tap(find.byKey(const Key('ai-send-button')));
      await tester.pumpAndSettle();
      expect(find.text('Rename a task'), findsOneWidget);
      expect(find.text('Change focus duration'), findsOneWidget);
    },
  );

  testWidgets('duration applies without starting timer and compact card fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        _FakeGateway(
          proposedActions: const [
            AiProposedAction(
              type: AiProposedActionType.setFocusDuration,
              durationMinutes: 25,
            ),
          ],
        ),
        width: 320,
      ),
    );
    await tester.enterText(find.byKey(const Key('ai-message-input')), '25');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    expect(container.read(focusTimerProvider).status, FocusTimerStatus.idle);
    expect(tester.takeException(), isNull);
  });

  for (final width in [1920.0, 1366.0, 1024.0, 360.0]) {
    testWidgets('proposal card has no overflow at ${width.toInt()} px', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          _FakeGateway(
            proposedActions: const [
              AiProposedAction(
                type: AiProposedActionType.addTask,
                title: 'Responsive task',
                description: 'A readable description',
              ),
            ],
          ),
          dedicated: width > 360,
          width: width,
        ),
      );
      await tester.enterText(find.byKey(const Key('ai-message-input')), 'Test');
      await tester.tap(find.byKey(const Key('ai-send-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-proposal-card')), findsOneWidget);
      if (width > 360) {
        expect(
          tester.getSize(find.byKey(const Key('ai-proposal-card'))).width,
          lessThanOrEqualTo(920),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirmed rename and notes use current project APIs', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        _FakeGateway(
          proposedActions: const [
            AiProposedAction(
              type: AiProposedActionType.renameTask,
              taskId: 'bogoka-1',
              newTitle: 'Titre final',
            ),
            AiProposedAction(
              type: AiProposedActionType.updateProjectNotes,
              newNotes: 'Notes finales',
            ),
          ],
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Modifie',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    expect(container.read(todayProjectsProvider).first.notes, isEmpty);
    await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
    await tester.pump();
    final updated = container.read(todayProjectsProvider).first;
    expect(updated.tasks.first.title, 'Titre final');
    expect(updated.notes, 'Notes finales');
  });

  testWidgets('confirmed reopen returns a completed task to active section', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        _FakeGateway(
          proposedActions: const [
            AiProposedAction(
              type: AiProposedActionType.reopenTask,
              taskId: 'bogoka-1',
            ),
          ],
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    container
        .read(todayProjectsProvider.notifier)
        .toggleTask('bogoka', 'bogoka-1');
    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Rouvre');
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
    await tester.pump();
    final task = container
        .read(todayProjectsProvider)
        .first
        .tasks
        .firstWhere((item) => item.id == 'bogoka-1');
    expect(task.isCompleted, isFalse);
    expect(container.read(todayProjectsProvider).first.tasks[3].id, 'bogoka-1');
  });

  testWidgets('composer keyboard input never confirms a pending proposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        _FakeGateway(
          proposedActions: const [
            AiProposedAction(
              type: AiProposedActionType.addTask,
              title: 'Not added',
            ),
          ],
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('ai-message-input')),
      'Propose',
    );
    await tester.tap(find.byKey(const Key('ai-send-button')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantPanel)),
    );
    final before = container.read(todayProjectsProvider).first.tasks.length;
    await tester.tap(find.byKey(const Key('ai-message-input')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(container.read(todayProjectsProvider).first.tasks.length, before);
    expect(find.byKey(const Key('ai-proposal-confirm')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ai-message-input')), 'Second');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(container.read(todayProjectsProvider).first.tasks.length, before);
    expect(find.byKey(const Key('ai-proposal-confirm')), findsOneWidget);
  });

  test('fake gateway provides all three offline action demos', () async {
    const gateway = FakeAiAssistantGateway(delay: Duration.zero);
    const context = AiAssistantContext(
      language: 'fr',
      focusRemainingSeconds: 1200,
      activeProject: AiAssistantProjectContext(
        name: 'Bogoka',
        tasks: [
          AiAssistantTaskContext(
            title: 'Première',
            completed: false,
            localTaskId: 'task-real-id',
          ),
        ],
      ),
    );
    final add = await gateway.respond(
      const AiRequest(message: 'Découpe ma prochaine tâche', context: context),
    );
    final complete = await gateway.respond(
      const AiRequest(
        message: 'Marque la première tâche comme terminée',
        context: context,
      ),
    );
    final duration = await gateway.respond(
      const AiRequest(
        message: 'Passe mon focus à 25 minutes',
        context: context,
      ),
    );
    expect(add.proposedActions, hasLength(3));
    expect(
      add.proposedActions.every(
        (action) => action.type == AiProposedActionType.addTask,
      ),
      isTrue,
    );
    expect(
      complete.proposedActions.single.type,
      AiProposedActionType.completeTask,
    );
    expect(complete.proposedActions.single.taskId, 'task-real-id');
    expect(duration.proposedActions.single.durationMinutes, 25);
  });
}

class _FakeGateway implements AiAssistantGateway {
  _FakeGateway({
    this.error,
    this.completer,
    this.failOnce = false,
    this.proposedActions = const [],
  });
  final AiAssistantErrorCategory? error;
  final Completer<AiResponse>? completer;
  final bool failOnce;
  final List<AiProposedAction> proposedActions;
  int calls = 0;
  final requests = <AiRequest>[];

  @override
  Future<AiResponse> respond(AiRequest request) async {
    calls++;
    requests.add(request);
    if (completer != null) return completer!.future;
    if (error != null || (failOnce && calls == 1)) {
      throw AiAssistantException(error ?? AiAssistantErrorCategory.timeout);
    }
    return const AiResponse(
      text: 'Réponse fake',
      conversationId: 'conversation-1',
    ).copyWithForTest(proposedActions);
  }
}

extension on AiResponse {
  AiResponse copyWithForTest(List<AiProposedAction> actions) => AiResponse(
    text: text,
    conversationId: conversationId,
    metadata: metadata,
    proposedActions: actions,
  );
}
