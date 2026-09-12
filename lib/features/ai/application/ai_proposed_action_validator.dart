import '../../projects/domain/focus_project.dart';
import '../../today/application/focus_timer_state.dart';
import '../domain/ai_assistant_models.dart';

class AiProposedActionValidator {
  const AiProposedActionValidator();

  static const maxActions = 10;
  static const maxTaskTitleLength = 120;
  static const maxTaskDescriptionLength = 500;
  static const maxProjectNotesLength = 5000;
  static const minFocusDurationMinutes = 1;
  static const maxFocusDurationMinutes = 480;

  bool validateAll(
    List<AiProposedAction> actions,
    FocusProject activeProject,
    FocusTimerState timer,
  ) =>
      actions.isNotEmpty &&
      actions.length <= maxActions &&
      !_hasContradictions(actions) &&
      actions.every((action) => validate(action, activeProject, timer));

  bool validate(
    AiProposedAction action,
    FocusProject project,
    FocusTimerState timer,
  ) {
    if (action.projectId != null && action.projectId != project.id) {
      return false;
    }
    final task = action.taskId == null
        ? null
        : project.tasks.where((item) => item.id == action.taskId).firstOrNull;
    return switch (action.type) {
      AiProposedActionType.addTask =>
        _text(action.title, maxTaskTitleLength) &&
            _optionalText(action.description, maxTaskDescriptionLength),
      AiProposedActionType.renameTask =>
        task != null && _text(action.newTitle, maxTaskTitleLength),
      AiProposedActionType.completeTask => task != null && !task.isCompleted,
      AiProposedActionType.reopenTask => task != null && task.isCompleted,
      AiProposedActionType.updateProjectNotes =>
        action.newNotes != null &&
            action.newNotes!.length <= maxProjectNotesLength,
      AiProposedActionType.startTimer =>
        timer.projectId == project.id &&
            (timer.status == FocusTimerStatus.idle ||
                timer.status == FocusTimerStatus.paused) &&
            timer.remainingSeconds > 0,
      AiProposedActionType.pauseTimer =>
        timer.projectId == project.id &&
            timer.status == FocusTimerStatus.running,
      AiProposedActionType.setFocusDuration =>
        action.durationMinutes != null &&
            action.durationMinutes! >= minFocusDurationMinutes &&
            action.durationMinutes! <= maxFocusDurationMinutes &&
            timer.status != FocusTimerStatus.running,
    };
  }

  bool _hasContradictions(List<AiProposedAction> actions) {
    final targets = <String>{};
    var timerActions = 0;
    for (final action in actions) {
      final target = switch (action.type) {
        AiProposedActionType.addTask =>
          'add:${action.title?.trim().toLowerCase()}',
        AiProposedActionType.completeTask ||
        AiProposedActionType.reopenTask => 'task:${action.taskId}',
        AiProposedActionType.renameTask => 'rename:${action.taskId}',
        _ => action.type.name,
      };
      if (!targets.add(target)) return true;
      if ([
        AiProposedActionType.startTimer,
        AiProposedActionType.pauseTimer,
        AiProposedActionType.setFocusDuration,
      ].contains(action.type)) {
        timerActions++;
      }
    }
    if (timerActions > 1) return true;
    return false;
  }

  bool _text(String? value, int max) =>
      value != null && value.trim().isNotEmpty && value.length <= max;
  bool _optionalText(String? value, int max) =>
      value == null || value.length <= max;
}
