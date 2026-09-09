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
typedef SyncSessionGuard = bool Function(String userId);

enum SyncResolutionChoice { keepLocal, useCloud }

enum SyncExecutionResult {
  noAction,
  uploaded,
  downloaded,
  conflict,
  firstSync,
  localChangedDuringSync,
  sessionChanged,
}

class FocusDaySyncExecutor {
  FocusDaySyncExecutor({
    required this.inspector,
    required this.cloudStorage,
    required this.localStorage,
    required this.applyDownloadedProjects,
    this.isSessionCurrent = _alwaysCurrent,
  });

  final FocusDaySyncInspector inspector;
  final SyncCloudGateway cloudStorage;
  final FocusDayStorage localStorage;
  final DownloadedProjectsApplier applyDownloadedProjects;
  final SyncSessionGuard isSessionCurrent;

  static bool _alwaysCurrent(String _) => true;

  Future<SyncExecutionResult> execute(String userId) async {
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    final decision = await inspector.inspect(userId);
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }

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

  Future<SyncExecutionResult> resolve(
    String userId,
    SyncResolutionChoice choice,
  ) => switch (choice) {
    SyncResolutionChoice.keepLocal => _upload(userId, force: true),
    SyncResolutionChoice.useCloud => _download(userId, allowDirty: true),
  };

  Future<SyncExecutionResult> _upload(
    String userId, {
    bool force = false,
  }) async {
    if (!isSessionCurrent(userId)) return SyncExecutionResult.sessionChanged;
    final revisionBeforeSync = localStorage.loadProjectsRevision();
    final projects = localStorage.loadProjects() ?? const [];

    late final CloudWriteResult write;
    try {
      write = await cloudStorage.saveProjects(
        userId,
        projects,
        expectedGeneration: localStorage.loadProjectsGeneration(),
        force: force,
      );
    } on CloudWriteConflict {
      return SyncExecutionResult.conflict;
    }

    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }

    final serverLastSyncAt = write.updatedAt;

    if (serverLastSyncAt != null) {
      await localStorage.saveLastSyncAt(serverLastSyncAt);
    }
    await localStorage.saveLastSyncedProjectsRevision(revisionBeforeSync);
    await localStorage.saveProjectsGeneration(write.generation);

    if (localStorage.loadProjectsRevision() != revisionBeforeSync) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    if (serverLastSyncAt != null) {
      await localStorage.saveProjectsUpdatedAt(serverLastSyncAt);
    }
    await localStorage.saveProjectsDirty(false);
    return SyncExecutionResult.uploaded;
  }

  Future<SyncExecutionResult> _download(
    String userId, {
    bool allowDirty = false,
  }) async {
    if (!isSessionCurrent(userId)) return SyncExecutionResult.sessionChanged;
    final revisionBeforeSync = localStorage.loadProjectsRevision();
    final snapshot = await cloudStorage.loadProjectsSnapshot(userId);
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    final serverLastSyncAt = snapshot.updatedAt;
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }

    if (localStorage.loadProjectsRevision() != revisionBeforeSync ||
        (!allowDirty && localStorage.loadProjectsDirty())) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    final applied = await applyDownloadedProjects(
      snapshot.projects,
      revisionBeforeSync,
    );
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    if (!applied || localStorage.loadProjectsRevision() != revisionBeforeSync) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    if (serverLastSyncAt != null) {
      await localStorage.saveLastSyncAt(serverLastSyncAt);
    }
    await localStorage.saveLastSyncedProjectsRevision(revisionBeforeSync);
    await localStorage.saveProjectsGeneration(snapshot.generation);

    if (localStorage.loadProjectsRevision() != revisionBeforeSync) {
      return SyncExecutionResult.localChangedDuringSync;
    }

    if (serverLastSyncAt != null) {
      await localStorage.saveProjectsUpdatedAt(serverLastSyncAt);
    }
    await localStorage.saveProjectsDirty(false);

    return SyncExecutionResult.downloaded;
  }
}
