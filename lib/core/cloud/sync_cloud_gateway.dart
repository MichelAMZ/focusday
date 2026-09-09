import '../../features/projects/domain/focus_project.dart';
import 'sync_metadata_reader.dart';

class CloudWriteConflict implements Exception {
  const CloudWriteConflict();
}

class CloudWriteResult {
  const CloudWriteResult({required this.generation, required this.updatedAt});

  final int generation;
  final DateTime? updatedAt;
}

class CloudProjectsSnapshot {
  const CloudProjectsSnapshot({
    required this.projects,
    required this.generation,
    required this.updatedAt,
  });

  final List<FocusProject> projects;
  final int generation;
  final DateTime? updatedAt;
}

abstract class SyncCloudGateway implements SyncMetadataReader {
  Future<List<FocusProject>> loadProjects(String userId);

  Future<int> loadProjectsGeneration(String userId);

  Future<CloudProjectsSnapshot> loadProjectsSnapshot(String userId);

  Future<CloudWriteResult> saveProjects(
    String userId,
    List<FocusProject> projects, {
    required int? expectedGeneration,
    bool force = false,
  });
}
