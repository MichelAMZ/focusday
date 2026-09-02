import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/today/application/focus_timer_controller.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';

void main() {
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
}
