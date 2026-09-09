import '../../projects/domain/focus_project.dart';
import '../../today/application/focus_timer_state.dart';
import '../domain/ai_assistant_models.dart';

class AiAssistantContextBuilder {
  const AiAssistantContextBuilder();

  AiAssistantContext build({
    required String language,
    required List<FocusProject> projects,
    required FocusTimerState timer,
  }) {
    FocusProject? activeProject;
    for (final project in projects) {
      if (project.status == FocusProjectStatus.active) {
        activeProject = project;
        break;
      }
    }

    return AiAssistantContext(
      language: language,
      focusRemainingSeconds:
          activeProject != null && timer.projectId == activeProject.id
          ? timer.remainingSeconds.clamp(0, timer.initialSeconds)
          : 0,
      activeProject: activeProject == null
          ? null
          : AiAssistantProjectContext(
              name: activeProject.name,
              tasks: [
                for (final task in activeProject.tasks)
                  AiAssistantTaskContext(
                    title: task.title,
                    completed: task.isCompleted,
                    localTaskId: task.id,
                  ),
              ],
              notes: activeProject.notes.trim().isEmpty
                  ? null
                  : activeProject.notes,
            ),
    );
  }
}
