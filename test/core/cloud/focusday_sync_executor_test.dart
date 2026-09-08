import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusday/core/cloud/focusday_sync_executor.dart';
import 'package:focusday/core/cloud/focusday_sync_inspector.dart';
import 'package:focusday/core/cloud/sync_cloud_gateway.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';

class FakeSyncCloudGateway implements SyncCloudGateway {
  FakeSyncCloudGateway({
    required this.lastSyncAt,
    this.projects = const [],
    this.lastSyncAtAfterSave,
    this.onLoadProjects,
    this.onSaveProjects,
  });

  DateTime? lastSyncAt;
  DateTime? lastSyncAtAfterSave;
  List<FocusProject> projects;
  Future<void> Function()? onLoadProjects;
  Future<void> Function()? onSaveProjects;

  int loadProjectsCalls = 0;
  int saveProjectsCalls = 0;
  int loadLastSyncAtCalls = 0;

  @override
  Future<DateTime?> loadLastSyncAt(String userId) async {
    loadLastSyncAtCalls++;
    return lastSyncAt;
  }

  @override
  Future<List<FocusProject>> loadProjects(String userId) async {
    loadProjectsCalls++;
    await onLoadProjects?.call();
    return List<FocusProject>.from(projects);
  }

  @override
  Future<void> saveProjects(String userId, List<FocusProject> projects) async {
    saveProjectsCalls++;
    this.projects = List<FocusProject>.from(projects);
    await onSaveProjects?.call();

    if (lastSyncAtAfterSave != null) {
      lastSyncAt = lastSyncAtAfterSave;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<FocusDayStorage> createStorage() async {
    final preferences = await SharedPreferences.getInstance();
    return FocusDayStorage(preferences);
  }

  FocusDaySyncExecutor createExecutor({
    required FocusDayStorage localStorage,
    required FakeSyncCloudGateway cloudStorage,
    DownloadedProjectsApplier? applyDownloadedProjects,
  }) {
    final inspector = FocusDaySyncInspector(
      cloudStorage: cloudStorage,
      localStorage: localStorage,
    );

    return FocusDaySyncExecutor(
      inspector: inspector,
      cloudStorage: cloudStorage,
      localStorage: localStorage,
      applyDownloadedProjects:
          applyDownloadedProjects ??
          (projects, expectedRevision) async {
            await localStorage.saveProjects(projects);
            return localStorage.loadProjectsRevision() == expectedRevision;
          },
    );
  }

  test('noAction performs no cloud write', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);

    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(false);

    final cloudStorage = FakeSyncCloudGateway(lastSyncAt: baseline);
    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    final result = await executor.execute('user-1');

    expect(result, SyncExecutionResult.noAction);
    expect(cloudStorage.saveProjectsCalls, 0);
    expect(cloudStorage.loadProjectsCalls, 0);
    expect(localStorage.loadProjectsDirty(), false);
    expect(localStorage.loadLastSyncedProjectsRevision(), 0);
  });

