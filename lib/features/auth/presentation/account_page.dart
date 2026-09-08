import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_provider.dart';
import '../../../core/storage/storage_provider.dart';
import '../../today/application/today_controller.dart';
import '../application/auth_controller.dart';
import '../application/auth_gateway.dart';
import '../../../l10n/app_localizations.dart';

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

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final outcome = await ref.read(authControllerProvider).signInWithGoogle();
      if (mounted && outcome == GoogleSignInOutcome.cancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.googleSignInCancelled)));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_googleAuthMessage(error, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _googleAuthMessage(
    FirebaseAuthException error,
    AppLocalizations l10n,
  ) => switch (error.code) {
    'account-exists-with-different-credential' ||
    'credential-already-in-use' => l10n.googleAccountCollision,
    'network-request-failed' => l10n.googleNetworkError,
    'popup-blocked' => l10n.googlePopupBlocked,
    'operation-not-allowed' ||
    'unsupported-platform' => l10n.googleSignInUnavailable,
    'too-many-requests' => l10n.googleTooManyRequests,
    _ => l10n.googleSignInFailed,
  };

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

  Future<void> _backupProjectsToCloud(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projects = ref.read(todayProjectsProvider);
      final cloudStorage = ref.read(focusDayCloudStorageProvider);
      final localStorage = ref.read(focusDayStorageProvider);
      final uploadedRevision = localStorage?.loadProjectsRevision() ?? 0;

      await cloudStorage.saveProjects(user.uid, projects);

      final serverLastSyncAt = await cloudStorage.loadLastSyncAt(user.uid);
      if (serverLastSyncAt == null) {
        throw StateError(
          'Horodatage de synchronisation Firestore indisponible.',
        );
      }

      await localStorage?.saveLastSyncAt(serverLastSyncAt);
      await localStorage?.prepareSyncOwner(user.uid);
      await localStorage?.saveLastSyncedProjectsRevision(uploadedRevision);
      if (localStorage?.loadProjectsRevision() == uploadedRevision) {
        await localStorage?.saveProjectsUpdatedAt(serverLastSyncAt);
        await localStorage?.saveProjectsDirty(false);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${projects.length} projet(s) sauvegardé(s) dans le cloud.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la sauvegarde cloud : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreProjectsFromCloud(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cloudStorage = ref.read(focusDayCloudStorageProvider);
      final localStorage = ref.read(focusDayStorageProvider);
      final expectedRevision = localStorage?.loadProjectsRevision() ?? 0;
      final cloudProjects = await cloudStorage.loadProjects(user.uid);

      if (!mounted) {
        return;
      }

      if (cloudProjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun projet trouvé dans le cloud.')),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Restaurer depuis le cloud ?'),
            content: Text(
              '${cloudProjects.length} projet(s) trouvé(s) dans le cloud. '
              'Les projets actuellement présents sur cet appareil '
              'seront remplacés.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Restaurer'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      final applied = await ref
          .read(todayProjectsProvider.notifier)
          .replaceAllProjectsFromCloud(cloudProjects, expectedRevision);
      if (!applied) {
        throw StateError(
          'Les projets locaux ont changé pendant la restauration. '
          'Aucune version plus récente n’a été marquée comme synchronisée.',
        );
      }

      final serverLastSyncAt = await cloudStorage.loadLastSyncAt(user.uid);
      if (serverLastSyncAt == null) {
        throw StateError(
          'Horodatage de synchronisation Firestore indisponible.',
        );
      }

      await localStorage?.saveLastSyncAt(serverLastSyncAt);
      await localStorage?.prepareSyncOwner(user.uid);
      await localStorage?.saveLastSyncedProjectsRevision(expectedRevision);
      if (localStorage?.loadProjectsRevision() != expectedRevision) {
        throw StateError(
          'Les projets locaux ont changé pendant la restauration.',
        );
      }
      await localStorage?.saveProjectsUpdatedAt(serverLastSyncAt);
      await localStorage?.saveProjectsDirty(false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${cloudProjects.length} projet(s) restauré(s) depuis le cloud.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la restauration cloud : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSignedIn(User user) {
    final displayName = user.displayName?.trim();
    final email = user.email?.trim();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccountIdentityAvatar(
                  displayName: user.displayName,
                  email: user.email,
                  photoUrl: user.photoURL,
                ),
                const SizedBox(height: 16),
                Text(
                  'Compte connecté',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (displayName != null && displayName.isNotEmpty)
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (email != null && email.isNotEmpty) Text(email),
                if ((displayName == null || displayName.isEmpty) &&
                    (email == null || email.isEmpty))
                  const Text('Compte Firebase'),
                const SizedBox(height: 8),
                const Text(
                  'Vos projets restent enregistrés localement sur cet appareil.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _backupProjectsToCloud(user),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Sauvegarder dans le cloud'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _restoreProjectsFromCloud(user),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Restaurer depuis le cloud'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
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
    final l10n = AppLocalizations.of(context)!;
    final googleSignInAvailable = ref.watch(googleSignInAvailableProvider);
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
        if (googleSignInAvailable) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.authOrSeparator),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('google-sign-in-button'),
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: const Icon(Icons.login),
            label: Text(
              _isLoading ? l10n.googleSignInLoading : l10n.continueWithGoogle,
            ),
          ),
        ],
      ],
    );
  }
}

class AccountIdentityAvatar extends StatelessWidget {
  const AccountIdentityAvatar({
    super.key,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String? displayName;
  final String? email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = photoUrl?.trim();
    final label = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : email?.trim();
    final fallback = CircleAvatar(
      radius: 28,
      child: label == null || label.isEmpty
          ? const Icon(Icons.person_outline)
          : Text(label.substring(0, 1).toUpperCase()),
    );
    if (normalizedPhotoUrl == null || normalizedPhotoUrl.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        normalizedPhotoUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
