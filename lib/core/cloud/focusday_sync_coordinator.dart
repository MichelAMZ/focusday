import 'package:firebase_core/firebase_core.dart';

import 'focusday_sync_executor.dart';

enum SyncCoordinatorStatus {
  idle,
  synchronizing,
  synchronized,
  conflict,
  firstSyncRequired,
  localChangedDuringSync,
  pendingOffline,
  error,
}

typedef SyncExecutorCallback =
    Future<SyncExecutionResult> Function(String userId);

class FocusDaySyncCoordinator {
  FocusDaySyncCoordinator(this._execute);

  final SyncExecutorCallback _execute;
  Future<SyncCoordinatorStatus>? _activeSync;
  int _generation = 0;

  SyncCoordinatorStatus state = SyncCoordinatorStatus.idle;
  Object? lastError;

  Future<SyncCoordinatorStatus> synchronize(String userId) {
    final activeSync = _activeSync;
    if (activeSync != null) {
      return activeSync;
    }

    final generation = _generation;
    state = SyncCoordinatorStatus.synchronizing;
    lastError = null;
    final operation = _run(userId, generation);
    _activeSync = operation;
    return operation;
  }

  void reset() {
    _generation++;
    state = SyncCoordinatorStatus.idle;
    lastError = null;
  }

  Future<SyncCoordinatorStatus> _run(String userId, int generation) async {
    try {
      final result = await _execute(userId);
      final next = switch (result) {
        SyncExecutionResult.noAction ||
        SyncExecutionResult.uploaded ||
        SyncExecutionResult.downloaded => SyncCoordinatorStatus.synchronized,
        SyncExecutionResult.conflict => SyncCoordinatorStatus.conflict,
        SyncExecutionResult.firstSync =>
          SyncCoordinatorStatus.firstSyncRequired,
        SyncExecutionResult.localChangedDuringSync =>
          SyncCoordinatorStatus.localChangedDuringSync,
        SyncExecutionResult.sessionChanged => SyncCoordinatorStatus.idle,
      };
      if (generation == _generation) {
        state = next;
      }
      return next;
    } catch (error) {
      final errorStatus = isTransientCloudError(error)
          ? SyncCoordinatorStatus.pendingOffline
          : SyncCoordinatorStatus.error;
      if (generation == _generation) {
        state = errorStatus;
        lastError = error;
      }
      return errorStatus;
    } finally {
      _activeSync = null;
    }
  }
}

bool isTransientCloudError(Object error) {
  if (error is! FirebaseException) return false;

  return const {
    'aborted',
    'cancelled',
    'deadline-exceeded',
    'network-request-failed',
    'resource-exhausted',
    'unavailable',
  }.contains(error.code);
}
