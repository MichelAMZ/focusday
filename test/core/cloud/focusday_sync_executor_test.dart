import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusday/core/cloud/focusday_sync_executor.dart';
import 'package:focusday/core/cloud/focusday_sync_inspector.dart';
import 'package:focusday/core/cloud/sync_cloud_gateway.dart';
import 'package:focusday/core/cloud/sync_decision.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';

class FakeSyncCloudGateway implements SyncCloudGateway {
  FakeSyncCloudGateway({
    required this.lastSyncAt,
    this.projects = const [],
    this.lastSyncAtAfterSave,
    this.onLoadProjects,
    this.onSaveProjects,
    this.onBeforeSaveProjects,
    this.generation = 0,
    this.returnNullUpdatedAt = false,
  });

  DateTime? lastSyncAt;
  DateTime? lastSyncAtAfterSave;
  List<FocusProject> projects;
  Future<void> Function()? onLoadProjects;
  Future<void> Function()? onSaveProjects;
  Future<void> Function()? onBeforeSaveProjects;
  int generation;
  bool returnNullUpdatedAt;

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
  Future<int> loadProjectsGeneration(String userId) async => generation;

  @override
  Future<CloudProjectsSnapshot> loadProjectsSnapshot(String userId) async {
    loadProjectsCalls++;
    await onLoadProjects?.call();
    return CloudProjectsSnapshot(
      projects: List<FocusProject>.from(projects),
      generation: generation,
      updatedAt: lastSyncAt,
    );
  }

