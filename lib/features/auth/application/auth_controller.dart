import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'auth_gateway.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(FirebaseAuthGateway(ref.watch(firebaseAuthProvider)));
});

final googleSignInAvailableProvider = Provider<bool>((ref) => kIsWeb);

class AuthController {
  const AuthController(this._auth);

  final AuthGateway _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmail(email: email, password: password);
  }

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createAccountWithEmail(email: email, password: password);
  }

  Future<GoogleSignInOutcome> signInWithGoogle() => _auth.signInWithGoogle();

  Future<void> signOut() {
    return _auth.signOut();
  }
}
