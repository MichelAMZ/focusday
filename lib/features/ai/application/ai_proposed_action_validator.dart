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
      AiProposedActionType.setFocusDuration =>
        action.durationMinutes != null &&
            action.durationMinutes! >= minFocusDurationMinutes &&
            action.durationMinutes! <= maxFocusDurationMinutes &&
            timer.status != FocusTimerStatus.running,
    };
  }

  bool _hasContradictions(List<AiProposedAction> actions) {
    final taskTransitions = <String, AiProposedActionType>{};
    final taskRenames = <String, String>{};
    int? focusDuration;
    String? projectNotes;

    for (final action in actions) {
      switch (action.type) {
        case AiProposedActionType.completeTask:
        case AiProposedActionType.reopenTask:
          final taskId = action.taskId;
          if (taskId != null &&
              taskTransitions.putIfAbsent(taskId, () => action.type) !=
                  action.type) {
            return true;
          }
        case AiProposedActionType.renameTask:
          final taskId = action.taskId;
          final title = action.newTitle?.trim();
          if (taskId != null && title != null) {
            final previous = taskRenames.putIfAbsent(taskId, () => title);
            if (previous != title) return true;
          }
        case AiProposedActionType.setFocusDuration:
          final duration = action.durationMinutes;
          if (focusDuration != null && duration != focusDuration) return true;
          focusDuration = duration;
        case AiProposedActionType.updateProjectNotes:
          final notes = action.newNotes;
          if (projectNotes != null && notes != projectNotes) return true;
          projectNotes = notes;
        case AiProposedActionType.addTask:
          break;
      }
    }
    return false;
  }

  bool _text(String? value, int max) =>
      value != null && value.trim().isNotEmpty && value.length <= max;
  bool _optionalText(String? value, int max) =>
      value == null || value.length <= max;
}
