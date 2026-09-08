import '../../features/projects/domain/focus_project.dart';
import 'sync_metadata_reader.dart';

abstract class SyncCloudGateway implements SyncMetadataReader {
  Future<List<FocusProject>> loadProjects(String userId);

  Future<void> saveProjects(
    String userId,
    List<FocusProject> projects,
  );
}
