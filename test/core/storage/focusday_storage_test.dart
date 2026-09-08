import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';

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
      await storage.saveSettingsLastSyncAt(DateTime.utc(2026, 1, 1));
      await storage.saveFocusLastSyncAt(DateTime.utc(2026, 1, 1));
      await storage.incrementSettingsRevision();
      await storage.incrementFocusRevision();
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
      expect(storage.loadLastSyncedSettingsRevision(), 1);
      expect(storage.loadLastSyncedFocusRevision(), 1);
      expect(storage.loadTimer()?.projectId, 'local-a');
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
}
