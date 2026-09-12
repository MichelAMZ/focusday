import '../../today/application/focus_timer_controller.dart';
import '../../today/application/today_controller.dart';
import '../../projects/domain/focus_project.dart';
import '../domain/ai_assistant_models.dart';
import 'ai_proposed_action_validator.dart';

class AiActionExecutor {
  const AiActionExecutor({
    required this.projects,
    required this.timer,
    this.validator = const AiProposedActionValidator(),
  });

  final TodayProjectsController projects;
  final FocusTimerController timer;
  final AiProposedActionValidator validator;

  bool executeConfirmed(List<AiProposedAction> actions) {
    final currentProject = projects.currentProjects
        .where((project) => project.status == FocusProjectStatus.active)
        .firstOrNull;
    if (currentProject == null) return false;
    final currentTimer = timer.currentState;
    if (!validator.validateAll(actions, currentProject, currentTimer)) {
      return false;
    }
    for (final action in actions) {
      switch (action.type) {
        case AiProposedActionType.addTask:
          projects.addTask(
            projectId: currentProject.id,
            title: action.title!,
            description: action.description ?? '',
          );
        case AiProposedActionType.renameTask:
          final task = currentProject.tasks
              .where((item) => item.id == action.taskId)
              .first;
          projects.updateTask(
            projectId: currentProject.id,
            taskId: task.id,
            title: action.newTitle!,
            description: task.description,
          );
        case AiProposedActionType.completeTask:
        case AiProposedActionType.reopenTask:
          projects.toggleTask(currentProject.id, action.taskId!);
        case AiProposedActionType.updateProjectNotes:
          projects.updateProjectNotes(
            projectId: currentProject.id,
            notes: action.newNotes!,
          );
        case AiProposedActionType.startTimer:
          timer.start();
        case AiProposedActionType.pauseTimer:
          timer.pause();
        case AiProposedActionType.setFocusDuration:
          projects.updateProject(
            projectId: currentProject.id,
            name: currentProject.name,
            durationMinutes: action.durationMinutes!,
          );
          if (currentTimer.projectId == currentProject.id) {
            timer.reset(
              projectId: currentProject.id,
              durationMinutes: action.durationMinutes!,
            );
          }
      }
    }
    return true;
  }
}
