import '../domain/ai_assistant_models.dart';

String buildChatGptExport(AiAssistantContext context) {
  final fr = context.language == 'fr';
  final project = context.activeProject;
  return [
    '${fr ? "Langue" : "Language"}: ${context.language}',
    '${fr ? "Projet" : "Project"}: ${project?.name ?? (fr ? "Aucun projet actif" : "No active project")}',
    '${fr ? "Temps restant" : "Time remaining"}: ${context.focusRemainingSeconds ~/ 60} min ${context.focusRemainingSeconds % 60} s',
    '',
    fr ? 'Tâches:' : 'Tasks:',
    for (final task in project?.tasks ?? <AiAssistantTaskContext>[])
      '- [${task.completed ? "x" : " "}] ${task.title}',
    if (project?.notes != null) ...['', 'Notes:', project!.notes!],
    '',
    fr ? 'Demande:' : 'Request:',
    fr
        ? 'Aide-moi à déterminer la prochaine action utile. Donne uniquement des conseils ; aucune action ne sera exécutée automatiquement.'
        : 'Help me identify the next useful action. Give advice only; nothing will be executed automatically.',
  ].join('\n');
}
