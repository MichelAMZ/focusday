import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/ai/application/ai_assistant_context_builder.dart';
import 'package:focusday/features/ai/application/ai_assistant_gateway.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';

void main() {
  const builder = AiAssistantContextBuilder();
  const active = FocusProject(
    id: 'private-project-id',
    name: 'Launch',
    durationMinutes: 25,
    status: FocusProjectStatus.active,
    notes: 'Keep the scope small.',
    tasks: [
      FocusTask(id: 'private-task-1', title: 'Draft', isCompleted: true),
      FocusTask(id: 'private-task-2', title: 'Review'),
    ],
  );
  const other = FocusProject(
    id: 'other-private-id',
    name: 'Secret other project',
    durationMinutes: 10,
    tasks: [],
  );
  const timer = FocusTimerState(
    projectId: 'private-project-id',
    initialSeconds: 1500,
    remainingSeconds: 720,
    status: FocusTimerStatus.paused,
  );

  test('builds the explicit allowlisted active-project context', () {
    final json = builder
        .build(language: 'fr', projects: const [active, other], timer: timer)
        .toJson();
    final project = json['activeProject']! as Map<String, Object?>;
    final tasks = project['tasks']! as List<Object?>;

    expect(json['language'], 'fr');
    expect(json['focusRemainingSeconds'], 720);
    expect(project['name'], 'Launch');
    expect(project['notes'], 'Keep the scope small.');
    expect(tasks, [
      {'title': 'Draft', 'completed': true},
      {'title': 'Review', 'completed': false},
    ]);
  });

  test('excludes identifiers, other projects, credentials, and secrets', () {
    final encoded = builder
        .build(language: 'en', projects: const [active, other], timer: timer)
        .toJson()
        .toString();

    expect(encoded, isNot(contains('private-project-id')));
    expect(encoded, isNot(contains('private-task')));
    expect(encoded, isNot(contains('Secret other project')));
    expect(encoded, isNot(contains('email')));
    expect(encoded, isNot(contains('uid')));
    expect(encoded, isNot(contains('apiKey')));
  });

  test('omits empty notes and unrelated timer state', () {
    final project = active.copyWith(notes: '  ');
    final context = builder.build(
      language: 'en',
      projects: [project],
      timer: timer.copyWith(projectId: 'another-project'),
    );
    final activeJson = context.toJson()['activeProject']! as Map;

    expect(activeJson.containsKey('notes'), isFalse);
    expect(context.focusRemainingSeconds, 0);
  });

  test('serializes request without absent optional values', () {
    final context = builder.build(
      language: 'fr',
      projects: const [active],
      timer: timer,
    );
    final json = AiRequest(
      message: 'Prochaine action ?',
      context: context,
    ).toJson();

    expect(json['message'], 'Prochaine action ?');
    expect(json.containsKey('conversationId'), isFalse);
    expect(json['context'], context.toJson());
  });

  test('serializes conversation id and parses minimal response metadata', () {
    final context = builder.build(
      language: 'fr',
      projects: const [active],
      timer: timer,
    );
    expect(
      AiRequest(
        message: 'Suite',
        conversationId: 'conv-1',
        context: context,
      ).toJson()['conversationId'],
      'conv-1',
    );

    final response = AiResponse.fromJson({
      'text': 'Commencez par Review.',
      'conversationId': 'conv-1',
      'metadata': {'requestId': 'request-1'},
    });
    expect(response.text, 'Commencez par Review.');
    expect(response.conversationId, 'conv-1');
    expect(response.metadata.requestId, 'request-1');
  });

  test('invalid response becomes a typed server error', () {
    expect(
      () => AiResponse.fromJson({'text': ''}),
      throwsA(
        isA<AiAssistantException>().having(
          (error) => error.category,
          'category',
          AiAssistantErrorCategory.serverError,
        ),
      ),
    );
  });

  test('all client error categories are available for localization', () {
    expect(AiAssistantErrorCategory.values, {
      AiAssistantErrorCategory.unauthenticated,
      AiAssistantErrorCategory.unavailable,
      AiAssistantErrorCategory.timeout,
      AiAssistantErrorCategory.rateLimited,
      AiAssistantErrorCategory.invalidRequest,
      AiAssistantErrorCategory.serverError,
      AiAssistantErrorCategory.personalQuota,
      AiAssistantErrorCategory.personalAccess,
      AiAssistantErrorCategory.backendConfiguration,
    });
  });

  test('fake gateway is usable without network', () async {
    final gateway = _FakeAiAssistantGateway();
    final response = await gateway.respond(
      AiRequest(
        message: 'Que faire ?',
        context: builder.build(
          language: 'fr',
          projects: const [active],
          timer: timer,
        ),
      ),
    );

    expect(response.text, 'Réponse locale de test');
    expect(gateway.lastRequest?.context.activeProject?.name, 'Launch');
  });
}

class _FakeAiAssistantGateway implements AiAssistantGateway {
  AiRequest? lastRequest;

  @override
  Future<AiResponse> respond(AiRequest request) async {
    lastRequest = request;
    return const AiResponse(text: 'Réponse locale de test');
  }
}
