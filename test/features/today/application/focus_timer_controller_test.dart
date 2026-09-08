import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/today/application/focus_timer_controller.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/core/storage/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusday/core/audio/focus_completion_sound_provider.dart';
import 'package:focusday/core/audio/focus_completion_sound_service.dart';
import 'package:focusday/core/cloud/account_sync_models.dart';
import 'package:focusday/core/cloud/sync_mutation_bus.dart';

class DelayedTimerStorage extends FocusDayStorage {
  DelayedTimerStorage(super.preferences);

  final writeEntered = Completer<void>();
  final releaseWrite = Completer<void>();
  bool delayNextWrite = true;

  @override
  Future<void> saveTimer(FocusTimerState timer) async {
    if (delayNextWrite) {
      delayNextWrite = false;
      writeEntered.complete();
      await releaseWrite.future;
    }
    await super.saveTimer(timer);
  }
}

class RecordingSoundService implements FocusCompletionSoundPlayer {
  int playCount = 0;

  @override
  Future<void> play() async => playCount++;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('timer starts with Bogoka at 60 minutes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(focusTimerProvider);

    expect(state.projectId, 'bogoka');
    expect(state.remainingSeconds, 3600);
    expect(state.status, FocusTimerStatus.idle);
  });

  test('start changes timer status to running', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(focusTimerProvider.notifier).start();

    final state = container.read(focusTimerProvider);

    expect(state.status, FocusTimerStatus.running);
    expect(state.endTime, isNotNull);
  });

  test('pause changes running timer to paused', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(focusTimerProvider.notifier);

    controller.start();
    controller.pause();

    final state = container.read(focusTimerProvider);

    expect(state.status, FocusTimerStatus.paused);
    expect(state.endTime, isNull);
  });

  test('addMinutes adds fifteen minutes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(focusTimerProvider.notifier).addMinutes(15);

    final state = container.read(focusTimerProvider);

    expect(state.remainingSeconds, 4500);
  });

  test('complete finishes the timer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(focusTimerProvider.notifier).complete();

    final state = container.read(focusTimerProvider);

    expect(state.status, FocusTimerStatus.completed);
    expect(state.remainingSeconds, 0);
    expect(state.endTime, isNull);
  });

  test('reset prepares timer for another project', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(focusTimerProvider.notifier)
        .reset(projectId: 'dotnet', durationMinutes: 30);

    final state = container.read(focusTimerProvider);

    expect(state.projectId, 'dotnet');
    expect(state.remainingSeconds, 1800);
    expect(state.initialSeconds, 1800);
    expect(state.status, FocusTimerStatus.idle);
  });

  test(
    'meaningful transitions increment focus revision, not clock ticks',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = FocusDayStorage(await SharedPreferences.getInstance());
      var now = DateTime.utc(2026, 9, 8, 12);
      final container = ProviderContainer(
        overrides: [
          focusDayStorageProvider.overrideWithValue(storage),
          focusClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(focusTimerProvider.notifier);

      controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(storage.loadFocusRevision(), 1);

      now = now.add(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(storage.loadFocusRevision(), 1);

      controller.pause();
      controller.resume();
      controller.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(storage.loadFocusRevision(), 4);
    },
  );

  test('ten display ticks cause no revision or cloud mutation', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    var now = DateTime.utc(2026, 9, 8, 12);
    final container = ProviderContainer(
      overrides: [
        focusDayStorageProvider.overrideWithValue(storage),
        focusClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    var mutations = 0;
    final subscription = container
        .read(syncMutationBusProvider)
        .changes
        .listen((_) => mutations++);
    addTearDown(subscription.cancel);
    final controller = container.read(focusTimerProvider.notifier);
    controller.start();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final revisionAfterStart = storage.loadFocusRevision();
    final mutationsAfterStart = mutations;

    for (var tick = 0; tick < 10; tick++) {
      now = now.add(const Duration(seconds: 1));
      controller.refreshRemainingTime();
    }
    await Future<void>.delayed(Duration.zero);

    expect(storage.loadFocusRevision(), revisionAfterStart);
    expect(mutations, mutationsAfterStart);
  });

  test(
    'start pause resume complete and reset emit exactly five mutations',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = FocusDayStorage(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [focusDayStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      var mutations = 0;
      final subscription = container
          .read(syncMutationBusProvider)
          .changes
          .listen((_) => mutations++);
      addTearDown(subscription.cancel);
      final controller = container.read(focusTimerProvider.notifier);
      controller.start();
      controller.pause();
      controller.resume();
      controller.complete();
      controller.reset(projectId: 'dotnet', durationMinutes: 30);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(storage.loadFocusRevision(), 5);
      expect(mutations, 5);
    },
  );

  test(
    'local mutation during replaceFromCloud wins in state and storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = DelayedTimerStorage(
        await SharedPreferences.getInstance(),
      );
      final container = ProviderContainer(
        overrides: [focusDayStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final controller = container.read(focusTimerProvider.notifier);
      final replacement = controller.replaceFromCloud(
        const CloudFocusState(
          projectId: 'cloud-project',
          status: FocusTimerStatus.paused,
          initialSeconds: 3600,
          remainingSecondsWhenPaused: 1200,
        ),
        0,
      );
      await storage.writeEntered.future;
      controller.reset(projectId: 'local-project', durationMinutes: 30);
      storage.releaseWrite.complete();

      expect(await replacement, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(focusTimerProvider).projectId, 'local-project');
      expect(storage.loadTimer()?.projectId, 'local-project');
      expect(storage.loadFocusRevision(), 1);
    },
  );

  test('restart derives running remaining time from endTime', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    final now = DateTime.utc(2026, 9, 8, 12);
    await storage.saveTimer(
      FocusTimerState(
        projectId: 'bogoka',
        initialSeconds: 3600,
        remainingSeconds: 3599,
        status: FocusTimerStatus.running,
        endTime: now.add(const Duration(minutes: 15)),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        focusDayStorageProvider.overrideWithValue(storage),
        focusClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(focusTimerProvider).remainingSeconds, 900);
  });

  test('restart marks an expired running timer completed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    final now = DateTime.utc(2026, 9, 8, 12);
    await storage.saveTimer(
      FocusTimerState(
        projectId: 'bogoka',
        initialSeconds: 3600,
        remainingSeconds: 10,
        status: FocusTimerStatus.running,
        endTime: now.subtract(const Duration(seconds: 1)),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        focusDayStorageProvider.overrideWithValue(storage),
        focusClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(focusTimerProvider).status,
      FocusTimerStatus.completed,
    );
  });

  test('disabled completion sound prevents playback', () async {
    SharedPreferences.setMockInitialValues({
      'focusday.settings.completionSoundEnabled': false,
    });
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    final sound = RecordingSoundService();
    var now = DateTime.utc(2026, 9, 8, 12);
    final container = ProviderContainer(
      overrides: [
        focusDayStorageProvider.overrideWithValue(storage),
        focusClockProvider.overrideWithValue(() => now),
        focusCompletionSoundProvider.overrideWithValue(sound),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(focusTimerProvider.notifier);
    controller.reset(projectId: 'bogoka', durationMinutes: 1);
    controller.start();
    now = now.add(const Duration(minutes: 2));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      container.read(focusTimerProvider).status,
      FocusTimerStatus.completed,
    );
    expect(sound.playCount, 0);
  });
}
