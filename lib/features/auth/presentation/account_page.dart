import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Opération réussie.')));
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _firebaseMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Adresse e-mail invalide.',
      'invalid-credential' => 'E-mail ou mot de passe incorrect.',
      'user-disabled' => 'Ce compte a été désactivé.',
      'email-already-in-use' => 'Cette adresse e-mail est déjà utilisée.',
      'weak-password' => 'Le mot de passe est trop faible.',
      'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
      _ => error.message ?? 'Erreur d’authentification.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compte & Cloud')),
      body: authState.when(
        data: (user) {
          if (user != null) {
            return _buildSignedIn(user);
          }

          return _buildSignedOut();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Erreur : $error')),
      ),
    );
  }

  Widget _buildSignedIn(User user) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_done_outlined, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Compte connecté',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(user.email ?? 'Compte Firebase'),
                const SizedBox(height: 8),
                const Text(
                  'La sauvegarde cloud sera activée dans l’étape suivante.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _runAuthAction(
                            () => ref.read(authControllerProvider).signOut(),
                          );
                        },
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedOut() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Adresse e-mail',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _passwordVisible
                  ? 'Masquer le mot de passe'
                  : 'Afficher le mot de passe',
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _passwordVisible = !_passwordVisible;
                });
              },
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () {
                  _runAuthAction(() async {
                    await ref
                        .read(authControllerProvider)
                        .signInWithEmail(
                          email: _emailController.text,
                          password: _passwordController.text,
                        );
                  });
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Se connecter'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isLoading
              ? null
              : () {
                  _runAuthAction(() async {
                    await ref
                        .read(authControllerProvider)
                        .createAccountWithEmail(
                          email: _emailController.text,
                          password: _passwordController.text,
                        );
                  });
                },
          child: const Text('Créer un compte'),
        ),
      ],
    );
  }
}
