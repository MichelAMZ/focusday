import '../../features/projects/domain/focus_project.dart';
import '../storage/focusday_storage.dart';
import 'focusday_sync_inspector.dart';
import 'sync_cloud_gateway.dart';
import 'sync_decision.dart';

typedef DownloadedProjectsApplier =
    Future<bool> Function(
      List<FocusProject> projects,
      int expectedProjectsRevision,
    );

enum SyncExecutionResult {
  noAction,
  uploaded,
  downloaded,
  conflict,
  firstSync,
  localChangedDuringSync,
}

class FocusDaySyncExecutor {
  FocusDaySyncExecutor({
    required this.inspector,
    required this.cloudStorage,
    required this.localStorage,
    required this.applyDownloadedProjects,
  });

  final FocusDaySyncInspector inspector;
  final SyncCloudGateway cloudStorage;
  final FocusDayStorage localStorage;
  final DownloadedProjectsApplier applyDownloadedProjects;

  Future<SyncExecutionResult> execute(String userId) async {
    final decision = await inspector.inspect(userId);

    switch (decision) {
      case SyncDecision.noAction:
        return SyncExecutionResult.noAction;

      case SyncDecision.conflict:
        return SyncExecutionResult.conflict;

      case SyncDecision.firstSync:
        return SyncExecutionResult.firstSync;

      case SyncDecision.upload:
        return _upload(userId);

      case SyncDecision.download:
        return _download(userId);
    }
  }

  Future<SyncExecutionResult> _upload(String userId) async {
    final revisionBeforeSync = localStorage.loadProjectsRevision();
    final projects = localStorage.loadProjects() ?? const [];

    await cloudStorage.saveProjects(userId, projects);

    final serverLastSyncAt = await cloudStorage.loadLastSyncAt(userId);
    if (serverLastSyncAt == null) {
      throw StateError(
        'Horodatage de synchronisation cloud indisponible après upload.',
      );
    }

    await localStorage.saveLastSyncAt(serverLastSyncAt);
    await localStorage.saveLastSyncedProjectsRevision(revisionBeforeSync);

    if (localStorage.loadProjectsRevision() != revisionBeforeSync) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    await localStorage.saveProjectsUpdatedAt(serverLastSyncAt);
    await localStorage.saveProjectsDirty(false);
    return SyncExecutionResult.uploaded;
  }

  Future<SyncExecutionResult> _download(String userId) async {
    final revisionBeforeSync = localStorage.loadProjectsRevision();
    final projects = await cloudStorage.loadProjects(userId);
    final serverLastSyncAt = await cloudStorage.loadLastSyncAt(userId);

    if (serverLastSyncAt == null) {
      throw StateError(
        'Horodatage de synchronisation cloud indisponible après download.',
      );
    }

    if (localStorage.loadProjectsRevision() != revisionBeforeSync ||
        localStorage.loadProjectsDirty()) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    final applied = await applyDownloadedProjects(projects, revisionBeforeSync);
    if (!applied || localStorage.loadProjectsRevision() != revisionBeforeSync) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    await localStorage.saveLastSyncAt(serverLastSyncAt);
    await localStorage.saveLastSyncedProjectsRevision(revisionBeforeSync);

    if (localStorage.loadProjectsRevision() != revisionBeforeSync) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    await localStorage.saveProjectsUpdatedAt(serverLastSyncAt);
    await localStorage.saveProjectsDirty(false);

    return SyncExecutionResult.downloaded;
  }
}
