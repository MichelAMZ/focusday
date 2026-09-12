import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/ai/infrastructure/http_ai_assistant_gateway.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const context = AiAssistantContext(language: 'fr', focusRemainingSeconds: 90);
  const request = AiRequest(message: 'Aide-moi', context: context);

  test(
    'personal key travels only in its header over HTTPS with redirects disabled',
    () async {
      final client = MockClient((incoming) async {
        expect(
          incoming.url.toString(),
          'https://gateway.example.test/api/ai/respond',
        );
        expect(incoming.followRedirects, isFalse);
        expect(incoming.headers['authorization'], 'Bearer firebase-token');
        expect(incoming.headers['x-focusday-openai-key'], 'offline-key');
        expect(incoming.body, isNot(contains('offline-key')));
        expect(incoming.url.toString(), isNot(contains('offline-key')));
        expect(jsonDecode(incoming.body)['providerMode'], 'personalOpenAi');
        return http.Response('{"text":"OK"}', 200);
      });
      final personal = HttpAiAssistantGateway(
        baseUri: Uri.parse('https://gateway.example.test'),
        tokenProvider: _FakeTokenProvider('firebase-token'),
        client: client,
        personalKey: () => 'offline-key',
      );
      await personal.respond(request);
    },
  );
  test(
    'rejects remote plaintext and missing personal key before network',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      for (final uri in [
        'http://remote.example',
        'https://gateway.example.test',
      ]) {
        final personal = HttpAiAssistantGateway(
          baseUri: Uri.parse(uri),
          tokenProvider: _FakeTokenProvider('token'),
          client: client,
          personalKey: () => uri.startsWith('https') ? null : 'offline-key',
        );
        await expectLater(
          personal.respond(request),
          _throws(
            uri.startsWith('https')
                ? AiAssistantErrorCategory.unavailable
                : AiAssistantErrorCategory.backendConfiguration,
          ),
        );
      }
      expect(calls, 0);
    },
  );
  test('allows explicit localhost HTTP for development', () async {
    var calls = 0;
    final personal = HttpAiAssistantGateway(
      baseUri: Uri.parse('http://localhost:8080'),
      tokenProvider: _FakeTokenProvider('token'),
      personalKey: () => 'offline-key',
      client: MockClient((_) async {
        calls++;
        return http.Response('{"text":"OK"}', 200);
      }),
    );
    await personal.respond(request);
    expect(calls, 1);
  });
  test(
    'does not send a key after identity changes while waiting for Firebase',
    () async {
      final token = Completer<String?>();
      String? key = 'offline-key';
      var calls = 0;
      final personal = HttpAiAssistantGateway(
        baseUri: Uri.parse('https://gateway.example.test'),
        tokenProvider: _DelayedToken(token.future),
        personalKey: () => key,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final pending = personal.respond(request);
      key = null;
      token.complete('old-firebase-token');
      await expectLater(
        pending,
        _throws(AiAssistantErrorCategory.unauthenticated),
      );
      expect(calls, 0);
    },
  );
  for (final status in [429, 403]) {
    test(
      'personal provider status $status has a user-facing category',
      () async {
        final personal = HttpAiAssistantGateway(
          baseUri: Uri.parse('https://gateway.example.test'),
          tokenProvider: _FakeTokenProvider('token'),
          personalKey: () => 'offline-key',
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(
          personal.respond(request),
          _throws(
            status == 429
                ? AiAssistantErrorCategory.personalQuota
                : AiAssistantErrorCategory.personalAccess,
          ),
        );
      },
    );
  }

  HttpAiAssistantGateway gateway(
    MockClient client, {
    String? token = 'firebase-token',
    Duration timeout = const Duration(seconds: 1),
  }) => HttpAiAssistantGateway(
    baseUri: Uri.parse('https://gateway.example.test'),
    tokenProvider: _FakeTokenProvider(token),
    client: client,
    timeout: timeout,
  );

  test('adds Firebase ID token as Bearer authorization', () async {
    final client = MockClient((incoming) async {
      expect(incoming.headers['authorization'], 'Bearer firebase-token');
      return http.Response('{"text":"OK"}', 200);
    });
    await gateway(client).respond(request);
  });

  test('rejects absence of authenticated user before network', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });
    await expectLater(
      gateway(client, token: null).respond(request),
      _throws(AiAssistantErrorCategory.unauthenticated),
    );
    expect(called, isFalse);
  });

  test('serializes AiRequest and targets the configured endpoint', () async {
    final client = MockClient((incoming) async {
      expect(incoming.url.path, '/api/ai/respond');
      expect(jsonDecode(incoming.body), request.toJson());
      return http.Response('{"text":"OK"}', 200);
    });
    await gateway(client).respond(request);
  });

  test('maps 400 to invalidRequest', () async {
    await expectLater(
      gateway(
        MockClient((_) async => http.Response('{}', 400)),
      ).respond(request),
      _throws(AiAssistantErrorCategory.invalidRequest),
    );
  });

  test('maps 401 to unauthenticated', () async {
    await expectLater(
      gateway(
        MockClient((_) async => http.Response('{}', 401)),
      ).respond(request),
      _throws(AiAssistantErrorCategory.unauthenticated),
    );
  });

  test('maps 408 to timeout', () async {
    await expectLater(
      gateway(
        MockClient((_) async => http.Response('{}', 408)),
      ).respond(request),
      _throws(AiAssistantErrorCategory.timeout),
    );
  });

  test('maps 429 to rateLimited', () async {
    await expectLater(
      gateway(
        MockClient((_) async => http.Response('{}', 429)),
      ).respond(request),
      _throws(AiAssistantErrorCategory.rateLimited),
    );
  });

  test('maps 503 to unavailable', () async {
    await expectLater(
      gateway(
        MockClient((_) async => http.Response('{}', 503)),
      ).respond(request),
      _throws(AiAssistantErrorCategory.unavailable),
    );
  });

  test('maps 500 to serverError without parsing its body', () async {
    await expectLater(
      gateway(
        MockClient((_) async => http.Response('sensitive upstream body', 500)),
      ).respond(request),
      _throws(AiAssistantErrorCategory.serverError),
    );
  });

  test('maps network timeout to timeout', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    await expectLater(
      gateway(
        client,
        timeout: const Duration(milliseconds: 1),
      ).respond(request),
      _throws(AiAssistantErrorCategory.timeout),
    );
  });

  test('parses successful response and minimal metadata', () async {
    final response = await gateway(
      MockClient(
        (_) async => http.Response(
          '{"text":"Conseil","conversationId":"conv","metadata":{"requestId":"req"}}',
          200,
        ),
      ),
    ).respond(request);
    expect(response.text, 'Conseil');
    expect(response.conversationId, 'conv');
    expect(response.metadata.requestId, 'req');
  });

  test('requires no OpenAI credential in Flutter gateway', () async {
    final client = MockClient((incoming) async {
      expect(incoming.headers.keys, isNot(contains('x-api-key')));
      expect(incoming.body, isNot(contains('OPENAI')));
      return http.Response('{"text":"OK"}', 200);
    });
    await gateway(client).respond(request);
  });
}

Matcher _throws(AiAssistantErrorCategory category) => throwsA(
  isA<AiAssistantException>().having(
    (error) => error.category,
    'category',
    category,
  ),
);

class _FakeTokenProvider implements FirebaseIdTokenProvider {
  const _FakeTokenProvider(this.token);
  final String? token;

  @override
  Future<String?> getIdToken() async => token;
}

class _DelayedToken implements FirebaseIdTokenProvider {
  _DelayedToken(this.token);
  final Future<String?> token;
  @override
  Future<String?> getIdToken() => token;
}
