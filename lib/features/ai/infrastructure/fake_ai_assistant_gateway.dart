import '../application/ai_assistant_gateway.dart';
import '../domain/ai_assistant_models.dart';

class FakeAiAssistantGateway implements AiAssistantGateway {
  const FakeAiAssistantGateway({
    this.delay = const Duration(milliseconds: 250),
  });
  final Duration delay;

  @override
  Future<AiResponse> respond(AiRequest request) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final french = request.context.language == 'fr';
    final normalized = request.message.toLowerCase();
    final text = normalized.contains('résum') || normalized.contains('summar')
        ? (french
              ? 'Votre projet actif regroupe les tâches et notes affichées. Choisissez une prochaine action concrète.'
              : 'Your active project contains the displayed tasks and notes. Choose one concrete next action.')
        : normalized.contains('découp') || normalized.contains('break')
        ? (french
              ? 'Découpez le travail en une première étape courte, un contrôle, puis une validation.'
              : 'Break the work into a short first step, a review, then a validation.')
        : (french
              ? 'Commencez par la première tâche active et avancez pendant un court bloc de concentration.'
              : 'Start with the first active task and work on it for one short focus block.');
    final firstActiveTask = request.context.activeProject?.tasks
        .where((task) => !task.completed)
        .firstOrNull;
    final actions =
        normalized.contains('découp') || normalized.contains('break')
        ? const [
            AiProposedAction(
              type: AiProposedActionType.addTask,
              title: 'Préparer le contenu',
            ),
            AiProposedAction(
              type: AiProposedActionType.addTask,
              title: 'Vérifier le résultat',
            ),
            AiProposedAction(
              type: AiProposedActionType.addTask,
              title: 'Valider la prochaine étape',
            ),
          ]
        : (normalized.contains('marque') || normalized.contains('complete')) &&
              firstActiveTask?.localTaskId != null
        ? [
            AiProposedAction(
              type: AiProposedActionType.completeTask,
              taskId: firstActiveTask!.localTaskId,
            ),
          ]
        : normalized.contains('25')
        ? const [
            AiProposedAction(
              type: AiProposedActionType.setFocusDuration,
              durationMinutes: 25,
            ),
          ]
        : const <AiProposedAction>[];
    return AiResponse(
      text: text,
      conversationId: request.conversationId ?? 'fake-conversation',
      proposedActions: actions,
    );
  }
}
