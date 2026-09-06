import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/projects/domain/focus_project.dart';

class FocusDayCloudStorage {
  FocusDayCloudStorage(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _projects(String userId) {
    return firestore.collection('users').doc(userId).collection('projects');
  }

  Future<List<FocusProject>> loadProjects(String userId) async {
    final snapshot = await _projects(userId).get();

    return snapshot.docs
        .map((document) => FocusProject.fromJson(document.data()))
        .toList();
  }

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

    await batch.commit();
  }
}
