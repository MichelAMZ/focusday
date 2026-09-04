enum ProjectSchedulePhase { normal, soon, due }

class ProjectScheduleState {
  const ProjectScheduleState({required this.now});

  final DateTime now;

  ProjectSchedulePhase phaseFor(DateTime? scheduledAt) {
    if (scheduledAt == null) {
      return ProjectSchedulePhase.normal;
    }

    final difference = scheduledAt.difference(now);

    if (difference <= Duration.zero) {
      return ProjectSchedulePhase.due;
    }

    if (difference <= const Duration(minutes: 10)) {
      return ProjectSchedulePhase.soon;
    }

    return ProjectSchedulePhase.normal;
  }
}
