import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/projects/domain/focus_project.dart';
import '../../features/today/application/focus_timer_state.dart';
import 'sync_cloud_gateway.dart';
import 'account_sync_gateway.dart';
import 'account_sync_models.dart';

class FocusDayCloudStorage implements SyncCloudGateway, AccountSyncGateway {
  FocusDayCloudStorage(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _projects(String userId) {
    return firestore.collection('users').doc(userId).collection('projects');
  }

  DocumentReference<Map<String, dynamic>> _settings(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('preferences');
  DocumentReference<Map<String, dynamic>> _focus(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('focus')
      .doc('current');

  @override
  Future<CloudValue<SyncedSettings>?> loadSettings(String userId) async {
    final data = (await _settings(userId).get()).data();
    final updatedAt = data?['updatedAt'];
    if (data == null) return null;
    return CloudValue(
      SyncedSettings(
        completionSoundEnabled: data['completionSoundEnabled'] as bool? ?? true,
        scheduledProjectAlertsEnabled:
            data['scheduledProjectAlertsEnabled'] as bool? ?? true,
        languagePreference: data['languagePreference'] as String? ?? 'system',
      ),
      updatedAt is Timestamp ? updatedAt.toDate().toUtc() : null,
      generation: data['generation'] as int? ?? 0,
    );
  }

  @override
  Future<CloudWriteResult> saveSettings(
    String userId,
    SyncedSettings value, {
    required int? expectedGeneration,
    bool force = false,
  }) async {
    final reference = _settings(userId);
    final generation = await _writeVersionedDocument(
      reference,
      expectedGeneration: expectedGeneration,
      force: force,
      data: {
        'schemaVersion': 1,
        'completionSoundEnabled': value.completionSoundEnabled,
        'scheduledProjectAlertsEnabled': value.scheduledProjectAlertsEnabled,
        'languagePreference': value.languagePreference,
      },
    );
    return CloudWriteResult(
      generation: generation,
      updatedAt: await _readResolvedUpdatedAt(reference),
    );
  }

  @override
  Future<CloudValue<CloudFocusState>?> loadFocus(String userId) async {
    final data = (await _focus(userId).get()).data();
    final updatedAt = data?['updatedAt'];
    if (data == null) return null;
    final statusName = data['status'] as String? ?? FocusTimerStatus.idle.name;
    final status = FocusTimerStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => FocusTimerStatus.idle,
    );
    return CloudValue(
      CloudFocusState(
        projectId: data['projectId'] as String? ?? 'bogoka',
        status: status,
        initialSeconds: data['initialSeconds'] as int? ?? 3600,
        remainingSecondsWhenPaused: data['remainingSecondsWhenPaused'] as int?,
        endsAt: (data['endsAt'] as Timestamp?)?.toDate().toUtc(),
      ),
      updatedAt is Timestamp ? updatedAt.toDate().toUtc() : null,
      generation: data['generation'] as int? ?? 0,
    );
  }

  @override
  Future<CloudWriteResult> saveFocus(
    String userId,
    CloudFocusState value, {
    required int? expectedGeneration,
    bool force = false,
  }) async {
    final reference = _focus(userId);
    final generation = await _writeVersionedDocument(
      reference,
      expectedGeneration: expectedGeneration,
      force: force,
      data: {
        'schemaVersion': 1,
        'projectId': value.projectId,
        'status': value.status.name,
        'initialSeconds': value.initialSeconds,
        'remainingSecondsWhenPaused': value.remainingSecondsWhenPaused,
        'endsAt': value.endsAt == null
            ? null
            : Timestamp.fromDate(value.endsAt!),
      },
    );
    return CloudWriteResult(
      generation: generation,
      updatedAt: await _readResolvedUpdatedAt(reference),
    );
  }

  Future<DateTime?> _readResolvedUpdatedAt(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final value = (await reference.get()).data()?['updatedAt'];
    return value is Timestamp ? value.toDate().toUtc() : null;
  }

  DocumentReference<Map<String, dynamic>> _syncState(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('sync')
        .doc('state');
  }

  Future<Map<String, dynamic>?> loadSyncState(String userId) async {
    final snapshot = await _syncState(userId).get();
    return snapshot.data();
  }

  @override
  Future<DateTime?> loadLastSyncAt(String userId) async {
    final state = await loadSyncState(userId);
    final value = state?['lastSyncAt'];

    if (value is Timestamp) {
      return value.toDate().toUtc();
    }

    return null;
  }

  Future<void> saveSyncState({
    required String userId,
    required int projectCount,
  }) async {
    await _syncState(userId).set({
      'schemaVersion': 1,
      'projectCount': projectCount,
      'lastSyncAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<FocusProject>> loadProjects(String userId) async {
    final snapshot = await _projects(userId).get();

    return snapshot.docs
        .map((document) => FocusProject.fromJson(document.data()))
        .toList();
  }

  @override
  Future<int> loadProjectsGeneration(String userId) async {
    final state = await loadSyncState(userId);
    return state?['projectsGeneration'] as int? ?? 0;
  }

  @override
  Future<CloudProjectsSnapshot> loadProjectsSnapshot(String userId) async {
    // A collection query cannot be issued through a FlutterFire transaction.
    // Bracket it with state reads instead: project writes and the generation
    // change commit atomically, so equal generations prove that the queried
    // snapshot belongs to one stable version.
    for (var attempt = 0; attempt < 3; attempt++) {
      final before = await loadSyncState(userId);
      final generation = before?['projectsGeneration'] as int? ?? 0;
      final projects = await loadProjects(userId);
      final after = await loadSyncState(userId);
      final generationAfter = after?['projectsGeneration'] as int? ?? 0;
      if (generation == generationAfter) {
        return CloudProjectsSnapshot(
          projects: projects,
          generation: generation,
          updatedAt: (after?['lastSyncAt'] as Timestamp?)?.toDate().toUtc(),
        );
      }
    }
    throw StateError('Le snapshot cloud a changé pendant sa lecture.');
  }

  @override
  Future<CloudWriteResult> saveProjects(
    String userId,
    List<FocusProject> projects, {
    required int? expectedGeneration,
    bool force = false,
  }) async {
    final collection = _projects(userId);
    // Legacy accounts may not have projectIds in sync/state. This snapshot is
    // used only for that one-time migration path. The state document remains
    // the CAS authority: a concurrent compliant writer changes its generation,
    // causing Firestore to retry and reject a stale expectedGeneration before
    // fallbackIds can be used.
    final existing = await collection.get();
    final fallbackIds = existing.docs.map((document) => document.id).toSet();
    final stateReference = _syncState(userId);
    final newGeneration = await firestore.runTransaction<int>((
      transaction,
    ) async {
      final state = (await transaction.get(stateReference)).data();
      final currentGeneration = state?['projectsGeneration'] as int? ?? 0;
      if (!force && expectedGeneration != currentGeneration) {
        throw const CloudWriteConflict();
      }
      final existingIds =
          (state?['projectIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toSet() ??
          fallbackIds;
      final localIds = projects.map((project) => project.id).toSet();
      for (final project in projects) {
        transaction.set(collection.doc(project.id), {
          ...project.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      for (final id in existingIds.difference(localIds)) {
        transaction.delete(collection.doc(id));
      }
      final nextGeneration = currentGeneration + 1;
      transaction.set(stateReference, {
        'schemaVersion': 1,
        'projectCount': projects.length,
        'projectIds': localIds.toList(),
        'projectsGeneration': nextGeneration,
        'lastSyncAt': FieldValue.serverTimestamp(),
      });
      return nextGeneration;
    });
    return CloudWriteResult(
      generation: newGeneration,
      updatedAt: await _readResolvedUpdatedAt(stateReference),
    );
  }

  Future<int> _writeVersionedDocument(
    DocumentReference<Map<String, dynamic>> reference, {
    required int? expectedGeneration,
    required bool force,
    required Map<String, dynamic> data,
  }) {
    return firestore.runTransaction<int>((transaction) async {
      final current = (await transaction.get(reference)).data();
      final generation = current?['generation'] as int? ?? 0;
      if (!force && expectedGeneration != generation) {
        throw const CloudWriteConflict();
      }
      final nextGeneration = generation + 1;
      transaction.set(reference, {
        ...data,
        'generation': nextGeneration,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return nextGeneration;
    });
  }
}
