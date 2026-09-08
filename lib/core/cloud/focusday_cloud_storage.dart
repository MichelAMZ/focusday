import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/projects/domain/focus_project.dart';
import 'sync_cloud_gateway.dart';

class FocusDayCloudStorage implements SyncCloudGateway {
  FocusDayCloudStorage(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _projects(String userId) {
    return firestore.collection('users').doc(userId).collection('projects');
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
