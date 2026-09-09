import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/core/cloud/sync_decision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sauvegarde et recharge les projets', () async {
    final preferences = await SharedPreferences.getInstance();

    final storage = FocusDayStorage(preferences);

    const projects = [
      FocusProject(
        id: 'test-project',
        name: 'Projet persistant',
        durationMinutes: 45,
        status: FocusProjectStatus.active,
        tasks: [
          FocusTask(id: 'task-1', title: 'Première tâche', isCompleted: true),
        ],
      ),
    ];

    await storage.saveProjects(projects);

    final restored = storage.loadProjects();

    expect(restored, isNotNull);
    expect(restored!.length, 1);
    expect(restored.first.name, 'Projet persistant');
    expect(restored.first.durationMinutes, 45);
    expect(restored.first.status, FocusProjectStatus.active);
    expect(restored.first.tasks.length, 1);
    expect(restored.first.tasks.first.isCompleted, isTrue);
  });

  test('retourne null sans sauvegarde', () async {
    final preferences = await SharedPreferences.getInstance();

    final storage = FocusDayStorage(preferences);

    expect(storage.loadProjects(), isNull);
  });

  test('sauvegarde et recharge le chrono en pause', () async {
    final preferences = await SharedPreferences.getInstance();

    final storage = FocusDayStorage(preferences);

    const timer = FocusTimerState(
      projectId: 'bogoka',
      initialSeconds: 3600,
      remainingSeconds: 1234,
      status: FocusTimerStatus.paused,
    );

    await storage.saveTimer(timer);

    final restored = storage.loadTimer();

    expect(restored, isNotNull);
    expect(restored!.projectId, 'bogoka');
    expect(restored.initialSeconds, 3600);
    expect(restored.remainingSeconds, 1234);
    expect(restored.status, FocusTimerStatus.paused);
    expect(restored.endTime, isNull);
  });

  test('sauvegarde et recharge endTime du chrono actif', () async {
    final preferences = await SharedPreferences.getInstance();

    final storage = FocusDayStorage(preferences);

    final endTime = DateTime.now().add(const Duration(minutes: 20));

    final timer = FocusTimerState(
      projectId: 'bogoka',
      initialSeconds: 3600,
      remainingSeconds: 1200,
      status: FocusTimerStatus.running,
      endTime: endTime,
    );

    await storage.saveTimer(timer);

    final restored = storage.loadTimer();

    expect(restored, isNotNull);
    expect(restored!.status, FocusTimerStatus.running);
    expect(restored.endTime, isNotNull);
    expect(restored.endTime!.toIso8601String(), endTime.toIso8601String());
  });

  test('retourne null sans chrono sauvegardé', () async {
    final preferences = await SharedPreferences.getInstance();

    final storage = FocusDayStorage(preferences);

    expect(storage.loadTimer(), isNull);
  });

  test('sync owner isolates account baselines', () async {
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    expect(storage.loadSyncOwnerUid(), isNull);
    await storage.saveSyncOwnerUid('user-a');
    expect(storage.loadSyncOwnerUid(), 'user-a');
    expect(storage.loadSyncOwnerUid(), isNot('user-b'));
  });

  test(
    'switching A to B discards A domain baselines without local deletion',
    () async {
      final storage = FocusDayStorage(await SharedPreferences.getInstance());
      await storage.saveSyncOwnerUid('user-a');
      await storage.saveLastSyncAt(DateTime.utc(2026, 1, 1));
      await storage.saveProjectsUpdatedAt(DateTime.utc(2026, 1, 1));
      await storage.saveSettingsLastSyncAt(DateTime.utc(2026, 1, 1));
      await storage.saveFocusLastSyncAt(DateTime.utc(2026, 1, 1));
      await storage.incrementSettingsRevision();
      await storage.incrementFocusRevision();
      await storage.incrementProjectsRevision();
      await storage.saveProjectsGeneration(7);
      await storage.saveSettingsGeneration(8);
      await storage.saveFocusGeneration(9);
      await storage.saveTimer(
        const FocusTimerState(
          projectId: 'local-a',
          initialSeconds: 60,
          remainingSeconds: 30,
          status: FocusTimerStatus.paused,
        ),
      );

      await storage.prepareSyncOwner('user-b');

      expect(storage.loadSyncOwnerUid(), 'user-b');
      expect(storage.loadSettingsLastSyncAt(), isNull);
      expect(storage.loadFocusLastSyncAt(), isNull);
      expect(storage.loadLastSyncAt(), isNull);
      expect(storage.loadProjectsUpdatedAt(), isNull);
      expect(storage.loadProjectsGeneration(), isNull);
      expect(storage.loadSettingsGeneration(), isNull);
      expect(storage.loadFocusGeneration(), isNull);
      expect(storage.loadLastSyncedProjectsRevision(), 1);
      expect(storage.loadLastSyncedSettingsRevision(), 1);
      expect(storage.loadLastSyncedFocusRevision(), 1);
      expect(storage.loadTimer()?.projectId, 'local-a');
    },
  );

  test(
    'Google to Email and Email to Google switches isolate baselines',
    () async {
      final storage = FocusDayStorage(await SharedPreferences.getInstance());

      await storage.prepareSyncOwner('google-user');
      await storage.saveLastSyncAt(DateTime.utc(2026, 1, 1));
      await storage.prepareSyncOwner('email-user');
      expect(storage.loadSyncOwnerUid(), 'email-user');
      expect(storage.loadLastSyncAt(), isNull);

      await storage.saveLastSyncAt(DateTime.utc(2026, 1, 2));
      await storage.prepareSyncOwner('second-google-user');
      expect(storage.loadSyncOwnerUid(), 'second-google-user');
      expect(storage.loadLastSyncAt(), isNull);
    },
  );

  test(
    'project serialization preserves notes schedule and task details',
    () async {
      final storage = FocusDayStorage(await SharedPreferences.getInstance());
      final scheduledAt = DateTime.utc(2026, 9, 9, 14, 30);
      final projects = [
        FocusProject(
          id: 'complete-project',
          name: 'Projet complet',
          durationMinutes: 75,
          status: FocusProjectStatus.paused,
          scheduledAt: scheduledAt,
          notes: 'Notes importantes',
          tasks: const [
            FocusTask(
              id: 'task-1',
              title: 'Titre',
              description: 'Description détaillée',
              isCompleted: true,
            ),
          ],
        ),
      ];

      await storage.saveProjects(projects);
      final restored = storage.loadProjects()!.single;

      expect(restored.notes, 'Notes importantes');
      expect(restored.scheduledAt, scheduledAt);
      expect(restored.tasks.single.description, 'Description détaillée');
      expect(restored.tasks.single.isCompleted, isTrue);
    },
  );

  test('settings and focus revisions are independent and monotone', () async {
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    expect(await storage.incrementSettingsRevision(), 1);
    expect(await storage.incrementSettingsRevision(), 2);
    expect(await storage.incrementFocusRevision(), 1);
    expect(storage.loadSettingsRevision(), 2);
    expect(storage.loadFocusRevision(), 1);
  });

  test('cloud generation baselines survive a storage reload', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = FocusDayStorage(preferences);
    await storage.saveProjectsGeneration(3);
    await storage.saveSettingsGeneration(4);
    await storage.saveFocusGeneration(5);

    final reloaded = FocusDayStorage(await SharedPreferences.getInstance());
    expect(reloaded.loadProjectsGeneration(), 3);
    expect(reloaded.loadSettingsGeneration(), 4);
    expect(reloaded.loadFocusGeneration(), 5);
  });

  test('first-sync project baseline survives an F5-style reload', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = FocusDayStorage(preferences);
    final serverTime = DateTime.utc(2026, 9, 9, 10);
    await storage.incrementProjectsRevision();
    await storage.saveProjectsDirty(true);

    expect(
      await storage.establishProjectsSyncBaseline(
        uid: 'same-user',
        synchronizedRevision: 1,
        serverLastSyncAt: serverTime,
      ),
      isTrue,
    );

    final reloaded = FocusDayStorage(await SharedPreferences.getInstance());
    expect(reloaded.loadSyncOwnerUid(), 'same-user');
    expect(reloaded.loadLastSyncAt(), serverTime);
    expect(reloaded.loadProjectsRevision(), 1);
    expect(reloaded.loadLastSyncedProjectsRevision(), 1);
    expect(reloaded.loadProjectsDirty(), isFalse);
    expect(
      decideSync(
        localChanged:
            reloaded.loadProjectsRevision() !=
            reloaded.loadLastSyncedProjectsRevision(),
        localLastSyncAt: reloaded.loadLastSyncAt(),
        cloudLastSyncAt: serverTime,
      ),
      SyncDecision.noAction,
    );
  });

  test(
    'stale project revision cannot establish a first-sync baseline',
    () async {
      final storage = FocusDayStorage(await SharedPreferences.getInstance());
      await storage.incrementProjectsRevision();

      expect(
        await storage.establishProjectsSyncBaseline(
          uid: 'same-user',
          synchronizedRevision: 0,
          serverLastSyncAt: DateTime.utc(2026, 9, 9),
        ),
        isFalse,
      );
      expect(storage.loadSyncOwnerUid(), isNull);
      expect(storage.loadLastSyncAt(), isNull);
      expect(storage.loadLastSyncedProjectsRevision(), 0);
    },
  );
}
