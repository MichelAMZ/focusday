enum FocusTimerStatus { idle, running, paused, completed }

class FocusTimerState {
  const FocusTimerState({
    required this.projectId,
    required this.initialSeconds,
    required this.remainingSeconds,
    this.status = FocusTimerStatus.idle,
    this.endTime,
  });

  final String projectId;
  final int initialSeconds;
  final int remainingSeconds;
  final FocusTimerStatus status;

  /// Heure réelle à laquelle le chrono doit atteindre zéro.
  ///
  /// Utilisé uniquement lorsque le chrono est en cours.
  final DateTime? endTime;

  bool get isRunning => status == FocusTimerStatus.running;

  bool get isPaused => status == FocusTimerStatus.paused;

  bool get isCompleted => status == FocusTimerStatus.completed;

  FocusTimerState copyWith({
    String? projectId,
    int? initialSeconds,
    int? remainingSeconds,
    FocusTimerStatus? status,
    DateTime? endTime,
    bool clearEndTime = false,
  }) {
    return FocusTimerState(
      projectId: projectId ?? this.projectId,
      initialSeconds: initialSeconds ?? this.initialSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      status: status ?? this.status,
      endTime: clearEndTime ? null : endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'initialSeconds': initialSeconds,
      'remainingSeconds': remainingSeconds,
      'status': status.name,
      'endTime': endTime?.toIso8601String(),
    };
  }

  factory FocusTimerState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? FocusTimerStatus.idle.name;

    final status = FocusTimerStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => FocusTimerStatus.idle,
    );

    final endTimeRaw = json['endTime'] as String?;

    return FocusTimerState(
      projectId: json['projectId'] as String,
      initialSeconds: json['initialSeconds'] as int,
      remainingSeconds: json['remainingSeconds'] as int,
      status: status,
      endTime: endTimeRaw == null ? null : DateTime.tryParse(endTimeRaw),
    );
  }
}
