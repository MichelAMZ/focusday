import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/cloud/account_sync_models.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';

void main() {
  final now = DateTime.utc(2026, 9, 8, 12);

  test('running is restored from the shared endsAt', () {
    final cloud = CloudFocusState(
      projectId: 'bogoka',
      status: FocusTimerStatus.running,
      initialSeconds: 3600,
      endsAt: now.add(const Duration(minutes: 25)),
    );
    final local = cloud.toLocal(now);
    expect(local.remainingSeconds, 1500);
    expect(local.endTime, cloud.endsAt);
    expect(local.status, FocusTimerStatus.running);
  });

  test('expired running timer becomes completed', () {
    final cloud = CloudFocusState(
      projectId: 'bogoka',
      status: FocusTimerStatus.running,
      initialSeconds: 3600,
      endsAt: now.subtract(const Duration(seconds: 1)),
    );
    final local = cloud.toLocal(now);
    expect(local.status, FocusTimerStatus.completed);
    expect(local.remainingSeconds, 0);
  });

  test('paused timer keeps its remaining snapshot and no endsAt', () {
    const local = FocusTimerState(
      projectId: 'dotnet',
      initialSeconds: 1800,
      remainingSeconds: 725,
      status: FocusTimerStatus.paused,
    );
    final cloud = CloudFocusState.fromLocal(local);
    expect(cloud.remainingSecondsWhenPaused, 725);
    expect(cloud.endsAt, isNull);
    expect(cloud.toLocal(now).remainingSeconds, 725);
  });
}
