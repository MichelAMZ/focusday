import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/ai/application/ai_assistant_controller.dart';
import 'package:focusday/features/ai/application/ai_assistant_gateway.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/presentation/ai_assistant_panel.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/l10n/app_localizations.dart';

void main() {
  const project = FocusProject(
    id: 'private-id',
    name: 'FocusDay',
    durationMinutes: 25,
    status: FocusProjectStatus.active,
    notes: 'Private note',
    tasks: [FocusTask(id: 'task-id', title: 'Review')],
  );
  const timer = FocusTimerState(
    projectId: 'private-id',
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
    expect(serialized, isNot(contains('private-id')));
    expect(serialized, isNot(contains('task-id')));
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
}

class _FakeGateway implements AiAssistantGateway {
  _FakeGateway({this.error, this.completer, this.failOnce = false});
  final AiAssistantErrorCategory? error;
  final Completer<AiResponse>? completer;
  final bool failOnce;
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
    );
  }
}
