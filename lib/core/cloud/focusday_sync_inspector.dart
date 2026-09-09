import '../storage/focusday_storage.dart';
import 'sync_decision.dart';
import 'sync_metadata_reader.dart';
import 'sync_cloud_gateway.dart';

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
    if (cloudStorage is SyncCloudGateway) {
      final gateway = cloudStorage as SyncCloudGateway;
      final cloudGeneration = await gateway.loadProjectsGeneration(userId);
      final baselineGeneration = localStorage.loadProjectsGeneration();
      if (baselineGeneration == null) {
        final legacyDecision = decideSync(
          localChanged: localChanged,
          localLastSyncAt: localLastSyncAt,
          cloudLastSyncAt: await gateway.loadLastSyncAt(userId),
        );
        if (legacyDecision != SyncDecision.firstSync &&
            legacyDecision != SyncDecision.conflict) {
          await localStorage.saveProjectsGeneration(cloudGeneration);
        }
        return legacyDecision;
      }
      final cloudChanged = cloudGeneration != baselineGeneration;
      if (localChanged && cloudChanged) return SyncDecision.conflict;
      if (localChanged) return SyncDecision.upload;
      if (cloudChanged) return SyncDecision.download;
      return SyncDecision.noAction;
    }
    final cloudLastSyncAt = await cloudStorage.loadLastSyncAt(userId);

    return decideSync(
      localChanged: localChanged,
      localLastSyncAt: localLastSyncAt,
      cloudLastSyncAt: cloudLastSyncAt,
    );
  }
}
