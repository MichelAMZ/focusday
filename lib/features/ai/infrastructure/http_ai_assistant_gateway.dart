import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../application/ai_assistant_gateway.dart';
import '../application/ai_diagnostics.dart';
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
    this.personalKey,
  }) : _baseUri = baseUri,
       _endpoint = baseUri.resolve('/api/ai/respond'),
       _client = client ?? http.Client();

  final Uri _endpoint;
  final Uri _baseUri;
  final FirebaseIdTokenProvider tokenProvider;
  final http.Client _client;
  final Duration timeout;
  final String? Function()? personalKey;
  void close() => _client.close();

  @override
  Future<AiResponse> respond(AiRequest request) async {
    final key = personalKey?.call();
    if (personalKey != null) {
      if (key == null || key.isEmpty) {
        throw const AiAssistantException(
          AiAssistantErrorCategory.unavailable,
          reason: AiDiagnosticReason.personalKeyMissing,
        );
      }
      if (!isValidAiBackendUri(_baseUri)) {
        throw const AiAssistantException(
          AiAssistantErrorCategory.backendConfiguration,
          reason: AiDiagnosticReason.backendUrlInvalid,
        );
      }
    }
    String? token;
    try {
      token = await tokenProvider.getIdToken().timeout(timeout);
    } catch (_) {
      throw const AiAssistantException(
        AiAssistantErrorCategory.unauthenticated,
        reason: AiDiagnosticReason.firebaseTokenFailed,
      );
    }
    if (token == null || token.trim().isEmpty) {
      throw const AiAssistantException(
        AiAssistantErrorCategory.unauthenticated,
        reason: AiDiagnosticReason.firebaseUserMissing,
      );
    }
    try {
      // Recheck session ownership after awaiting Firebase. Never follow redirects with credentials.
      if (personalKey != null && personalKey!() != key) {
        throw const AiAssistantException(
          AiAssistantErrorCategory.unauthenticated,
          reason: AiDiagnosticReason.personalKeyMissing,
        );
      }
      final outgoing = http.Request('POST', _endpoint)
        ..followRedirects = false
        ..headers.addAll({
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
          if (personalKey != null) 'x-focusday-openai-key': key!,
        })
        ..body = jsonEncode({
          ...request.toJson(),
          if (personalKey != null) 'providerMode': 'personalOpenAi',
        });
      final response = await _client
          .send(outgoing)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) {
        if (personalKey != null && response.statusCode == 429) {
          throw const AiAssistantException(
            AiAssistantErrorCategory.personalQuota,
            reason: AiDiagnosticReason.backendResponseError,
          );
        }
        if (personalKey != null && response.statusCode == 403) {
          throw const AiAssistantException(
            AiAssistantErrorCategory.personalAccess,
            reason: AiDiagnosticReason.backendResponseError,
          );
        }
        throw AiAssistantException(
          _categoryForStatus(response.statusCode),
          statusCode: response.statusCode,
          reason: AiDiagnosticReason.backendResponseError,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiAssistantException(
          AiAssistantErrorCategory.serverError,
          reason: AiDiagnosticReason.backendResponseError,
        );
      }
      return AiResponse.fromJson(decoded);
    } on TimeoutException {
      throw const AiAssistantException(
        AiAssistantErrorCategory.timeout,
        reason: AiDiagnosticReason.httpRequestFailed,
      );
    } on AiAssistantException catch (error) {
      throw AiAssistantException(
        error.category,
        statusCode: error.statusCode,
        reason: error.reason ?? AiDiagnosticReason.backendResponseError,
      );
    } on http.ClientException {
      throw const AiAssistantException(
        AiAssistantErrorCategory.unavailable,
        reason: AiDiagnosticReason.httpRequestFailed,
      );
    } on FormatException {
      throw const AiAssistantException(
        AiAssistantErrorCategory.serverError,
        reason: AiDiagnosticReason.backendResponseError,
      );
    } catch (_) {
      throw const AiAssistantException(
        AiAssistantErrorCategory.unavailable,
        reason: AiDiagnosticReason.httpRequestFailed,
      );
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

class UnavailableAiAssistantGateway implements AiAssistantGateway {
  const UnavailableAiAssistantGateway({
    this.reason = AiDiagnosticReason.gatewayNotCreated,
    this.category = AiAssistantErrorCategory.unavailable,
  });
  final AiDiagnosticReason reason;
  final AiAssistantErrorCategory category;
  @override
  Future<AiResponse> respond(AiRequest request) async =>
      throw AiAssistantException(category, reason: reason);
}
