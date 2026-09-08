import '../storage/focusday_storage.dart';
import 'account_sync_gateway.dart';
import 'account_sync_models.dart';
import 'focusday_sync_executor.dart';
import 'sync_decision.dart';

typedef SettingsApplier =
    Future<bool> Function(SyncedSettings value, int expectedRevision);
typedef FocusApplier =
    Future<bool> Function(CloudFocusState value, int expectedRevision);

class AccountSyncExecutor {
  AccountSyncExecutor({
    required this.gateway,
    required this.storage,
    required this.applySettings,
    required this.applyFocus,
  });

  final AccountSyncGateway gateway;
  final FocusDayStorage storage;
  final SettingsApplier applySettings;
  final FocusApplier applyFocus;

  Future<SyncExecutionResult> executeSettings(String userId) async {
    final revision = storage.loadSettingsRevision();
    final cloud = await gateway.loadSettings(userId);
    final localChanged = revision != storage.loadLastSyncedSettingsRevision();
    final decision = _decideDomain(
      localChanged: localChanged,
      localLastSyncAt: storage.loadSettingsLastSyncAt(),
      cloudLastSyncAt: cloud?.updatedAt,
    );
    if (decision == SyncDecision.firstSync) {
      return SyncExecutionResult.firstSync;
    }
    if (decision == SyncDecision.conflict) return SyncExecutionResult.conflict;
    if (decision == SyncDecision.noAction) return SyncExecutionResult.noAction;
    if (decision == SyncDecision.upload) {
      final value = SyncedSettings(
        completionSoundEnabled: storage.loadCompletionSoundEnabled(),
        scheduledProjectAlertsEnabled: storage
            .loadScheduledProjectAlertsEnabled(),
        languagePreference: storage.loadLanguagePreference() ?? 'system',
      );
      final updatedAt = await gateway.saveSettings(userId, value);
      await storage.saveSettingsLastSyncAt(updatedAt);
      await storage.saveLastSyncedSettingsRevision(revision);
      return storage.loadSettingsRevision() == revision
          ? SyncExecutionResult.uploaded
          : SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud == null) return SyncExecutionResult.noAction;
    if (storage.loadSettingsRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    final applied = await applySettings(cloud.value, revision);
    if (!applied || storage.loadSettingsRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    await storage.saveSettingsLastSyncAt(cloud.updatedAt);
    await storage.saveLastSyncedSettingsRevision(revision);
    return SyncExecutionResult.downloaded;
  }

  Future<SyncExecutionResult> executeFocus(String userId) async {
    final revision = storage.loadFocusRevision();
    final cloud = await gateway.loadFocus(userId);
    final localChanged = revision != storage.loadLastSyncedFocusRevision();
    final decision = _decideDomain(
      localChanged: localChanged,
      localLastSyncAt: storage.loadFocusLastSyncAt(),
      cloudLastSyncAt: cloud?.updatedAt,
    );
    if (decision == SyncDecision.firstSync) {
      return SyncExecutionResult.firstSync;
    }
    if (decision == SyncDecision.conflict) return SyncExecutionResult.conflict;
    if (decision == SyncDecision.noAction) return SyncExecutionResult.noAction;
    if (decision == SyncDecision.upload) {
      final timer = storage.loadTimer();
      if (timer == null) return SyncExecutionResult.noAction;
      final updatedAt = await gateway.saveFocus(
        userId,
        CloudFocusState.fromLocal(timer),
      );
      await storage.saveFocusLastSyncAt(updatedAt);
      await storage.saveLastSyncedFocusRevision(revision);
      return storage.loadFocusRevision() == revision
          ? SyncExecutionResult.uploaded
          : SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud == null) return SyncExecutionResult.noAction;
    if (storage.loadFocusRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    final applied = await applyFocus(cloud.value, revision);
    if (!applied || storage.loadFocusRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    await storage.saveFocusLastSyncAt(cloud.updatedAt);
    await storage.saveLastSyncedFocusRevision(revision);
    return SyncExecutionResult.downloaded;
  }

  SyncDecision _decideDomain({
    required bool localChanged,
    required DateTime? localLastSyncAt,
    required DateTime? cloudLastSyncAt,
  }) {
    if (localLastSyncAt == null) {
      if (localChanged && cloudLastSyncAt != null) return SyncDecision.conflict;
      if (localChanged) return SyncDecision.upload;
      if (cloudLastSyncAt != null) return SyncDecision.download;
      return SyncDecision.noAction;
    }
    return decideSync(
      localChanged: localChanged,
      localLastSyncAt: localLastSyncAt,
      cloudLastSyncAt: cloudLastSyncAt,
    );
  }
}
