import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_assistant_models.dart';
import '../infrastructure/fake_ai_assistant_gateway.dart';
import 'ai_assistant_gateway.dart';

enum AiChatRole { user, assistant }

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
  });
  final List<AiChatMessage> messages;
  final bool isSending;
  final AiAssistantErrorCategory? error;
  final String? conversationId;

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isSending,
    AiAssistantErrorCategory? error,
    bool clearError = false,
    String? conversationId,
  }) => AiAssistantState(
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    error: clearError ? null : error ?? this.error,
    conversationId: conversationId ?? this.conversationId,
  );
}

final aiAssistantGatewayProvider = Provider<AiAssistantGateway>(
  (ref) => const FakeAiAssistantGateway(),
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

  Future<void> retry() async {
    final message = _lastMessage;
    final context = _lastContext;
    if (message == null || context == null || state.isSending) return;
    await send(message, context);
  }
}
