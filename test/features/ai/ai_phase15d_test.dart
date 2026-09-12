import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/ai/application/ai_assistant_controller.dart';
import 'package:focusday/features/ai/application/ai_assistant_context_builder.dart';
import 'package:focusday/features/ai/application/ai_assistant_gateway.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/presentation/ai_assistant_panel.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/today_controller.dart';
import 'package:focusday/features/today/application/focus_timer_controller.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/l10n/app_localizations.dart';

class _Gateway implements AiAssistantGateway {
  _Gateway(this.actions);
  final List<AiProposedAction> actions;
  Completer<AiResponse>? pending;
  @override
  Future<AiResponse> respond(AiRequest request) async =>
      pending?.future ?? AiResponse(text: 'Proposal', proposedActions: actions);
}

void main() {
  const project = FocusProject(
    id: 'p',
    name: 'Bogoka',
    durationMinutes: 25,
    status: FocusProjectStatus.active,
    tasks: [
      FocusTask(id: 't', title: 'Review'),
      FocusTask(id: 't2', title: 'Tests'),
    ],
  );
  const other = FocusProject(
    id: 'other',
    name: 'Other',
    durationMinutes: 10,
    tasks: [],
  );

  ProviderContainer create(_Gateway gateway) {
    final c = ProviderContainer(
      overrides: [aiAssistantGatewayProvider.overrideWithValue(gateway)],
    );
    c.read(todayProjectsProvider.notifier).replaceAllProjects([project, other]);
    c
        .read(focusTimerProvider.notifier)
        .reset(projectId: 'p', durationMinutes: 25);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> propose(ProviderContainer c) => c
      .read(aiAssistantControllerProvider.notifier)
      .send(
        'Help',
        const AiAssistantContextBuilder().build(
          language: 'fr',
          projects: c.read(todayProjectsProvider),
          timer: c.read(focusTimerProvider),
        ),
      );
  FocusProject current(ProviderContainer c) =>
      c.read(todayProjectsProvider).firstWhere((p) => p.id == 'p');

  final cases = <String, AiProposedAction>{
    'CREATE_TASK': const AiProposedAction(
      type: AiProposedActionType.addTask,
      title: 'Lancer les tests',
      projectId: 'p',
    ),
    'COMPLETE_TASK': const AiProposedAction(
      type: AiProposedActionType.completeTask,
      taskId: 'focusday_task_0',
    ),
    'START_TIMER': const AiProposedAction(
      type: AiProposedActionType.startTimer,
      projectId: 'p',
    ),
    'PAUSE_TIMER': const AiProposedAction(
      type: AiProposedActionType.pauseTimer,
      projectId: 'p',
    ),
    'UPDATE_PROJECT_DURATION': const AiProposedAction(
      type: AiProposedActionType.setFocusDuration,
      projectId: 'p',
      durationMinutes: 45,
    ),
  };
  for (final entry in cases.entries) {
    test(
      '${entry.key}: only explicit confirmation mutates, double confirmation is inert',
      () async {
        final c = create(_Gateway([entry.value]));
        if (entry.key == 'PAUSE_TIMER') {
          c.read(focusTimerProvider.notifier).start();
        }
        final before = current(c).toJson();
        final timerBefore = c.read(focusTimerProvider).toJson();
        await propose(c);
        expect(current(c).toJson(), before);
        expect(c.read(focusTimerProvider).toJson(), timerBefore);
        expect(
          c.read(aiAssistantControllerProvider).proposalStatus,
          AiProposalStatus.pending,
        );
        final controller = c.read(aiAssistantControllerProvider.notifier);
        controller.confirmProposals();
        expect(
          c.read(aiAssistantControllerProvider).proposalStatus,
          AiProposalStatus.applied,
        );
        switch (entry.key) {
          case 'CREATE_TASK':
            expect(
              current(c).tasks.where((t) => t.title == 'Lancer les tests'),
              hasLength(1),
            );
          case 'COMPLETE_TASK':
            expect(
              current(c).tasks.firstWhere((t) => t.id == 't').isCompleted,
              isTrue,
            );
          case 'START_TIMER':
            expect(c.read(focusTimerProvider).status, FocusTimerStatus.running);
          case 'PAUSE_TIMER':
            expect(c.read(focusTimerProvider).status, FocusTimerStatus.paused);
          case 'UPDATE_PROJECT_DURATION':
            expect(current(c).durationMinutes, 45);
            expect(c.read(focusTimerProvider).initialSeconds, 2700);
            expect(c.read(focusTimerProvider).status, FocusTimerStatus.idle);
        }
        final after = current(c).toJson();
        final timerAfter = c.read(focusTimerProvider).toJson();
        controller.confirmProposals();
        expect(current(c).toJson(), after);
        expect(c.read(focusTimerProvider).toJson(), timerAfter);
        expect(
          c
              .read(todayProjectsProvider)
              .firstWhere((p) => p.id == 'other')
              .toJson(),
          other.toJson(),
        );
      },
    );
  }
  test('refusal prevents creation even if confirmation follows', () async {
    final c = create(_Gateway([cases['CREATE_TASK']!]));
    await propose(c);
    final controller = c.read(aiAssistantControllerProvider.notifier);
    controller.rejectProposals();
    controller.confirmProposals();
    expect(current(c).toJson(), project.toJson());
    expect(
      c.read(aiAssistantControllerProvider).proposalStatus,
      AiProposalStatus.rejected,
    );
  });
  final invalid = [
    const AiProposedAction(type: AiProposedActionType.addTask, title: ' '),
    const AiProposedAction(
      type: AiProposedActionType.addTask,
      projectId: 'missing',
      title: 'No',
    ),
    const AiProposedAction(
      type: AiProposedActionType.completeTask,
      taskId: 'missing',
    ),
    const AiProposedAction(
      type: AiProposedActionType.completeTask,
      taskId: 'focusday_task_99',
    ),
    const AiProposedAction(
      type: AiProposedActionType.setFocusDuration,
      durationMinutes: 0,
    ),
    const AiProposedAction(
      type: AiProposedActionType.setFocusDuration,
      durationMinutes: 481,
    ),
    const AiProposedAction(
      type: AiProposedActionType.pauseTimer,
      projectId: 'p',
    ),
  ];
  for (var i = 0; i < invalid.length; i++) {
    test(
      'invalid action $i rejects the entire batch without mutation',
      () async {
        final c = create(_Gateway([cases['CREATE_TASK']!, invalid[i]]));
        final before = c.read(focusTimerProvider).toJson();
        await propose(c);
        c.read(aiAssistantControllerProvider.notifier).confirmProposals();
        expect(current(c).toJson(), project.toJson());
        expect(c.read(focusTimerProvider).toJson(), before);
        expect(
          c.read(aiAssistantControllerProvider).proposalStatus,
          AiProposalStatus.expired,
        );
      },
    );
  }
  test('duplicate completion cannot toggle a task twice', () async {
    final c = create(
      _Gateway([cases['COMPLETE_TASK']!, cases['COMPLETE_TASK']!]),
    );
    await propose(c);
    c.read(aiAssistantControllerProvider.notifier).confirmProposals();
    expect(current(c).toJson(), project.toJson());
    expect(
      c.read(aiAssistantControllerProvider).proposalStatus,
      AiProposalStatus.expired,
    );
  });
  test('late proposal cannot move to a different active project', () async {
    final gateway = _Gateway([
      const AiProposedAction(type: AiProposedActionType.addTask, title: 'No'),
    ])..pending = Completer<AiResponse>();
    final c = create(gateway);
    final request = propose(c);
    c.read(todayProjectsProvider.notifier).startProject('other');
    final before = c
        .read(todayProjectsProvider)
        .map((p) => p.toJson())
        .toList();
    gateway.pending!.complete(
      AiResponse(text: 'Proposal', proposedActions: gateway.actions),
    );
    await request;
    c.read(aiAssistantControllerProvider.notifier).confirmProposals();
    expect(
      c.read(todayProjectsProvider).map((p) => p.toJson()).toList(),
      before,
    );
    expect(
      c.read(aiAssistantControllerProvider).proposalStatus,
      AiProposalStatus.expired,
    );
  });
  test(
    'task references remain tied to the request despite reordered tasks',
    () async {
      final c = create(_Gateway([cases['COMPLETE_TASK']!]));
      await propose(c);
      c.read(todayProjectsProvider.notifier).replaceAllProjects([
        project.copyWith(tasks: project.tasks.reversed.toList()),
        other,
      ]);
      c.read(aiAssistantControllerProvider.notifier).confirmProposals();
      expect(
        current(c).tasks.firstWhere((t) => t.id == 't').isCompleted,
        isTrue,
      );
      expect(
        current(c).tasks.firstWhere((t) => t.id == 't2').isCompleted,
        isFalse,
      );
    },
  );
  for (final language in ['fr', 'en']) {
    testWidgets(
      'timer action card has explicit confirmation and result ($language)',
      (tester) async {
        final c = create(_Gateway([cases['START_TIMER']!]));
        await propose(c);
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
                  timer: c.read(focusTimerProvider),
                ),
              ),
            ),
          ),
        );
        expect(
          find.text(language == 'fr' ? 'Démarrer le timer' : 'Start timer'),
          findsOneWidget,
        );
        expect(c.read(focusTimerProvider).status, FocusTimerStatus.idle);
        await tester.ensureVisible(
          find.byKey(const Key('ai-proposal-confirm')),
        );
        await tester.tap(find.byKey(const Key('ai-proposal-confirm')));
        await tester.pump();
        expect(c.read(focusTimerProvider).status, FocusTimerStatus.running);
        expect(find.byKey(const Key('ai-proposal-confirm')), findsNothing);
        expect(
          find.text(
            language == 'fr' ? 'Proposition appliquée' : 'Proposal applied',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        c.read(focusTimerProvider.notifier).pause();
      },
    );
  }
}
