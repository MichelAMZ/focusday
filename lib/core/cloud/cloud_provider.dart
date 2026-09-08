import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/today/application/today_controller.dart';
import '../storage/storage_provider.dart';
import 'focusday_cloud_storage.dart';
import 'focusday_sync_executor.dart';
import 'focusday_sync_inspector.dart';
import 'focusday_sync_coordinator.dart';

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

  return FocusDaySyncExecutor(
    inspector: inspector,
    cloudStorage: cloudStorage,
    localStorage: localStorage,
    applyDownloadedProjects: (projects, expectedProjectsRevision) {
      return ref
          .read(todayProjectsProvider.notifier)
          .replaceAllProjectsFromCloud(projects, expectedProjectsRevision);
    },
  );
});

final focusDaySyncCoordinatorProvider = Provider<FocusDaySyncCoordinator?>((
  ref,
) {
  final executor = ref.watch(focusDaySyncExecutorProvider);
  return executor == null ? null : FocusDaySyncCoordinator(executor.execute);
});
