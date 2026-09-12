import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/ai_assistant_models.dart';
import '../domain/ai_chat_message.dart';
import '../infrastructure/ai_chat_history_store.dart';
import '../../projects/domain/focus_project.dart';
import '../infrastructure/http_ai_assistant_gateway.dart';
import '../../auth/application/auth_controller.dart';
import 'ai_provider_settings.dart';
import 'ai_diagnostics.dart';
import '../../today/application/focus_timer_controller.dart';
import '../../today/application/today_controller.dart';
import 'ai_action_executor.dart';
import 'ai_assistant_gateway.dart';

export '../domain/ai_chat_message.dart';

enum AiProposalStatus { pending, applying, applied, rejected, expired, failed }

class AiAssistantState {
  const AiAssistantState({
    this.messages = const [],
    this.isSending = false,
    this.error,
    this.conversationId,
    this.proposedActions = const [],
    this.proposalStatus,
    this.proposalProjectId,
    this.historyError = false,
    this.isClearingHistory = false,
  });
  final List<AiChatMessage> messages;
  final bool isSending;
  final AiAssistantErrorCategory? error;
  final String? conversationId;
  final List<AiProposedAction> proposedActions;
  final AiProposalStatus? proposalStatus;
  final String? proposalProjectId;
  final bool historyError;
  final bool isClearingHistory;

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isSending,
    AiAssistantErrorCategory? error,
    bool clearError = false,
    String? conversationId,
    List<AiProposedAction>? proposedActions,
    AiProposalStatus? proposalStatus,
    String? proposalProjectId,
    bool clearProposalStatus = false,
    bool? historyError,
  }) => AiAssistantState(
    historyError: historyError ?? this.historyError,
    isClearingHistory: isClearingHistory,
    proposalProjectId: proposalProjectId ?? this.proposalProjectId,
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

final aiBackendUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment('FOCUSDAY_AI_BACKEND_URL'),
);
final aiBackendUriProvider = Provider<Uri?>((ref) {
  final value = ref.watch(aiBackendUrlProvider).trim();
  return value.isEmpty ? null : Uri.tryParse(value);
});
final aiIdTokenProvider = Provider<FirebaseIdTokenProvider>(
  (ref) => FirebaseAuthIdTokenProvider(ref.read(firebaseAuthProvider)),
);
final aiPersonalKeyReaderProvider = Provider<String? Function()>(
  (ref) => () {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      throw const AiAssistantException(
        AiAssistantErrorCategory.unauthenticated,
        reason: AiDiagnosticReason.firebaseUserMissing,
      );
    }
    return ref.read(sessionAiKeyProvider).forOwner(user.uid);
  },
);
final aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
final aiAssistantGatewayProvider = Provider<AiAssistantGateway>((ref) {
  final settings = ref.watch(aiProviderSettingsProvider);
  final uri = ref.watch(aiBackendUriProvider);
  if (settings.mode != AiProviderMode.personalOpenAi &&
      settings.mode != AiProviderMode.focusday) {
    return const UnavailableAiAssistantGateway(
      reason: AiDiagnosticReason.providerNotConfigured,
    );
  }
  if (settings.mode == AiProviderMode.personalOpenAi &&
      !settings.keyConfigured) {
    return const UnavailableAiAssistantGateway(
      reason: AiDiagnosticReason.personalKeyMissing,
    );
  }
  if (uri == null || !isValidAiBackendUri(uri)) {
    return UnavailableAiAssistantGateway(
      category: AiAssistantErrorCategory.backendConfiguration,
      reason: ref.watch(aiBackendUrlProvider).trim().isEmpty && uri == null
          ? AiDiagnosticReason.backendUrlMissing
          : AiDiagnosticReason.backendUrlInvalid,
    );
  }
  final gateway = HttpAiAssistantGateway(
    baseUri: uri,
    tokenProvider: ref.watch(aiIdTokenProvider),
    personalKey: settings.mode == AiProviderMode.personalOpenAi
        ? ref.watch(aiPersonalKeyReaderProvider)
        : null,
    client: ref.watch(aiHttpClientProvider),
  );
  return gateway;
});
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
  int _generation = 0;
  AiChatHistoryStore? _historyStore;
  List<AiChatMessage> _history = const [];

  @override
  AiAssistantState build() {
    _historyStore = ref.read(aiChatHistoryStoreProvider);
    final saved = _historyStore?.load();
    _history = saved?.messages ?? const [];
    _nextId = 0;
    for (final message in _history) {
      final number = int.tryParse(message.id.replaceFirst('message-', ''));
      if (number != null && number >= _nextId) _nextId = number + 1;
    }
    ref.listen(aiProviderSettingsProvider, (_, next) {
      if (state.isClearingHistory) return;
      _generation++;
      _lastMessage = null;
      _lastContext = null;
      state = AiAssistantState(
        messages: next.mode == AiProviderMode.focusday ? _history : const [],
        historyError: state.historyError,
      );
    });
    ref.onDispose(() => _generation++);
    return AiAssistantState(
      messages: _history,
      historyError: saved?.invalid ?? false,
    );
  }

  Future<void> _persistHistory(int generation) async {
    if (ref.read(aiProviderSettingsProvider).mode != AiProviderMode.focusday) {
      return;
    }
    _history = List.unmodifiable(
      state.messages.skip(
        state.messages.length > AiChatHistoryStore.maxMessages
            ? state.messages.length - AiChatHistoryStore.maxMessages
            : 0,
      ),
    );
    state = state.copyWith(messages: _history);
    final saved = await _historyStore?.save(_history) ?? true;
    if (ref.mounted && generation == _generation) {
      state = state.copyWith(historyError: !saved);
    }
  }

  Future<void> clearHistory() async {
    if (state.isClearingHistory) return;
    final generation = ++_generation;
    _lastMessage = null;
    _lastContext = null;
    final previous = _history;
    // Invalidate all proposals and in-flight replies before the async delete.
    state = AiAssistantState(messages: state.messages, isClearingHistory: true);
    final cleared = await _historyStore?.clear() ?? true;
    if (!ref.mounted || generation != _generation) return;
    if (cleared) _history = const [];
    state = AiAssistantState(
      messages: cleared ? const [] : previous,
      historyError: !cleared,
    );
  }

  bool get _enabled {
    final config = ref.read(aiProviderSettingsProvider);
    return config.mode == AiProviderMode.focusday ||
        (config.mode == AiProviderMode.personalOpenAi && config.keyConfigured);
  }

  Future<void> send(String rawMessage, AiAssistantContext context) async {
    await _send(rawMessage, context, appendUserMessage: true);
  }

  Future<void> _send(
    String rawMessage,
    AiAssistantContext context, {
    required bool appendUserMessage,
  }) async {
    final message = rawMessage.trim();
    if (!_enabled) {
      debugAiFailure(
        ref.read(aiProviderSettingsProvider).mode !=
                AiProviderMode.personalOpenAi
            ? AiDiagnosticReason.providerNotConfigured
            : AiDiagnosticReason.personalKeyMissing,
      );
      return;
    }
    if (message.isEmpty || state.isSending || state.isClearingHistory) return;
    final projectId =
        context.activeProject?.localProjectId ??
        ref
            .read(todayProjectsProvider)
            .where((p) => p.status == FocusProjectStatus.active)
            .firstOrNull
            ?.id;
    final generation = _generation;
    _lastMessage = message;
    _lastContext = context;
    state = state.copyWith(
      messages: [
        ...state.messages,
        if (appendUserMessage)
          AiChatMessage(
            id: 'message-${_nextId++}',
            createdAt: DateTime.now().toUtc(),
            projectId: projectId,
            projectName: context.activeProject?.name,
            role: AiChatRole.user,
            text: message,
          ),
      ],
      isSending: true,
      clearError: true,
    );
    if (_historyStore != null) await _persistHistory(generation);
    if (!ref.mounted || generation != _generation || !_enabled) return;
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
      if (!ref.mounted || generation != _generation || !_enabled) return;
      state = state.copyWith(
        messages: [
          ...state.messages,
          AiChatMessage(
            id: 'message-${_nextId++}',
            createdAt: DateTime.now().toUtc(),
            projectId: projectId,
            projectName: context.activeProject?.name,
            role: AiChatRole.assistant,
            text: response.text,
          ),
        ],
        isSending: false,
        clearError: true,
        conversationId: response.conversationId,
        proposalProjectId: projectId,
        proposedActions: response.proposedActions
            .map((action) {
              var taskId = action.taskId;
              final match = RegExp(
                r'^focusday_task_(\d+)$',
              ).firstMatch(taskId ?? '');
              if (match != null) {
                final index = int.parse(match.group(1)!);
                final tasks =
                    context.activeProject?.tasks ??
                    const <AiAssistantTaskContext>[];
                taskId = index < tasks.length ? tasks[index].localTaskId : null;
              }
              return action.withTarget(projectId ?? '', taskId);
            })
            .toList(growable: false),
        proposalStatus: response.proposedActions.isEmpty
            ? null
            : AiProposalStatus.pending,
        clearProposalStatus: response.proposedActions.isEmpty,
      );
      await _persistHistory(generation);
    } on AiAssistantException catch (error) {
      if (!ref.mounted || generation != _generation || !_enabled) return;
      if (error.reason case final reason?) debugAiFailure(reason);
      state = state.copyWith(isSending: false, error: error.category);
    } catch (_) {
      if (!ref.mounted || generation != _generation || !_enabled) return;
      debugAiFailure(AiDiagnosticReason.gatewayNotCreated);
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
    if (!_enabled || state.proposalStatus != AiProposalStatus.pending) return;
    state = state.copyWith(proposalStatus: AiProposalStatus.applying);
    try {
      final applied = ref
          .read(aiActionExecutorProvider)
          .executeConfirmed(state.proposedActions);
      state = state.copyWith(
        proposalStatus: applied
            ? AiProposalStatus.applied
            : AiProposalStatus.expired,
      );
    } catch (_) {
      state = state.copyWith(proposalStatus: AiProposalStatus.failed);
    }
  }

  Future<void> retry() async {
    final message = _lastMessage;
    final context = _lastContext;
    if (message == null ||
        context == null ||
        state.isSending ||
        state.error == null) {
      return;
    }
    await _send(message, context, appendUserMessage: false);
  }
}
