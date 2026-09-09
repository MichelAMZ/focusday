import 'account_sync_executor.dart';
import 'focusday_sync_executor.dart';
import 'sync_decision.dart';

enum SyncConflictDomain { projects, settings, focus }

Future<SyncExecutionResult?> applySyncResolutionChoice(
  SyncResolutionChoice? choice,
  Future<SyncExecutionResult> Function(SyncResolutionChoice choice) apply,
) {
  if (choice == null) return Future.value();
  return apply(choice);
}

class SyncConflictResolver {
  const SyncConflictResolver({required this.projects, required this.account});

  final FocusDaySyncExecutor projects;
  final AccountSyncExecutor account;

  Future<List<SyncConflictDomain>> detect(String userId) async {
    final decisions = await Future.wait([
      projects.inspector.inspect(userId),
      account.inspectSettings(userId),
      account.inspectFocus(userId),
    ]);
    return [
      for (var index = 0; index < decisions.length; index++)
        if (decisions[index] == SyncDecision.conflict)
          SyncConflictDomain.values[index],
    ];
  }

  Future<SyncExecutionResult> resolve(
    String userId,
    SyncConflictDomain domain,
    SyncResolutionChoice choice,
  ) => switch (domain) {
    SyncConflictDomain.projects => projects.resolve(userId, choice),
    SyncConflictDomain.settings => account.resolveSettings(userId, choice),
    SyncConflictDomain.focus => account.resolveFocus(userId, choice),
  };
}
