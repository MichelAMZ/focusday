import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_assistant_models.dart';
import '../infrastructure/fake_ai_assistant_gateway.dart';
import '../../today/application/focus_timer_controller.dart';
import '../../today/application/today_controller.dart';
import 'ai_action_executor.dart';
import 'ai_assistant_gateway.dart';

enum AiChatRole { user, assistant }

enum AiProposalStatus { pending, applying, applied, rejected, expired }

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
  });
  final String id;
  final AiChatRole role;
  final String text;
}

class AiAssistantState {
  const AiAssistantState({
    this.messages = const [],
    this.isSending = false,
    this.error,
    this.conversationId,
    this.proposedActions = const [],
    this.proposalStatus,
  });
  final List<AiChatMessage> messages;
  final bool isSending;
  final AiAssistantErrorCategory? error;
  final String? conversationId;
  final List<AiProposedAction> proposedActions;
  final AiProposalStatus? proposalStatus;

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isSending,
    AiAssistantErrorCategory? error,
    bool clearError = false,
    String? conversationId,
    List<AiProposedAction>? proposedActions,
    AiProposalStatus? proposalStatus,
    bool clearProposalStatus = false,
  }) => AiAssistantState(
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    error: clearError ? null : error ?? this.error,
    conversationId: conversationId ?? this.conversationId,
    proposedActions: proposedActions ?? this.proposedActions,
    proposalStatus: clearProposalStatus
        ? null
        : proposalStatus ?? this.proposalStatus,
  );
}

final aiAssistantGatewayProvider = Provider<AiAssistantGateway>(
  (ref) => const FakeAiAssistantGateway(),
);
final aiActionExecutorProvider = Provider<AiActionExecutor>(
  (ref) => AiActionExecutor(
    projects: ref.read(todayProjectsProvider.notifier),
    timer: ref.read(focusTimerProvider.notifier),
  ),
);
final aiAssistantControllerProvider =
    NotifierProvider<AiAssistantController, AiAssistantState>(
      AiAssistantController.new,
    );

class AiAssistantController extends Notifier<AiAssistantState> {
  int _nextId = 0;
  String? _lastMessage;
  AiAssistantContext? _lastContext;

  @override
  AiAssistantState build() => const AiAssistantState();

  Future<void> send(String rawMessage, AiAssistantContext context) async {
    final message = rawMessage.trim();
    if (message.isEmpty || state.isSending) return;
    _lastMessage = message;
    _lastContext = context;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AiChatMessage(
          id: 'message-${_nextId++}',
          role: AiChatRole.user,
          text: message,
        ),
      ],
      isSending: true,
      clearError: true,
    );
    try {
      final response = await ref
          .read(aiAssistantGatewayProvider)
          .respond(
            AiRequest(
              message: message,
              conversationId: state.conversationId,
              context: context,
            ),
          );
      state = state.copyWith(
        messages: [
          ...state.messages,
          AiChatMessage(
            id: 'message-${_nextId++}',
            role: AiChatRole.assistant,
            text: response.text,
          ),
        ],
        isSending: false,
        clearError: true,
        conversationId: response.conversationId,
        proposedActions: response.proposedActions,
        proposalStatus: response.proposedActions.isEmpty
            ? null
            : AiProposalStatus.pending,
        clearProposalStatus: response.proposedActions.isEmpty,
      );
    } on AiAssistantException catch (error) {
      state = state.copyWith(isSending: false, error: error.category);
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        error: AiAssistantErrorCategory.serverError,
      );
    }
  }

  void rejectProposals() {
    if (state.proposalStatus != AiProposalStatus.pending) return;
    state = state.copyWith(proposalStatus: AiProposalStatus.rejected);
  }

  void confirmProposals() {
    if (state.proposalStatus != AiProposalStatus.pending) return;
    state = state.copyWith(proposalStatus: AiProposalStatus.applying);
    final applied = ref
        .read(aiActionExecutorProvider)
        .executeConfirmed(state.proposedActions);
    state = state.copyWith(
      proposalStatus: applied
          ? AiProposalStatus.applied
          : AiProposalStatus.expired,
    );
  }

  Future<void> retry() async {
    final message = _lastMessage;
    final context = _lastContext;
    if (message == null || context == null || state.isSending) return;
    await send(message, context);
  }
}
