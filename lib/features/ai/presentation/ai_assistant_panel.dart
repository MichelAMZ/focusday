import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../projects/domain/focus_project.dart';
import '../../today/application/focus_timer_state.dart';
import '../application/ai_assistant_context_builder.dart';
import '../application/ai_assistant_controller.dart';
import '../domain/ai_assistant_models.dart';

class AiAssistantPage extends StatelessWidget {
  const AiAssistantPage({
    required this.projects,
    required this.timer,
    super.key,
  });
  final List<FocusProject> projects;
  final FocusTimerState timer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_outlined),
          const SizedBox(width: 10),
          Text(AppLocalizations.of(context)!.aiAssistantTitle),
        ],
      ),
    ),
    body: SafeArea(
      child: AiAssistantPanel(
        projects: projects,
        timer: timer,
        isDedicatedPage: true,
      ),
    ),
  );
}

class AiAssistantPanel extends ConsumerStatefulWidget {
  const AiAssistantPanel({
    required this.projects,
    required this.timer,
    this.isDedicatedPage = false,
    super.key,
  });
  final List<FocusProject> projects;
  final FocusTimerState timer;
  final bool isDedicatedPage;

  @override
  ConsumerState<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends ConsumerState<AiAssistantPanel> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  AiAssistantContext _context() => const AiAssistantContextBuilder().build(
    language: Localizations.localeOf(context).languageCode,
    projects: widget.projects,
    timer: widget.timer,
  );

