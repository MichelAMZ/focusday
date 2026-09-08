import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:focusday/features/auth/application/auth_controller.dart';
import 'package:focusday/features/auth/application/auth_gateway.dart';

class FakeAuthGateway implements AuthGateway {
  String? email;
  int signInCalls = 0;
  int createCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;
  GoogleSignInOutcome googleOutcome = GoogleSignInOutcome.signedIn;

  @override
  User? get currentUser => null;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    this.email = email;
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async => createCalls++;

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    googleCalls++;
    return googleOutcome;
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

void main() {
  test('email sign-in remains delegated', () async {
    final gateway = FakeAuthGateway();
    await AuthController(
      gateway,
    ).signInWithEmail(email: 'user@example.com', password: 'secret');
    expect(gateway.signInCalls, 1);
    expect(gateway.email, 'user@example.com');
  });

  test('email account creation remains delegated', () async {
    final gateway = FakeAuthGateway();
    await AuthController(
      gateway,
    ).createAccountWithEmail(email: 'user@example.com', password: 'secret');
    expect(gateway.createCalls, 1);
  });

  test('sign-out remains delegated without touching local storage', () async {
    final gateway = FakeAuthGateway();
    await AuthController(gateway).signOut();
    expect(gateway.signOutCalls, 1);
  });

  test('Google result is propagated by the controller', () async {
    final gateway = FakeAuthGateway()
      ..googleOutcome = GoogleSignInOutcome.cancelled;
    expect(
      await AuthController(gateway).signInWithGoogle(),
      GoogleSignInOutcome.cancelled,
    );
    expect(gateway.googleCalls, 1);
  });

  test('Web uses popup and Windows remains unsupported', () {
    expect(
      selectGoogleAuthFlow(isWeb: true, targetPlatform: TargetPlatform.windows),
      GoogleAuthFlow.webPopup,
    );
    expect(
      selectGoogleAuthFlow(
        isWeb: false,
        targetPlatform: TargetPlatform.windows,
      ),
      GoogleAuthFlow.unsupported,
    );
  });

  test('Google popup cancellation codes are non-errors', () {
    expect(isGoogleSignInCancellationCode('popup-closed-by-user'), isTrue);
    expect(isGoogleSignInCancellationCode('cancelled-popup-request'), isTrue);
    expect(isGoogleSignInCancellationCode('network-request-failed'), isFalse);
  });
}