  test('firstSync performs no cloud write', () async {
    final localStorage = await createStorage();
    await localStorage.saveProjectsDirty(true);

    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: DateTime.utc(2026, 9, 8, 10),
    );

    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    final result = await executor.execute('user-1');

    expect(result, SyncExecutionResult.firstSync);
    expect(cloudStorage.saveProjectsCalls, 0);
    expect(cloudStorage.loadProjectsCalls, 0);
    expect(localStorage.loadProjectsDirty(), true);
  });

  test('conflict performs no cloud write or download', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);

    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(true);

    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: baseline.add(const Duration(minutes: 10)),
    );

    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    final result = await executor.execute('user-1');

    expect(result, SyncExecutionResult.conflict);
    expect(cloudStorage.saveProjectsCalls, 0);
    expect(cloudStorage.loadProjectsCalls, 0);
    expect(localStorage.loadProjectsDirty(), true);
  });

  test('upload saves local projects and clears dirty flag', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    final serverTime = baseline.add(const Duration(minutes: 10));

    const localProjects = [
      FocusProject(
        id: 'local-1',
        name: 'Projet local',
        durationMinutes: 30,
        tasks: [],
      ),
    ];

    await localStorage.saveProjects(localProjects);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(true);

    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: baseline,
      lastSyncAtAfterSave: serverTime,
    );

    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    final result = await executor.execute('user-1');

    expect(result, SyncExecutionResult.uploaded);
    expect(cloudStorage.saveProjectsCalls, 1);
    expect(cloudStorage.projects.single.id, 'local-1');
    expect(localStorage.loadLastSyncAt(), serverTime);
    expect(localStorage.loadProjectsUpdatedAt(), serverTime);
    expect(localStorage.loadProjectsDirty(), false);
    expect(localStorage.loadLastSyncedProjectsRevision(), 0);
  });

  test('download replaces local projects and clears dirty flag', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    final serverTime = baseline.add(const Duration(minutes: 10));

    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(false);

    const cloudProjects = [
      FocusProject(
        id: 'cloud-1',
        name: 'Projet cloud',
        durationMinutes: 45,
        tasks: [],
      ),
    ];

    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: serverTime,
      projects: cloudProjects,
    );

    var applyCalls = 0;

    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
      applyDownloadedProjects: (projects, expectedRevision) async {
        applyCalls++;
        await localStorage.saveProjects(projects);
        return true;
      },
    );

    final result = await executor.execute('user-1');

    expect(result, SyncExecutionResult.downloaded);
    expect(cloudStorage.loadProjectsCalls, 1);
    expect(applyCalls, 1);

    final restored = localStorage.loadProjects();
    expect(restored, isNotNull);
    expect(restored!.single.id, 'cloud-1');
    expect(localStorage.loadLastSyncAt(), serverTime);
    expect(localStorage.loadProjectsUpdatedAt(), serverTime);
    expect(localStorage.loadProjectsDirty(), false);
  });

  test(
    'upload preserves dirty flag when local project changes during sync',
    () async {
      final localStorage = await createStorage();
      final baseline = DateTime.utc(2026, 9, 8, 10);
      final serverTime = baseline.add(const Duration(minutes: 10));

      const localProjects = [
        FocusProject(
          id: 'local-1',
          name: 'Projet local',
          durationMinutes: 30,
          tasks: [],
        ),
      ];

      await localStorage.saveProjects(localProjects);
      await localStorage.saveLastSyncAt(baseline);
      await localStorage.saveProjectsDirty(true);

      final cloudStorage = FakeSyncCloudGateway(
        lastSyncAt: baseline,
        lastSyncAtAfterSave: serverTime,
        onSaveProjects: () async {
          await localStorage.incrementProjectsRevision();
          await localStorage.saveProjectsDirty(true);
        },
      );

      final executor = createExecutor(
        localStorage: localStorage,
        cloudStorage: cloudStorage,
      );

      final result = await executor.execute('user-1');

      expect(result, SyncExecutionResult.localChangedDuringSync);
      expect(cloudStorage.saveProjectsCalls, 1);
      expect(localStorage.loadProjectsDirty(), true);
      expect(localStorage.loadProjectsRevision(), 1);
    },
  );

  test('download does not overwrite local change made during sync', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    final serverTime = baseline.add(const Duration(minutes: 10));

    const localProjects = [
      FocusProject(
        id: 'local-1',
        name: 'Projet local',
        durationMinutes: 30,
        tasks: [],
      ),
    ];

    const cloudProjects = [
      FocusProject(
        id: 'cloud-1',
        name: 'Projet cloud',
        durationMinutes: 45,
        tasks: [],
      ),
    ];

    await localStorage.saveProjects(localProjects);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(false);

    var applyCalls = 0;

    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: serverTime,
      projects: cloudProjects,
      onLoadProjects: () async {
        await localStorage.incrementProjectsRevision();
        await localStorage.saveProjectsDirty(true);
      },
    );

    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
      applyDownloadedProjects: (projects, expectedRevision) async {
        applyCalls++;
        await localStorage.saveProjects(projects);
        return true;
      },
    );

    final result = await executor.execute('user-1');

    expect(result, SyncExecutionResult.localChangedDuringSync);
    expect(cloudStorage.loadProjectsCalls, 1);
    expect(applyCalls, 0);
    expect(localStorage.loadProjectsDirty(), true);
    expect(localStorage.loadProjectsRevision(), 1);

    final preservedProjects = localStorage.loadProjects();
    expect(preservedProjects, isNotNull);
    expect(preservedProjects!.single.id, 'local-1');
  });

  test(
    'download aborts when local changes during snapshot application',
    () async {
      final localStorage = await createStorage();
      final baseline = DateTime.utc(2026, 9, 8, 10);
      await localStorage.saveLastSyncAt(baseline);
      final cloudStorage = FakeSyncCloudGateway(
        lastSyncAt: baseline.add(const Duration(minutes: 5)),
        projects: const [
          FocusProject(
            id: 'cloud',
            name: 'Cloud',
            durationMinutes: 30,
            tasks: [],
          ),
        ],
      );
      var writes = 0;
      final executor = createExecutor(
        localStorage: localStorage,
        cloudStorage: cloudStorage,
        applyDownloadedProjects: (projects, expectedRevision) async {
          await localStorage.incrementProjectsRevision();
          await localStorage.saveProjectsDirty(true);
          writes++;
          return false;
        },
      );

      expect(
        await executor.execute('user-1'),
        SyncExecutionResult.localChangedDuringSync,
      );
      expect(writes, 1);
      expect(localStorage.loadProjectsRevision(), 1);
      expect(localStorage.loadLastSyncedProjectsRevision(), 0);
      expect(localStorage.loadProjectsDirty(), true);
    },
  );

  test('network error never advances synchronized revision', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.incrementProjectsRevision();
    await localStorage.saveProjectsDirty(true);
    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: baseline,
      onSaveProjects: () async => throw StateError('offline'),
    );
    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    await expectLater(executor.execute('user-1'), throwsStateError);
    expect(localStorage.loadLastSyncedProjectsRevision(), 0);
    expect(localStorage.loadProjectsDirty(), true);
  });
}
