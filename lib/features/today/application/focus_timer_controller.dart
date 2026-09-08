import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import 'focus_timer_state.dart';
import '../../../core/audio/focus_completion_sound_provider.dart';
import '../../../core/cloud/account_sync_models.dart';
import '../../../core/cloud/sync_mutation_bus.dart';
import '../../settings/application/settings_controller.dart';

final focusClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final focusTimerProvider =
    NotifierProvider<FocusTimerController, FocusTimerState>(
      FocusTimerController.new,
    );

class FocusTimerController extends Notifier<FocusTimerState> {
  Timer? _ticker;
  Future<void> _persistence = Future.value();
  int _mutationGeneration = 0;

  @override
  FocusTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });

    final storage = ref.watch(focusDayStorageProvider);
    final savedTimer = storage?.loadTimer();

    if (savedTimer == null) {
      return const FocusTimerState(
        projectId: 'bogoka',
        initialSeconds: 60 * 60,
        remainingSeconds: 60 * 60,
      );
    }

    if (savedTimer.status != FocusTimerStatus.running) {
      return savedTimer;
    }

    final endTime = savedTimer.endTime;

    if (endTime == null) {
      return savedTimer.copyWith(
        status: FocusTimerStatus.paused,
        clearEndTime: true,
      );
    }

    final milliseconds = endTime.difference(_now()).inMilliseconds;

    if (milliseconds <= 0) {
      final completedState = savedTimer.copyWith(
        remainingSeconds: 0,
        status: FocusTimerStatus.completed,
        clearEndTime: true,
      );

      storage?.saveTimer(completedState);

      return completedState;
    }

    final remainingSeconds = (milliseconds / 1000).ceil();

    final restoredState = savedTimer.copyWith(
      remainingSeconds: remainingSeconds,
    );

    _startTicker();

    return restoredState;
  }

  void start() {
    if (state.status == FocusTimerStatus.running ||
        state.status == FocusTimerStatus.completed) {
      return;
    }

    if (state.remainingSeconds <= 0) {
      return;
    }

    final endTime = _now().add(Duration(seconds: state.remainingSeconds));

    state = state.copyWith(status: FocusTimerStatus.running, endTime: endTime);

    _persist();
    _startTicker();
  }

  void pause() {
    if (state.status != FocusTimerStatus.running) {
      return;
    }

    refreshRemainingTime();
    _ticker?.cancel();

    state = state.copyWith(status: FocusTimerStatus.paused, clearEndTime: true);

    _persist();
  }

  void resume() {
    if (state.status != FocusTimerStatus.paused) {
      return;
    }

    start();
  }

  void addMinutes(int minutes) {
    if (minutes <= 0) {
      return;
    }

    final secondsToAdd = minutes * 60;

    if (state.status == FocusTimerStatus.running) {
      final currentRemaining = _calculateRemainingSeconds();

      final newRemaining = currentRemaining + secondsToAdd;

      final newEndTime = _now().add(Duration(seconds: newRemaining));

      state = state.copyWith(
        initialSeconds: state.initialSeconds + secondsToAdd,
        remainingSeconds: newRemaining,
        endTime: newEndTime,
      );

      _persist();

      return;
    }

    state = state.copyWith(
      initialSeconds: state.initialSeconds + secondsToAdd,
      remainingSeconds: state.remainingSeconds + secondsToAdd,
    );

    _persist();
  }

  void complete() {
    _ticker?.cancel();

    state = state.copyWith(
      remainingSeconds: 0,
      status: FocusTimerStatus.completed,
      clearEndTime: true,
    );

    _persist();
  }

  void reset({required String projectId, required int durationMinutes}) {
    _ticker?.cancel();

    final seconds = durationMinutes * 60;

    state = FocusTimerState(
      projectId: projectId,
      initialSeconds: seconds,
      remainingSeconds: seconds,
    );

    _persist();
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshRemainingTime(),
    );
  }

  /// Refreshes display state from the deterministic deadline.
  /// Non-terminal ticks are deliberately local-only.
  void refreshRemainingTime() {
    if (state.status != FocusTimerStatus.running) {
      return;
    }

    final remaining = _calculateRemainingSeconds();

    if (remaining <= 0) {
      _ticker?.cancel();

      state = state.copyWith(
        remainingSeconds: 0,
        status: FocusTimerStatus.completed,
        clearEndTime: true,
      );

      _persist();

      if (ref.read(settingsProvider).completionSoundEnabled) {
        unawaited(ref.read(focusCompletionSoundProvider).play());
      }
      return;
    }

    state = state.copyWith(remainingSeconds: remaining);
  }

  int _calculateRemainingSeconds() {
    final endTime = state.endTime;

    if (endTime == null) {
      return state.remainingSeconds;
    }

    final milliseconds = endTime.difference(_now()).inMilliseconds;

    if (milliseconds <= 0) {
      return 0;
    }

    // Arrondi supérieur pour éviter que 59,8 secondes
    // apparaissent immédiatement comme 00:00:59.
    return (milliseconds / 1000).ceil();
  }

  DateTime _now() => ref.read(focusClockProvider)();

  Future<bool> replaceFromCloud(CloudFocusState cloud, int expectedRevision) {
    final storage = ref.read(focusDayStorageProvider);
    if (storage == null || storage.loadFocusRevision() != expectedRevision) {
      return Future.value(false);
    }
    final expectedGeneration = _mutationGeneration;
    final operation = _persistence.then((_) async {
      if (_mutationGeneration != expectedGeneration ||
          storage.loadFocusRevision() != expectedRevision) {
        return false;
      }
      final downloaded = cloud.toLocal(_now());
      await storage.saveTimer(downloaded);
      if (_mutationGeneration != expectedGeneration ||
          storage.loadFocusRevision() != expectedRevision) {
        // A local mutation occurred while SharedPreferences was awaiting its
        // write. Restore the newer in-memory snapshot before returning.
        await storage.saveTimer(state);
        return false;
      }
      _ticker?.cancel();
      state = downloaded;
      if (downloaded.status == FocusTimerStatus.running) _startTicker();
      return true;
    });
    _persistence = operation.then<void>((_) {});
    return operation;
  }

  void _persist() {
    final storage = ref.read(focusDayStorageProvider);

    if (storage == null) {
      return;
    }

    final snapshot = state;
    _mutationGeneration++;
    _persistence = _persistence.then((_) async {
      await storage.saveTimer(snapshot);
      await storage.incrementFocusRevision();
      ref.read(syncMutationBusProvider).notify(SyncDomain.focus);
    });
    unawaited(_persistence);
  }
}
