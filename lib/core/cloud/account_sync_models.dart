import '../../features/today/application/focus_timer_state.dart';

class SyncedSettings {
  const SyncedSettings({
    required this.completionSoundEnabled,
    required this.scheduledProjectAlertsEnabled,
    required this.languagePreference,
  });

  final bool completionSoundEnabled;
  final bool scheduledProjectAlertsEnabled;
  final String languagePreference;
}

class CloudFocusState {
  const CloudFocusState({
    required this.projectId,
    required this.status,
    required this.initialSeconds,
    this.remainingSecondsWhenPaused,
    this.endsAt,
  });

  final String projectId;
  final FocusTimerStatus status;
  final int initialSeconds;
  final int? remainingSecondsWhenPaused;
  final DateTime? endsAt;

  factory CloudFocusState.fromLocal(FocusTimerState state) => CloudFocusState(
    projectId: state.projectId,
    status: state.status,
    initialSeconds: state.initialSeconds,
    remainingSecondsWhenPaused: state.status == FocusTimerStatus.running
        ? null
        : state.remainingSeconds,
    endsAt: state.status == FocusTimerStatus.running ? state.endTime : null,
  );

  FocusTimerState toLocal(DateTime now) {
    if (status == FocusTimerStatus.running && endsAt != null) {
      final milliseconds = endsAt!.difference(now).inMilliseconds;
      if (milliseconds <= 0) {
        return FocusTimerState(
          projectId: projectId,
          initialSeconds: initialSeconds,
          remainingSeconds: 0,
          status: FocusTimerStatus.completed,
        );
      }
      return FocusTimerState(
        projectId: projectId,
        initialSeconds: initialSeconds,
        remainingSeconds: (milliseconds / 1000).ceil(),
        status: status,
        endTime: endsAt,
      );
    }
    return FocusTimerState(
      projectId: projectId,
      initialSeconds: initialSeconds,
      remainingSeconds: remainingSecondsWhenPaused ?? initialSeconds,
      status: status == FocusTimerStatus.running
          ? FocusTimerStatus.paused
          : status,
    );
  }
}

class CloudValue<T> {
  const CloudValue(this.value, this.updatedAt, {this.generation = 0});
  final T value;
  final DateTime? updatedAt;
  final int generation;
}
