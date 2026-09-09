import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../application/ai_assistant_gateway.dart';
import '../domain/ai_assistant_models.dart';

abstract interface class FirebaseIdTokenProvider {
  Future<String?> getIdToken();
}

class FirebaseAuthIdTokenProvider implements FirebaseIdTokenProvider {
  FirebaseAuthIdTokenProvider(this.auth);
  final FirebaseAuth auth;

  @override
  Future<String?> getIdToken() async => await auth.currentUser?.getIdToken();
}

class HttpAiAssistantGateway implements AiAssistantGateway {
  HttpAiAssistantGateway({
    required Uri baseUri,
    required this.tokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _endpoint = baseUri.resolve('/api/ai/respond'),
       _client = client ?? http.Client();

  final Uri _endpoint;
  final FirebaseIdTokenProvider tokenProvider;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<AiResponse> respond(AiRequest request) async {
    final token = await tokenProvider.getIdToken();
    if (token == null || token.trim().isEmpty) {
      throw const AiAssistantException(
        AiAssistantErrorCategory.unauthenticated,
      );
    }
    try {
      final response = await _client
          .post(
            _endpoint,
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AiAssistantException(
          _categoryForStatus(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiAssistantException(AiAssistantErrorCategory.serverError);
      }
      return AiResponse.fromJson(decoded);
    } on TimeoutException {
      throw const AiAssistantException(AiAssistantErrorCategory.timeout);
    } on AiAssistantException {
      rethrow;
    } on http.ClientException {
      throw const AiAssistantException(AiAssistantErrorCategory.unavailable);
    } on FormatException {
      throw const AiAssistantException(AiAssistantErrorCategory.serverError);
    }
  }

  AiAssistantErrorCategory _categoryForStatus(int status) => switch (status) {
    400 => AiAssistantErrorCategory.invalidRequest,
    401 => AiAssistantErrorCategory.unauthenticated,
    408 => AiAssistantErrorCategory.timeout,
    429 => AiAssistantErrorCategory.rateLimited,
    503 => AiAssistantErrorCategory.unavailable,
    _ => AiAssistantErrorCategory.serverError,
  };
}
