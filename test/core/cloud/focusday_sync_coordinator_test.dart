import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/cloud/focusday_sync_coordinator.dart';
import 'package:focusday/core/cloud/focusday_sync_executor.dart';

void main() {
  test('two simultaneous calls execute only one synchronization', () async {
    final completion = Completer<SyncExecutionResult>();
    var calls = 0;
    final coordinator = FocusDaySyncCoordinator((userId) {
      calls++;
      return completion.future;
    });

    final first = coordinator.synchronize('user-1');
    final second = coordinator.synchronize('user-1');
    expect(calls, 1);
    expect(coordinator.state, SyncCoordinatorStatus.synchronizing);
    completion.complete(SyncExecutionResult.noAction);
    expect(await first, SyncCoordinatorStatus.synchronized);
    expect(await second, SyncCoordinatorStatus.synchronized);
    expect(calls, 1);
  });

  test(
    'conflict and firstSync remain explicit non-destructive states',
    () async {
      final conflict = FocusDaySyncCoordinator(
        (_) async => SyncExecutionResult.conflict,
      );
      final firstSync = FocusDaySyncCoordinator(
        (_) async => SyncExecutionResult.firstSync,
      );
      expect(
        await conflict.synchronize('user'),
        SyncCoordinatorStatus.conflict,
      );
      expect(
        await firstSync.synchronize('user'),
        SyncCoordinatorStatus.firstSyncRequired,
      );
    },
  );

  test(
    'network error is captured and does not escape to the application',
    () async {
      final coordinator = FocusDaySyncCoordinator(
        (_) async => throw StateError('offline'),
      );
      expect(
        await coordinator.synchronize('user'),
        SyncCoordinatorStatus.error,
      );
      expect(coordinator.state, SyncCoordinatorStatus.error);
      expect(coordinator.lastError, isA<StateError>());
    },
  );

  test('transient Firestore error is classified as pending offline', () async {
    final coordinator = FocusDaySyncCoordinator(
      (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      ),
    );

    expect(
      await coordinator.synchronize('user'),
      SyncCoordinatorStatus.pendingOffline,
    );
    expect(coordinator.state, SyncCoordinatorStatus.pendingOffline);
  });

  test(
    'logout reset prevents an old completion from changing visible state',
    () async {
      final completion = Completer<SyncExecutionResult>();
      final coordinator = FocusDaySyncCoordinator((_) => completion.future);
      final running = coordinator.synchronize('user');
      coordinator.reset();
      completion.complete(SyncExecutionResult.downloaded);
      await running;
      expect(coordinator.state, SyncCoordinatorStatus.idle);
    },
  );
}
