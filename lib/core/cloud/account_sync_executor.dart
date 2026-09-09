import '../storage/focusday_storage.dart';
import 'account_sync_gateway.dart';
import 'account_sync_models.dart';
import 'focusday_sync_executor.dart';
import 'sync_decision.dart';
import 'sync_cloud_gateway.dart';

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
    this.isSessionCurrent = _alwaysCurrent,
  });

  final AccountSyncGateway gateway;
  final FocusDayStorage storage;
  final SettingsApplier applySettings;
  final FocusApplier applyFocus;
  final SyncSessionGuard isSessionCurrent;

  static bool _alwaysCurrent(String _) => true;

  Future<SyncDecision> inspectSettings(String userId) async {
    final revision = storage.loadSettingsRevision();
    final cloud = await gateway.loadSettings(userId);
    return _decideVersionedDomain(
      localChanged: revision != storage.loadLastSyncedSettingsRevision(),
      localGeneration: storage.loadSettingsGeneration(),
      cloudGeneration: cloud?.generation ?? 0,
      localLastSyncAt: storage.loadSettingsLastSyncAt(),
      cloudLastSyncAt: cloud?.updatedAt,
    );
  }

  Future<SyncDecision> inspectFocus(String userId) async {
    final revision = storage.loadFocusRevision();
    final cloud = await gateway.loadFocus(userId);
    return _decideVersionedDomain(
      localChanged: revision != storage.loadLastSyncedFocusRevision(),
      localGeneration: storage.loadFocusGeneration(),
      cloudGeneration: cloud?.generation ?? 0,
      localLastSyncAt: storage.loadFocusLastSyncAt(),
      cloudLastSyncAt: cloud?.updatedAt,
    );
  }

  Future<SyncExecutionResult> resolveSettings(
    String userId,
    SyncResolutionChoice choice,
  ) async {
    if (!isSessionCurrent(userId)) return SyncExecutionResult.sessionChanged;
    final revision = storage.loadSettingsRevision();
    if (choice == SyncResolutionChoice.keepLocal) {
      final write = await gateway.saveSettings(
        userId,
        SyncedSettings(
          completionSoundEnabled: storage.loadCompletionSoundEnabled(),
          scheduledProjectAlertsEnabled: storage
              .loadScheduledProjectAlertsEnabled(),
          languagePreference: storage.loadLanguagePreference() ?? 'system',
        ),
        expectedGeneration: storage.loadSettingsGeneration(),
        force: true,
      );
      if (!isSessionCurrent(userId) ||
          storage.loadSettingsRevision() != revision) {
        return SyncExecutionResult.localChangedDuringSync;
      }
      if (write.updatedAt case final updatedAt?) {
        await storage.saveSettingsLastSyncAt(updatedAt);
      }
      await storage.saveLastSyncedSettingsRevision(revision);
      await storage.saveSettingsGeneration(write.generation);
      return SyncExecutionResult.uploaded;
    }
    final cloud = await gateway.loadSettings(userId);
    if (!isSessionCurrent(userId)) return SyncExecutionResult.sessionChanged;
    if (cloud == null) return SyncExecutionResult.noAction;
    final applied = await applySettings(cloud.value, revision);
    if (!applied || !isSessionCurrent(userId)) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud.updatedAt case final updatedAt?) {
      await storage.saveSettingsLastSyncAt(updatedAt);
    }
    await storage.saveLastSyncedSettingsRevision(revision);
    await storage.saveSettingsGeneration(cloud.generation);
    return SyncExecutionResult.downloaded;
  }

  Future<SyncExecutionResult> resolveFocus(
    String userId,
    SyncResolutionChoice choice,
  ) async {
    if (!isSessionCurrent(userId)) return SyncExecutionResult.sessionChanged;
    final revision = storage.loadFocusRevision();
    if (choice == SyncResolutionChoice.keepLocal) {
      final timer = storage.loadTimer();
      if (timer == null) return SyncExecutionResult.noAction;
      final write = await gateway.saveFocus(
        userId,
        CloudFocusState.fromLocal(timer),
        expectedGeneration: storage.loadFocusGeneration(),
        force: true,
      );
      if (!isSessionCurrent(userId) ||
          storage.loadFocusRevision() != revision) {
        return SyncExecutionResult.localChangedDuringSync;
      }
      if (write.updatedAt case final updatedAt?) {
        await storage.saveFocusLastSyncAt(updatedAt);
      }
      await storage.saveLastSyncedFocusRevision(revision);
      await storage.saveFocusGeneration(write.generation);
      return SyncExecutionResult.uploaded;
    }
    final cloud = await gateway.loadFocus(userId);
    if (!isSessionCurrent(userId)) return SyncExecutionResult.sessionChanged;
    if (cloud == null) return SyncExecutionResult.noAction;
    final applied = await applyFocus(cloud.value, revision);
    if (!applied || !isSessionCurrent(userId)) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud.updatedAt case final updatedAt?) {
      await storage.saveFocusLastSyncAt(updatedAt);
    }
    await storage.saveLastSyncedFocusRevision(revision);
    await storage.saveFocusGeneration(cloud.generation);
    return SyncExecutionResult.downloaded;
  }

  Future<SyncExecutionResult> executeSettings(String userId) async {
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    final revision = storage.loadSettingsRevision();
    final cloud = await gateway.loadSettings(userId);
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    final localChanged = revision != storage.loadLastSyncedSettingsRevision();
    final decision = _decideVersionedDomain(
      localChanged: localChanged,
      localGeneration: storage.loadSettingsGeneration(),
      cloudGeneration: cloud?.generation ?? 0,
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
      late final CloudWriteResult write;
      try {
        write = await gateway.saveSettings(
          userId,
          value,
          expectedGeneration:
              storage.loadSettingsGeneration() ?? cloud?.generation ?? 0,
        );
      } on CloudWriteConflict {
        return SyncExecutionResult.conflict;
      }
      if (!isSessionCurrent(userId)) {
        return SyncExecutionResult.sessionChanged;
      }
      if (write.updatedAt case final updatedAt?) {
        await storage.saveSettingsLastSyncAt(updatedAt);
      }
      await storage.saveLastSyncedSettingsRevision(revision);
      await storage.saveSettingsGeneration(write.generation);
      return storage.loadSettingsRevision() == revision
          ? SyncExecutionResult.uploaded
          : SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud == null) return SyncExecutionResult.noAction;
    if (storage.loadSettingsRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    final applied = await applySettings(cloud.value, revision);
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    if (!applied || storage.loadSettingsRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud.updatedAt case final updatedAt?) {
      await storage.saveSettingsLastSyncAt(updatedAt);
    }
    await storage.saveLastSyncedSettingsRevision(revision);
    await storage.saveSettingsGeneration(cloud.generation);
    return SyncExecutionResult.downloaded;
  }

  Future<SyncExecutionResult> executeFocus(String userId) async {
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    final revision = storage.loadFocusRevision();
    final cloud = await gateway.loadFocus(userId);
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    final localChanged = revision != storage.loadLastSyncedFocusRevision();
    final decision = _decideVersionedDomain(
      localChanged: localChanged,
      localGeneration: storage.loadFocusGeneration(),
      cloudGeneration: cloud?.generation ?? 0,
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
      late final CloudWriteResult write;
      try {
        write = await gateway.saveFocus(
          userId,
          CloudFocusState.fromLocal(timer),
          expectedGeneration:
              storage.loadFocusGeneration() ?? cloud?.generation ?? 0,
        );
      } on CloudWriteConflict {
        return SyncExecutionResult.conflict;
      }
      if (!isSessionCurrent(userId)) {
        return SyncExecutionResult.sessionChanged;
      }
      if (write.updatedAt case final updatedAt?) {
        await storage.saveFocusLastSyncAt(updatedAt);
      }
      await storage.saveLastSyncedFocusRevision(revision);
      await storage.saveFocusGeneration(write.generation);
      return storage.loadFocusRevision() == revision
          ? SyncExecutionResult.uploaded
          : SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud == null) return SyncExecutionResult.noAction;
    if (storage.loadFocusRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    final applied = await applyFocus(cloud.value, revision);
    if (!isSessionCurrent(userId)) {
      return SyncExecutionResult.sessionChanged;
    }
    if (!applied || storage.loadFocusRevision() != revision) {
      return SyncExecutionResult.localChangedDuringSync;
    }
    if (cloud.updatedAt case final updatedAt?) {
      await storage.saveFocusLastSyncAt(updatedAt);
    }
    await storage.saveLastSyncedFocusRevision(revision);
    await storage.saveFocusGeneration(cloud.generation);
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

  SyncDecision _decideVersionedDomain({
    required bool localChanged,
    required int? localGeneration,
    required int cloudGeneration,
    required DateTime? localLastSyncAt,
    required DateTime? cloudLastSyncAt,
  }) {
    if (localGeneration == null) {
      return _decideDomain(
        localChanged: localChanged,
        localLastSyncAt: localLastSyncAt,
        cloudLastSyncAt: cloudLastSyncAt,
      );
    }
    final cloudChanged = cloudGeneration != localGeneration;
    if (localChanged && cloudChanged) return SyncDecision.conflict;
    if (localChanged) return SyncDecision.upload;
    if (cloudChanged) return SyncDecision.download;
    return SyncDecision.noAction;
  }
}
