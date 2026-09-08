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
    if (data == null || updatedAt is! Timestamp) return null;
    return CloudValue(
      SyncedSettings(
        completionSoundEnabled: data['completionSoundEnabled'] as bool? ?? true,
        scheduledProjectAlertsEnabled:
            data['scheduledProjectAlertsEnabled'] as bool? ?? true,
        languagePreference: data['languagePreference'] as String? ?? 'system',
      ),
      updatedAt.toDate().toUtc(),
    );
  }

  @override
  Future<DateTime> saveSettings(String userId, SyncedSettings value) async {
    final reference = _settings(userId);
    await reference.set({
      'schemaVersion': 1,
      'completionSoundEnabled': value.completionSoundEnabled,
      'scheduledProjectAlertsEnabled': value.scheduledProjectAlertsEnabled,
      'languagePreference': value.languagePreference,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return _readUpdatedAt(reference);
  }

  @override
  Future<CloudValue<CloudFocusState>?> loadFocus(String userId) async {
    final data = (await _focus(userId).get()).data();
    final updatedAt = data?['updatedAt'];
    if (data == null || updatedAt is! Timestamp) return null;
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
      updatedAt.toDate().toUtc(),
    );
  }

  @override
  Future<DateTime> saveFocus(String userId, CloudFocusState value) async {
    final reference = _focus(userId);
    await reference.set({
      'schemaVersion': 1,
      'projectId': value.projectId,
      'status': value.status.name,
      'initialSeconds': value.initialSeconds,
      'remainingSecondsWhenPaused': value.remainingSecondsWhenPaused,
      'endsAt': value.endsAt == null ? null : Timestamp.fromDate(value.endsAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return _readUpdatedAt(reference);
  }

  Future<DateTime> _readUpdatedAt(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final value = (await reference.get()).data()?['updatedAt'];
    if (value is! Timestamp) {
      throw StateError(
        'Horodatage serveur indisponible après synchronisation.',
      );
    }
    return value.toDate().toUtc();
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
  Future<void> saveProjects(String userId, List<FocusProject> projects) async {
    final collection = _projects(userId);
    final existing = await collection.get();
    final localIds = projects.map((project) => project.id).toSet();

    final batch = firestore.batch();

    for (final project in projects) {
      batch.set(collection.doc(project.id), {
        ...project.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    for (final document in existing.docs) {
      if (!localIds.contains(document.id)) {
        batch.delete(document.reference);
      }
    }

    batch.set(_syncState(userId), {
      'schemaVersion': 1,
      'projectCount': projects.length,
      'lastSyncAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
