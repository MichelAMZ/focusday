import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/today/application/today_controller.dart';
import '../../features/today/application/focus_timer_controller.dart';
import '../../features/settings/application/settings_controller.dart';
import '../../features/auth/application/auth_controller.dart';
import '../storage/storage_provider.dart';
import 'focusday_cloud_storage.dart';
import 'focusday_sync_executor.dart';
import 'focusday_sync_inspector.dart';
import 'focusday_sync_coordinator.dart';
import 'account_sync_executor.dart';
import 'conflict_resolution.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final focusDayCloudStorageProvider = Provider<FocusDayCloudStorage>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return FocusDayCloudStorage(firestore);
});

final focusDaySyncInspectorProvider = Provider<FocusDaySyncInspector?>((ref) {
  final localStorage = ref.watch(focusDayStorageProvider);

  if (localStorage == null) {
    return null;
  }

  final cloudStorage = ref.watch(focusDayCloudStorageProvider);

  return FocusDaySyncInspector(
    cloudStorage: cloudStorage,
    localStorage: localStorage,
  );
});

final focusDaySyncExecutorProvider = Provider<FocusDaySyncExecutor?>((ref) {
  final localStorage = ref.watch(focusDayStorageProvider);
  final inspector = ref.watch(focusDaySyncInspectorProvider);

  if (localStorage == null || inspector == null) {
    return null;
  }

  final cloudStorage = ref.watch(focusDayCloudStorageProvider);
  bool isSessionCurrent(String userId) =>
      ref.read(firebaseAuthProvider).currentUser?.uid == userId &&
      localStorage.loadSyncOwnerUid() == userId;

  return FocusDaySyncExecutor(
    inspector: inspector,
    cloudStorage: cloudStorage,
    localStorage: localStorage,
    isSessionCurrent: isSessionCurrent,
    applyDownloadedProjects: (projects, expectedProjectsRevision) {
      return ref
          .read(todayProjectsProvider.notifier)
          .replaceAllProjectsFromCloud(projects, expectedProjectsRevision);
    },
  );
});

final accountSyncExecutorProvider = Provider<AccountSyncExecutor?>((ref) {
  final localStorage = ref.watch(focusDayStorageProvider);
  if (localStorage == null) return null;
  final cloudStorage = ref.watch(focusDayCloudStorageProvider);
  return AccountSyncExecutor(
    gateway: cloudStorage,
    storage: localStorage,
    isSessionCurrent: (userId) =>
        ref.read(firebaseAuthProvider).currentUser?.uid == userId &&
        localStorage.loadSyncOwnerUid() == userId,
    applySettings: (value, revision) =>
        ref.read(settingsProvider.notifier).replaceFromCloud(value, revision),
    applyFocus: (value, revision) =>
        ref.read(focusTimerProvider.notifier).replaceFromCloud(value, revision),
  );
});

final syncConflictResolverProvider = Provider<SyncConflictResolver?>((ref) {
  final projects = ref.watch(focusDaySyncExecutorProvider);
  final account = ref.watch(accountSyncExecutorProvider);
  if (projects == null || account == null) return null;
  return SyncConflictResolver(projects: projects, account: account);
});

final focusDaySyncCoordinatorProvider = Provider<FocusDaySyncCoordinator?>((
  ref,
) {
  final executor = ref.watch(focusDaySyncExecutorProvider);
  final localStorage = ref.watch(focusDayStorageProvider);
  if (executor == null || localStorage == null) return null;
  final accountExecutor = ref.watch(accountSyncExecutorProvider);
  if (accountExecutor == null) return null;
  return FocusDaySyncCoordinator((userId) async {
    if (localStorage.loadSyncOwnerUid() != userId) {
      return SyncExecutionResult.firstSync;
    }
    final results = <SyncExecutionResult>[
      await executor.execute(userId),
      await accountExecutor.executeSettings(userId),
      await accountExecutor.executeFocus(userId),
    ];
    if (results.contains(SyncExecutionResult.conflict)) {
      return SyncExecutionResult.conflict;
    }
    if (results.contains(SyncExecutionResult.firstSync)) {
      return SyncExecutionResult.firstSync;
    }
    if (results.contains(SyncExecutionResult.localChangedDuringSync)) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    if (results.contains(SyncExecutionResult.sessionChanged)) {
      return SyncExecutionResult.sessionChanged;
    }
    if (results.contains(SyncExecutionResult.uploaded)) {
      return SyncExecutionResult.uploaded;
    }
    if (results.contains(SyncExecutionResult.downloaded)) {
      return SyncExecutionResult.downloaded;
    }
    return SyncExecutionResult.noAction;
  });
});
