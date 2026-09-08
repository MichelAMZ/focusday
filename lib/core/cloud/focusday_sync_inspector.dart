import '../storage/focusday_storage.dart';
import 'sync_decision.dart';
import 'sync_metadata_reader.dart';

class FocusDaySyncInspector {
  FocusDaySyncInspector({
    required this.cloudStorage,
    required this.localStorage,
  });

  final SyncMetadataReader cloudStorage;
  final FocusDayStorage localStorage;

  Future<SyncDecision> inspect(String userId) async {
    final localChanged =
        localStorage.loadProjectsDirty() ||
        localStorage.loadProjectsRevision() !=
            localStorage.loadLastSyncedProjectsRevision();
    final localLastSyncAt = localStorage.loadLastSyncAt();
    final cloudLastSyncAt = await cloudStorage.loadLastSyncAt(userId);

    return decideSync(
      localChanged: localChanged,
      localLastSyncAt: localLastSyncAt,
      cloudLastSyncAt: cloudLastSyncAt,
    );
  }
}
