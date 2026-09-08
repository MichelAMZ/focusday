import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/auth/application/auth_controller.dart';
import 'package:focusday/features/auth/application/auth_gateway.dart';
import 'package:focusday/features/auth/presentation/account_page.dart';
import 'package:focusday/l10n/app_localizations.dart';

class WidgetAuthGateway implements AuthGateway {
  int googleCalls = 0;
  Completer<GoogleSignInOutcome>? pendingGoogle;
  FirebaseAuthException? googleError;

  @override
  User? get currentUser => null;
  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() {
    googleCalls++;
    if (googleError case final error?) return Future.error(error);
    return pendingGoogle?.future ?? Future.value(GoogleSignInOutcome.signedIn);
  }
}

Widget buildAccountPage(
  WidgetAuthGateway gateway, {
  bool googleAvailable = true,
}) => ProviderScope(
  overrides: [
    authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
    authControllerProvider.overrideWithValue(AuthController(gateway)),
    googleSignInAvailableProvider.overrideWithValue(googleAvailable),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: AccountPage(),
  ),
);

void main() {
  testWidgets('Google button is visible while signed out', (tester) async {
    await tester.pumpWidget(buildAccountPage(WidgetAuthGateway()));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Google button is hidden on unsupported platforms', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildAccountPage(WidgetAuthGateway(), googleAvailable: false),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('google-sign-in-button')), findsNothing);
  });

  testWidgets('Google button cannot trigger twice while loading', (
    tester,
  ) async {
    final gateway = WidgetAuthGateway()
      ..pendingGoogle = Completer<GoogleSignInOutcome>();
    await tester.pumpWidget(buildAccountPage(gateway));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('google-sign-in-button'));
    await tester.tap(button);
    await tester.pump();
    expect(gateway.googleCalls, 1);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    expect(gateway.googleCalls, 1);
    gateway.pendingGoogle!.complete(GoogleSignInOutcome.signedIn);
    await tester.pumpAndSettle();
  });

  testWidgets('Google cancellation is handled as a neutral message', (
    tester,
  ) async {
    final gateway = WidgetAuthGateway()
      ..pendingGoogle = Completer<GoogleSignInOutcome>()
      ..pendingGoogle!.complete(GoogleSignInOutcome.cancelled);
    await tester.pumpWidget(buildAccountPage(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-sign-in-button')));
    await tester.pumpAndSettle();
    expect(find.text('Google sign-in cancelled.'), findsOneWidget);
  });

  testWidgets('account collision has a safe user-facing message', (
    tester,
  ) async {
    final gateway = WidgetAuthGateway()
      ..googleError = FirebaseAuthException(
        code: 'account-exists-with-different-credential',
      );
    await tester.pumpWidget(buildAccountPage(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-sign-in-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('An account already exists with another sign-in method.'),
      findsOneWidget,
    );
  });

  testWidgets('identity avatar falls back without a photo URL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountIdentityAvatar(
            displayName: 'Google User',
            email: 'user@example.com',
          ),
        ),
      ),
    );
    expect(find.text('G'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
