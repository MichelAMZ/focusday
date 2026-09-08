import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum GoogleSignInOutcome { signedIn, cancelled }

enum GoogleAuthFlow { webPopup, unsupported }

GoogleAuthFlow selectGoogleAuthFlow({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return GoogleAuthFlow.webPopup;
  return GoogleAuthFlow.unsupported;
}

bool isGoogleSignInCancellationCode(String code) => const {
  'popup-closed-by-user',
  'cancelled-popup-request',
  'web-context-cancelled',
  'canceled',
  'cancelled',
}.contains(code);

abstract interface class AuthGateway {
  User? get currentUser;
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  });
  Future<GoogleSignInOutcome> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  const FirebaseAuthGateway(this._auth, {this.isWeb, this.targetPlatform});

  final FirebaseAuth _auth;
  final bool? isWeb;
  final TargetPlatform? targetPlatform;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      switch (selectGoogleAuthFlow(
        isWeb: isWeb ?? kIsWeb,
        targetPlatform: targetPlatform ?? defaultTargetPlatform,
      )) {
        case GoogleAuthFlow.webPopup:
          await _auth.signInWithPopup(provider);
        case GoogleAuthFlow.unsupported:
          throw FirebaseAuthException(
            code: 'unsupported-platform',
            message: 'Google Sign-In is not configured for this platform.',
          );
      }
      return GoogleSignInOutcome.signedIn;
    } on FirebaseAuthException catch (error) {
      if (isGoogleSignInCancellationCode(error.code)) {
        return GoogleSignInOutcome.cancelled;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