  Future<void> _send([String? suggestion]) async {
    final text = suggestion ?? _textController.text;
    if (text.trim().isEmpty) return;
    if (suggestion == null) _textController.clear();
    await ref
        .read(aiAssistantControllerProvider.notifier)
        .send(text, _context());
    if (!mounted) return;
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(aiAssistantControllerProvider);
    final suggestions = [
      l10n.aiSuggestionNext,
      l10n.aiSuggestionBreakDown,
      l10n.aiSuggestionPrioritize,
      l10n.aiSuggestionSummary,
    ];
    final activeProjectName = _context().activeProject?.name;
    final contextLabel = activeProjectName == null
        ? l10n.aiAssistantContextNone
        : l10n.aiAssistantContextProject(activeProjectName);
    final panel = Card(
      margin: EdgeInsets.all(widget.isDedicatedPage ? 16 : 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.isDedicatedPage)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  contextLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.aiAssistantTitle),
              subtitle: Text(contextLabel),
            ),
          const Divider(height: 1),
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              l10n.aiAssistantEmptyTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final twoColumns =
                                    constraints.maxWidth >= 560 &&
                                    widget.isDedicatedPage;
                                final itemWidth = twoColumns
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth;
                                return Wrap(
                                  key: const Key('ai-suggestions'),
                                  spacing: 12,
                                  runSpacing: 10,
                                  children: [
                                    for (
                                      var index = 0;
                                      index < suggestions.length;
                                      index++
                                    )
                                      SizedBox(
                                        key: Key('ai-suggestion-$index'),
                                        width: itemWidth,
                                        child: OutlinedButton(
                                          onPressed: state.isSending
                                              ? null
                                              : () => _send(suggestions[index]),
                                          child: Text(suggestions[index]),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        state.messages.length +
                        (state.proposedActions.isEmpty ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return _AiProposalCard(
                          actions: state.proposedActions,
                          status:
                              state.proposalStatus ?? AiProposalStatus.expired,
                          project: widget.projects
                              .where(
                                (project) =>
                                    project.status == FocusProjectStatus.active,
                              )
                              .firstOrNull,
                          timer: widget.timer,
                          onConfirm: () => ref
                              .read(aiAssistantControllerProvider.notifier)
                              .confirmProposals(),
                          onReject: () => ref
                              .read(aiAssistantControllerProvider.notifier)
                              .rejectProposals(),
                        );
                      }
                      final message = state.messages[index];
                      final user = message.role == AiChatRole.user;
                      return Semantics(
                        label: user ? 'User message' : 'Assistant message',
                        child: Align(
                          alignment: user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: FractionallySizedBox(
                            key: Key(
                              user ? 'ai-user-bubble' : 'ai-assistant-bubble',
                            ),
                            widthFactor: user ? 0.72 : 0.78,
                            alignment: user
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              color: user
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: SelectableText(message.text),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (state.isSending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(l10n.aiSending),
                ],
              ),
            ),
          if (state.error != null)
            MaterialBanner(
              content: Text(_errorMessage(l10n, state.error!)),
              actions: [
                TextButton(
                  onPressed: state.isSending
                      ? null
                      : () => ref
                            .read(aiAssistantControllerProvider.notifier)
                            .retry(),
                  child: Text(l10n.aiRetry),
                ),
              ],
            ),
          const Divider(height: 1),
          Padding(
            key: const Key('ai-composer'),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): () =>
                          _send(),
                    },
                    child: TextField(
                      key: const Key('ai-message-input'),
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !state.isSending,
                      decoration: InputDecoration(
                        hintText: l10n.aiInputHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('ai-send-button'),
                  tooltip: l10n.aiSend,
                  onPressed: state.isSending ? null : _send,
                  icon: const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!widget.isDedicatedPage) return panel;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SizedBox(width: double.infinity, child: panel),
      ),
    );
  }

  String _errorMessage(
    AppLocalizations l10n,
    AiAssistantErrorCategory category,
  ) => switch (category) {
    AiAssistantErrorCategory.unauthenticated => l10n.aiErrorUnauthenticated,
    AiAssistantErrorCategory.unavailable => l10n.aiErrorUnavailable,
    AiAssistantErrorCategory.timeout => l10n.aiErrorTimeout,
    AiAssistantErrorCategory.rateLimited => l10n.aiErrorRateLimited,
    AiAssistantErrorCategory.invalidRequest => l10n.aiErrorInvalidRequest,
    AiAssistantErrorCategory.serverError => l10n.aiErrorServer,
  };
}

class _AiProposalCard extends StatelessWidget {
  const _AiProposalCard({
    required this.actions,
    required this.status,
    required this.project,
    required this.timer,
    required this.onConfirm,
    required this.onReject,
  });

  final List<AiProposedAction> actions;
  final AiProposalStatus status;
  final FocusProject? project;
  final FocusTimerState timer;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pending = status == AiProposalStatus.pending;
    final applicable = project != null;
    final addCount = actions
        .where((action) => action.type == AiProposedActionType.addTask)
        .length;
    final confirmLabel = addCount == actions.length
        ? l10n.aiProposalAdd
        : l10n.aiProposalConfirm;

    return Semantics(
      container: true,
      label: l10n.aiProposalTitle,
      child: Card.outlined(
        key: const Key('ai-proposal-card'),
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_fix_high_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.aiProposalTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (status == AiProposalStatus.applying)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                applicable
                    ? l10n.aiProposalProject(project!.name)
                    : l10n.aiAssistantContextNone,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (addCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    addCount == 1
                        ? l10n.aiProposalAddTask
                        : l10n.aiProposalAddTasks(addCount),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              for (final action in actions) ...[
                _actionContent(context, action),
                const SizedBox(height: 8),
              ],
              if (status == AiProposalStatus.applied)
                _status(
                  context,
                  Icons.check_circle_outline,
                  l10n.aiProposalApplied,
                ),
              if (status == AiProposalStatus.rejected)
                _status(context, Icons.block_outlined, l10n.aiProposalRejected),
              if (status == AiProposalStatus.expired || !applicable)
                _status(context, Icons.info_outline, l10n.aiProposalExpired),
              if (pending && applicable) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('ai-proposal-reject'),
                        onPressed: onReject,
                        child: Text(l10n.aiProposalReject),
                      ),
                      FilledButton(
                        key: const Key('ai-proposal-confirm'),
                        onPressed: onConfirm,
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionContent(BuildContext context, AiProposedAction action) {
    final l10n = AppLocalizations.of(context)!;
    final task = action.taskId == null
        ? null
        : project?.tasks.where((task) => task.id == action.taskId).firstOrNull;
    return switch (action.type) {
      AiProposedActionType.addTask => _line(
        context,
        '• ${action.title}',
        detail: action.description,
      ),
      AiProposedActionType.renameTask => _line(
        context,
        l10n.aiProposalRenameTask,
        detail: '${task?.title ?? l10n.aiProposalInvalid} → ${action.newTitle}',
      ),
      AiProposedActionType.completeTask => _line(
        context,
        l10n.aiProposalCompleteTask,
        detail: task?.title ?? l10n.aiProposalInvalid,
      ),
      AiProposedActionType.reopenTask => _line(
        context,
        l10n.aiProposalReopenTask,
        detail: task?.title ?? l10n.aiProposalInvalid,
      ),
      AiProposedActionType.updateProjectNotes => _line(
        context,
        l10n.aiProposalUpdateNotes,
        detail:
            '${l10n.aiProposalBefore}: ${_preview(project?.notes ?? '')}\n'
            '${l10n.aiProposalAfter}: ${_preview(action.newNotes ?? '')}',
      ),
      AiProposedActionType.setFocusDuration => _line(
        context,
        l10n.aiProposalFocusDuration,
        detail:
            '${project?.durationMinutes ?? timer.initialSeconds ~/ 60} '
            '${l10n.aiProposalMinutes} → ${action.durationMinutes} '
            '${l10n.aiProposalMinutes}',
      ),
    };
  }

  Widget _line(BuildContext context, String title, {String? detail}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        if (detail != null && detail.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 12),
            child: Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    ),
  );

  Widget _status(BuildContext context, IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Flexible(child: Text(label)),
    ],
  );

  String _preview(String value) {
    const maxLength = 140;
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= maxLength
        ? compact
        : '${compact.substring(0, maxLength - 1)}…';
  }
}
