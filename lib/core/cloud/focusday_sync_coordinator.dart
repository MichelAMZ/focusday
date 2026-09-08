import 'focusday_sync_executor.dart';

enum SyncCoordinatorStatus {
  idle,
  synchronizing,
  synchronized,
  conflict,
  firstSyncRequired,
  localChangedDuringSync,
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
      };
      if (generation == _generation) {
        state = next;
      }
      return next;
    } catch (error) {
      if (generation == _generation) {
        state = SyncCoordinatorStatus.error;
        lastError = error;
      }
      return SyncCoordinatorStatus.error;
    } finally {
      _activeSync = null;
    }
  }
}
