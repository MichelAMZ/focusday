import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:focusday/features/ai/application/ai_assistant_controller.dart';
import 'package:focusday/features/ai/application/ai_provider_settings.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/infrastructure/http_ai_assistant_gateway.dart';

class _Configured extends AiProviderSettingsController {
  @override
  AiProviderSettings build() => const AiProviderSettings(
    mode: AiProviderMode.personalOpenAi,
    keyConfigured: true,
  );
}

class _Tokens implements FirebaseIdTokenProvider {
  int calls = 0;
  String? value = 'offline-token';
  bool fail = false;
  @override
  Future<String?> getIdToken() async {
    calls++;
    if (fail) throw StateError('PRIVATE_TOKEN_ERROR');
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const context = AiAssistantContext(language: 'fr', focusRemainingSeconds: 60);
  const request = AiRequest(message: 'Question', context: context);
  late List<String> logs;
  late DebugPrintCallback oldPrint;
  setUp(() {
    logs = [];
    oldPrint = debugPrint;
    debugPrint = (String? text, {int? wrapWidth}) {
      if (text != null) logs.add(text);
    };
  });
  tearDown(() => debugPrint = oldPrint);
  ProviderContainer container(
    String url,
    _Tokens tokens,
    http.Client client, {
    String? key = 'offline-key',
  }) {
    final c = ProviderContainer(
      overrides: [
        aiProviderSettingsProvider.overrideWith(_Configured.new),
        aiBackendUrlProvider.overrideWithValue(url),
        aiIdTokenProvider.overrideWithValue(tokens),
        aiPersonalKeyReaderProvider.overrideWithValue(() => key),
        aiHttpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(client.close);
    return c;
  }

  test(
    'configured key plus missing build URL stops before token and HTTP with exact reason',
    () async {
      final tokens = _Tokens();
      var calls = 0;
      final c = container(
        '',
        tokens,
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      expect(c.read(aiProviderSettingsProvider).keyConfigured, isTrue);
      expect(c.read(aiBackendUriProvider), isNull);
      expect(
        c.read(aiAssistantGatewayProvider),
        isA<UnavailableAiAssistantGateway>(),
      );
      await c
          .read(aiAssistantControllerProvider.notifier)
          .send('Question', context);
      expect(tokens.calls, 0);
      expect(calls, 0);
      expect(
        c.read(aiAssistantControllerProvider).error,
        AiAssistantErrorCategory.backendConfiguration,
      );
      expect(logs, ['[focusday.ai] backend_url_missing']);
    },
  );
  test(
    'V1 default gateway authenticates without a personal OpenAI key',
    () async {
      final tokens = _Tokens();
      var calls = 0;
      final client = MockClient((incoming) async {
        calls++;
        expect(incoming.url.path, '/api/ai/respond');
        expect(incoming.headers['authorization'], 'Bearer offline-token');
        expect(incoming.headers.containsKey('x-focusday-openai-key'), isFalse);
        final body = jsonDecode(incoming.body) as Map;
        expect(body.containsKey('providerMode'), isFalse);
        expect(body['context'], context.toJson());
        return http.Response('{"text":"Advice","proposedActions":[]}', 200);
      });
      final c = ProviderContainer(
        overrides: [
          aiBackendUrlProvider.overrideWithValue('https://gateway.example'),
          aiIdTokenProvider.overrideWithValue(tokens),
          aiPersonalKeyReaderProvider.overrideWith(
            (ref) => throw StateError('V1 must not read personal keys'),
          ),
          aiHttpClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(client.close);
      await c
          .read(aiAssistantControllerProvider.notifier)
          .send('Question', context);
      expect(calls, 1);
      expect(c.read(aiAssistantControllerProvider).error, isNull);
      expect(
        c.read(aiAssistantControllerProvider).messages.last.text,
        'Advice',
      );
    },
  );

  var invalidCase = 0;
  for (final url in [
    'not-a-url',
    'http://remote.example',
    'https://',
    'https://host.test?key=PRIVATE',
    'https://user:PRIVATE@host.test',
    'https://host.test/#PRIVATE',
  ]) {
    test(
      'rejects invalid backend configuration without logging it: case ${invalidCase++}',
      () async {
        final tokens = _Tokens();
        var calls = 0;
        final c = container(
          url,
          tokens,
          MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        await c
            .read(aiAssistantControllerProvider.notifier)
            .send('Question', context);
        expect(tokens.calls, 0);
        expect(calls, 0);
        expect(logs, ['[focusday.ai] backend_url_invalid']);
        expect(logs.join(), isNot(contains('PRIVATE')));
      },
    );
  }
  for (final url in [
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'https://backend.example.test',
  ]) {
    test(
      'real Riverpod gateway reaches fake HTTP with explicit safe URL $url',
      () async {
        final tokens = _Tokens();
        var calls = 0;
        final c = container(
          url,
          tokens,
          MockClient((incoming) async {
            calls++;
            expect(incoming.url.path, '/api/ai/respond');
            expect(incoming.headers['x-focusday-openai-key'], 'offline-key');
            expect(incoming.headers['authorization'], 'Bearer offline-token');
            expect(jsonDecode(incoming.body)['providerMode'], 'personalOpenAi');
            return http.Response('{"text":"Advice","proposedActions":[]}', 200);
          }),
        );
        expect(
          c.read(aiAssistantGatewayProvider),
          isA<HttpAiAssistantGateway>(),
        );
        await c
            .read(aiAssistantControllerProvider.notifier)
            .send('Question', context);
        expect(tokens.calls, 1);
        expect(calls, 1);
        expect(c.read(aiAssistantControllerProvider).error, isNull);
        expect(logs, isEmpty);
      },
    );
  }
  test('missing session key is distinct from backend URL failure', () async {
    final tokens = _Tokens();
    var calls = 0;
    final c = container(
      'https://backend.example.test',
      tokens,
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
      key: null,
    );
    await c
        .read(aiAssistantControllerProvider.notifier)
        .send('Question', context);
    expect(tokens.calls, 0);
    expect(calls, 0);
    expect(logs, ['[focusday.ai] personal_key_missing']);
  });
  test(
    'Firebase missing user and failed token have separate safe diagnostics',
    () async {
      for (final failed in [false, true]) {
        logs.clear();
        final tokens = _Tokens()
          ..value = null
          ..fail = failed;
        var calls = 0;
        final c = container(
          'https://backend.example.test',
          tokens,
          MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        await c
            .read(aiAssistantControllerProvider.notifier)
            .send('Question', context);
        expect(calls, 0);
        expect(logs, [
          '[focusday.ai] ${failed ? "firebase_token_failed" : "firebase_user_missing"}',
        ]);
        expect(logs.join(), isNot(contains('PRIVATE_TOKEN_ERROR')));
      }
    },
  );
  test(
    'transport and backend response failures never log raw exception or payload',
    () async {
      for (final failed in [false, true]) {
        logs.clear();
        final c = container(
          'https://backend.example.test',
          _Tokens(),
          MockClient((_) async {
            if (failed) throw http.ClientException('PRIVATE_HTTP_ERROR');
            return http.Response('PRIVATE_BODY', 503);
          }),
        );
        await c
            .read(aiAssistantControllerProvider.notifier)
            .send('Question', context);
        expect(logs, [
          '[focusday.ai] ${failed ? "http_request_failed" : "backend_response_error"}',
        ]);
      }
    },
  );
  test(
    'repeated retries preserve one user bubble and exactly the previous payload',
    () async {
      final bodies = <String>[];
      final c = container(
        'https://backend.example.test',
        _Tokens(),
        MockClient((incoming) async {
          bodies.add(incoming.body);
          return bodies.length < 3
              ? http.Response('{}', 503)
              : http.Response('{"text":"OK"}', 200);
        }),
      );
      final controller = c.read(aiAssistantControllerProvider.notifier);
      await controller.send(request.message, request.context);
      await controller.retry();
      await controller.retry();
      await controller
          .retry(); // Success cannot be retried as a technical failure.
      expect(bodies, hasLength(3));
      expect(bodies.toSet(), hasLength(1));
      expect(
        c
            .read(aiAssistantControllerProvider)
            .messages
            .where((m) => m.role == AiChatRole.user),
        hasLength(1),
      );
      expect(
        c
            .read(aiAssistantControllerProvider)
            .messages
            .where((m) => m.role == AiChatRole.assistant),
        hasLength(1),
      );
    },
  );
}