  @override
  Future<CloudWriteResult> saveProjects(
    String userId,
    List<FocusProject> projects, {
    required int? expectedGeneration,
    bool force = false,
  }) async {
    saveProjectsCalls++;
    await onBeforeSaveProjects?.call();
    if (!force && expectedGeneration != generation) {
      throw const CloudWriteConflict();
    }
    await onSaveProjects?.call();
    this.projects = List<FocusProject>.from(projects);
    generation++;

    if (lastSyncAtAfterSave != null) {
      lastSyncAt = lastSyncAtAfterSave;
    }
    return CloudWriteResult(
      generation: generation,
      updatedAt: returnNullUpdatedAt ? null : lastSyncAt ?? DateTime.utc(2026),
    );
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
    SyncSessionGuard? isSessionCurrent,
  }) {
    final inspector = FocusDaySyncInspector(
      cloudStorage: cloudStorage,
      localStorage: localStorage,
    );

    return FocusDaySyncExecutor(
      inspector: inspector,
      cloudStorage: cloudStorage,
      localStorage: localStorage,
      isSessionCurrent: isSessionCurrent ?? (_) => true,
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

  test('unauthenticated session performs no cloud operation', () async {
    final localStorage = await createStorage();
    await localStorage.saveProjectsDirty(true);
    final cloudStorage = FakeSyncCloudGateway(lastSyncAt: DateTime.utc(2026));
    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
      isSessionCurrent: (_) => false,
    );

    expect(
      await executor.execute('signed-out-user'),
      SyncExecutionResult.sessionChanged,
    );
    expect(cloudStorage.loadLastSyncAtCalls, 0);
    expect(cloudStorage.saveProjectsCalls, 0);
    expect(cloudStorage.loadProjectsCalls, 0);
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

  test('logout during upload never advances the local baseline', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.incrementProjectsRevision();
    await localStorage.saveProjectsDirty(true);
    var signedIn = true;
    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: baseline,
      lastSyncAtAfterSave: baseline.add(const Duration(minutes: 1)),
      onSaveProjects: () async => signedIn = false,
    );
    final executor = createExecutor(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
      isSessionCurrent: (_) => signedIn,
    );

    expect(
      await executor.execute('user-1'),
      SyncExecutionResult.sessionChanged,
    );
    expect(localStorage.loadLastSyncAt(), baseline);
    expect(localStorage.loadLastSyncedProjectsRevision(), 0);
    expect(localStorage.loadProjectsDirty(), isTrue);
  });

  test('explicit empty local upload replaces the cloud snapshot', () async {
    final localStorage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await localStorage.saveProjects(const []);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.incrementProjectsRevision();
    await localStorage.saveProjectsDirty(true);
    final cloudStorage = FakeSyncCloudGateway(
      lastSyncAt: baseline,
      lastSyncAtAfterSave: baseline.add(const Duration(minutes: 1)),
      projects: const [
        FocusProject(
          id: 'old-cloud-project',
          name: 'Old',
          durationMinutes: 30,
          tasks: [],
        ),
      ],
    );

    expect(
      await createExecutor(
        localStorage: localStorage,
        cloudStorage: cloudStorage,
      ).execute('user-1'),
      SyncExecutionResult.uploaded,
    );
    expect(cloudStorage.projects, isEmpty);
    expect(localStorage.loadProjectsDirty(), isFalse);
  });

  test(
    'project conflict resolved with local updates cloud and baseline',
    () async {
      final storage = await createStorage();
      final baseline = DateTime.utc(2026, 9, 8, 10);
      final serverTime = baseline.add(const Duration(minutes: 20));
      await storage.saveProjects(const [
        FocusProject(
          id: 'local',
          name: 'Local',
          durationMinutes: 30,
          tasks: [],
        ),
      ]);
      await storage.saveLastSyncAt(baseline);
      await storage.incrementProjectsRevision();
      await storage.saveProjectsDirty(true);
      final cloud = FakeSyncCloudGateway(
        lastSyncAt: baseline.add(const Duration(minutes: 10)),
        lastSyncAtAfterSave: serverTime,
      );
      final executor = createExecutor(
        localStorage: storage,
        cloudStorage: cloud,
      );

      expect(await executor.execute('u'), SyncExecutionResult.conflict);
      expect(
        await executor.resolve('u', SyncResolutionChoice.keepLocal),
        SyncExecutionResult.uploaded,
      );
      expect(cloud.projects.single.id, 'local');
      expect(storage.loadLastSyncAt(), serverTime);
      expect(storage.loadLastSyncedProjectsRevision(), 1);
      expect(storage.loadProjectsGeneration(), cloud.generation);
      expect(storage.loadProjectsRevision(), 1);
      expect(storage.loadProjectsDirty(), isFalse);
      expect(await cloud.loadProjectsGeneration('u'), cloud.generation);
      expect(await executor.inspector.inspect('u'), SyncDecision.noAction);
      expect(await executor.execute('u'), SyncExecutionResult.noAction);
    },
  );

  test(
    'generation establishes first upload when server timestamp is unresolved',
    () async {
      final storage = await createStorage();
      await storage.saveProjects(const [
        FocusProject(
          id: 'local',
          name: 'Local',
          durationMinutes: 30,
          tasks: [],
        ),
      ]);
      await storage.incrementProjectsRevision();
      await storage.saveProjectsDirty(true);
      final cloud = FakeSyncCloudGateway(
        lastSyncAt: null,
        returnNullUpdatedAt: true,
      );
      final executor = createExecutor(
        localStorage: storage,
        cloudStorage: cloud,
      );

      expect(
        await executor.resolve('u', SyncResolutionChoice.keepLocal),
        SyncExecutionResult.uploaded,
      );
      expect(storage.loadProjectsGeneration(), 1);
      expect(storage.loadProjectsRevision(), 1);
      expect(storage.loadLastSyncedProjectsRevision(), 1);
      expect(storage.loadProjectsDirty(), isFalse);
      expect(storage.loadLastSyncAt(), isNull);
      expect(await executor.inspector.inspect('u'), SyncDecision.noAction);
    },
  );

  test('project conflict resolved with cloud replaces local', () async {
    final storage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    final cloudTime = baseline.add(const Duration(minutes: 10));
    await storage.saveProjects(const [
      FocusProject(id: 'local', name: 'Local', durationMinutes: 30, tasks: []),
    ]);
    await storage.saveLastSyncAt(baseline);
    await storage.incrementProjectsRevision();
    await storage.saveProjectsDirty(true);
    final cloud = FakeSyncCloudGateway(
      lastSyncAt: cloudTime,
      projects: const [
        FocusProject(
          id: 'cloud',
          name: 'Cloud',
          durationMinutes: 45,
          tasks: [],
        ),
      ],
    );
    final executor = createExecutor(localStorage: storage, cloudStorage: cloud);

    expect(
      await executor.resolve('u', SyncResolutionChoice.useCloud),
      SyncExecutionResult.downloaded,
    );
    expect(storage.loadProjects()!.single.id, 'cloud');
    expect(storage.loadProjectsDirty(), isFalse);
    expect(storage.loadLastSyncAt(), cloudTime);
    expect(storage.loadProjectsGeneration(), cloud.generation);
  });

  test('network failure resolving project keeps conflict metadata', () async {
    final storage = await createStorage();
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await storage.saveLastSyncAt(baseline);
    await storage.incrementProjectsRevision();
    await storage.saveProjectsDirty(true);
    final cloud = FakeSyncCloudGateway(
      lastSyncAt: baseline.add(const Duration(minutes: 1)),
      onSaveProjects: () async => throw StateError('offline'),
    );
    final executor = createExecutor(localStorage: storage, cloudStorage: cloud);

    await expectLater(
      executor.resolve('u', SyncResolutionChoice.keepLocal),
      throwsStateError,
    );
    expect(storage.loadLastSyncAt(), baseline);
    expect(storage.loadLastSyncedProjectsRevision(), 0);
    expect(storage.loadProjectsDirty(), isTrue);
  });

  test('failed first-sync restore establishes no baseline', () async {
    final storage = await createStorage();
    await storage.saveProjectsDirty(true);
    final cloud = FakeSyncCloudGateway(
      lastSyncAt: DateTime.utc(2026, 9, 9),
      onLoadProjects: () async => throw StateError('offline'),
    );
    final executor = createExecutor(localStorage: storage, cloudStorage: cloud);

    expect(await executor.execute('u'), SyncExecutionResult.firstSync);
    await expectLater(
      executor.resolve('u', SyncResolutionChoice.useCloud),
      throwsStateError,
    );
    expect(storage.loadLastSyncAt(), isNull);
    expect(storage.loadLastSyncedProjectsRevision(), 0);
    expect(storage.loadProjectsDirty(), isTrue);
  });

  test(
    'stale upload is rejected when cloud generation changes before write',
    () async {
      final storage = await createStorage();
      final baseline = DateTime.utc(2026, 9, 8, 10);

      const localProjects = [
        FocusProject(
          id: 'shared',
          name: 'Version locale',
          durationMinutes: 30,
          tasks: [],
        ),
      ];

      const concurrentProjects = [
        FocusProject(
          id: 'shared',
          name: 'Version concurrente',
          durationMinutes: 45,
          tasks: [],
        ),
      ];

      await storage.saveProjects(localProjects);
      await storage.saveLastSyncAt(baseline);
      await storage.saveProjectsGeneration(0);
      await storage.incrementProjectsRevision();
      await storage.saveProjectsDirty(true);

      late final FakeSyncCloudGateway cloud;
      var concurrentWriteInjected = false;

      cloud = FakeSyncCloudGateway(
        lastSyncAt: baseline,
        generation: 0,
        onBeforeSaveProjects: () async {
          if (concurrentWriteInjected) return;
          concurrentWriteInjected = true;
          cloud.projects = List<FocusProject>.from(concurrentProjects);
          cloud.generation = 1;
          cloud.lastSyncAt = baseline.add(const Duration(minutes: 1));
        },
      );

      final executor = createExecutor(
        localStorage: storage,
        cloudStorage: cloud,
      );

      final result = await executor.execute('u');

      expect(result, SyncExecutionResult.conflict);
      expect(cloud.generation, 1);
      expect(cloud.projects.single.name, 'Version concurrente');
      expect(storage.loadProjectsDirty(), isTrue);
      expect(storage.loadProjectsGeneration(), 0);
      expect(storage.loadLastSyncedProjectsRevision(), 0);
    },
  );
}
