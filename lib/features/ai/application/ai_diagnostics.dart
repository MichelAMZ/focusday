import 'package:flutter/foundation.dart';

enum AiDiagnosticReason {
  providerNotConfigured,
  personalKeyMissing,
  firebaseUserMissing,
  firebaseTokenFailed,
  backendUrlMissing,
  backendUrlInvalid,
  gatewayNotCreated,
  httpRequestFailed,
  backendResponseError;

  String get code => switch (this) {
    providerNotConfigured => 'provider_not_configured',
    personalKeyMissing => 'personal_key_missing',
    firebaseUserMissing => 'firebase_user_missing',
    firebaseTokenFailed => 'firebase_token_failed',
    backendUrlMissing => 'backend_url_missing',
    backendUrlInvalid => 'backend_url_invalid',
    gatewayNotCreated => 'gateway_not_created',
    httpRequestFailed => 'http_request_failed',
    backendResponseError => 'backend_response_error',
  };
}

// Only fixed enum values can reach the DEBUG logger. No free-form payload.
void debugAiFailure(AiDiagnosticReason reason) {
  if (kDebugMode) debugPrint('[focusday.ai] ${reason.code}');
}

bool isValidAiBackendUri(Uri uri) =>
    uri.hasAuthority &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    !uri.hasQuery &&
    !uri.hasFragment &&
    (uri.scheme == 'https' ||
        (uri.scheme == 'http' &&
            {'localhost', '127.0.0.1', '::1'}.contains(uri.host)));
