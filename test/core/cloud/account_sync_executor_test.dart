import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/cloud/account_sync_executor.dart';
import 'package:focusday/core/cloud/account_sync_gateway.dart';
import 'package:focusday/core/cloud/account_sync_models.dart';
import 'package:focusday/core/cloud/focusday_sync_executor.dart';
import 'package:focusday/core/cloud/sync_cloud_gateway.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGateway implements AccountSyncGateway {
  CloudValue<SyncedSettings>? settings;
  CloudValue<CloudFocusState>? focus;
  int settingsWrites = 0;
  int focusWrites = 0;
  Future<void> Function()? onSaveSettings;
  Future<void> Function()? onSaveFocus;
  Future<void> Function()? onBeforeSaveSettings;
  Future<void> Function()? onBeforeSaveFocus;
  bool throwOnSettingsSave = false;
  bool returnNullSettingsUpdatedAt = false;
  bool returnNullFocusUpdatedAt = false;
  int settingsGeneration = 0;
  int focusGeneration = 0;
  final updatedAt = DateTime.utc(2026, 9, 8, 12);

  @override
  Future<CloudValue<SyncedSettings>?> loadSettings(String userId) async =>
      settings;
  @override
  Future<CloudValue<CloudFocusState>?> loadFocus(String userId) async => focus;
  @override
  Future<CloudWriteResult> saveSettings(
    String userId,
    SyncedSettings value, {
    required int? expectedGeneration,
    bool force = false,
  }) async {
    settingsWrites++;
    if (throwOnSettingsSave) throw StateError('offline');
    await onBeforeSaveSettings?.call();
    if (!force && expectedGeneration != settingsGeneration) {
      throw const CloudWriteConflict();
    }
    await onSaveSettings?.call();
    settingsGeneration++;
    settings = CloudValue(value, updatedAt, generation: settingsGeneration);
    return CloudWriteResult(
      generation: settingsGeneration,
      updatedAt: returnNullSettingsUpdatedAt ? null : updatedAt,
    );
  }

  @override
  Future<CloudWriteResult> saveFocus(
    String userId,
    CloudFocusState value, {
    required int? expectedGeneration,
    bool force = false,
  }) async {
    focusWrites++;
    await onBeforeSaveFocus?.call();
    if (!force && expectedGeneration != focusGeneration) {
      throw const CloudWriteConflict();
    }
    await onSaveFocus?.call();
    focusGeneration++;
    focus = CloudValue(value, updatedAt, generation: focusGeneration);
    return CloudWriteResult(
      generation: focusGeneration,
      updatedAt: returnNullFocusUpdatedAt ? null : updatedAt,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FocusDayStorage storage;
  late FakeGateway gateway;
  late AccountSyncExecutor executor;
  late SyncedSettings? appliedSettings;
  late CloudFocusState? appliedFocus;
  late bool sessionCurrent;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = FocusDayStorage(await SharedPreferences.getInstance());
    gateway = FakeGateway();
    appliedSettings = null;
    appliedFocus = null;
    sessionCurrent = true;
    executor = AccountSyncExecutor(
      gateway: gateway,
      storage: storage,
      isSessionCurrent: (_) => sessionCurrent,
      applySettings: (value, revision) async {
        appliedSettings = value;
        return true;
      },
      applyFocus: (value, revision) async {
        appliedFocus = value;
        return true;
      },
    );
  });

  test('local synchronized preference change uploads once', () async {
    await storage.saveCompletionSoundEnabled(false);
    await storage.incrementSettingsRevision();
    expect(await executor.executeSettings('u'), SyncExecutionResult.uploaded);
    expect(gateway.settingsWrites, 1);
    expect(gateway.settings!.value.completionSoundEnabled, isFalse);
  });

  test(
    'AI provider stays local and does not trigger settings upload',
    () async {
      final before = await executor.executeSettings('u');
      await storage.saveAiProviderMode('personalOpenAi');
      final result = await executor.executeSettings('u');
      expect(result, before);
      expect(gateway.settingsWrites, 0);
      expect(storage.loadSettingsRevision(), 0);
      expect(storage.loadAiProviderMode(), 'personalOpenAi');
    },
  );

  test('cloud preference downloads when local domain is untouched', () async {
    gateway.settings = CloudValue(
      const SyncedSettings(
        completionSoundEnabled: false,
        scheduledProjectAlertsEnabled: false,
        languagePreference: 'fr',
      ),
      gateway.updatedAt,
    );
    expect(await executor.executeSettings('u'), SyncExecutionResult.downloaded);
    expect(appliedSettings?.languagePreference, 'fr');
    expect(gateway.settingsWrites, 0);
  });

  test('first settings conflict is conservative', () async {
    await storage.incrementSettingsRevision();
    gateway.settings = CloudValue(
      const SyncedSettings(
        completionSoundEnabled: true,
        scheduledProjectAlertsEnabled: true,
        languagePreference: 'en',
      ),
      gateway.updatedAt,
    );
    expect(await executor.executeSettings('u'), SyncExecutionResult.conflict);
    expect(appliedSettings, isNull);
    expect(gateway.settingsWrites, 0);
  });

  test('focus transition uploads deterministic running state', () async {
    await storage.saveTimer(
      FocusTimerState(
        projectId: 'bogoka',
        initialSeconds: 3600,
        remainingSeconds: 3600,
        status: FocusTimerStatus.running,
        endTime: gateway.updatedAt.add(const Duration(hours: 1)),
      ),
    );
    await storage.incrementFocusRevision();
    expect(await executor.executeFocus('u'), SyncExecutionResult.uploaded);
    expect(gateway.focusWrites, 1);
    expect(gateway.focus!.value.remainingSecondsWhenPaused, isNull);
    expect(gateway.focus!.value.endsAt, isNotNull);
  });

  test('focus cloud state downloads without an extra write', () async {
    gateway.focus = CloudValue(
      CloudFocusState(
        projectId: 'dotnet',
        status: FocusTimerStatus.paused,
        initialSeconds: 1800,
        remainingSecondsWhenPaused: 900,
      ),
      gateway.updatedAt,
    );
    expect(await executor.executeFocus('u'), SyncExecutionResult.downloaded);
    expect(appliedFocus?.projectId, 'dotnet');
    expect(gateway.focusWrites, 0);
  });

  test('settings change during upload remains unsynchronized', () async {
    await storage.incrementSettingsRevision();
    gateway.onSaveSettings = () async {
      await storage.incrementSettingsRevision();
    };
    expect(
      await executor.executeSettings('u'),
      SyncExecutionResult.localChangedDuringSync,
    );
    expect(
      storage.loadSettingsRevision(),
      isNot(storage.loadLastSyncedSettingsRevision()),
    );
  });

  test('focus change during upload remains unsynchronized', () async {
    await storage.saveTimer(
      const FocusTimerState(
        projectId: 'bogoka',
        initialSeconds: 3600,
        remainingSeconds: 1200,
        status: FocusTimerStatus.paused,
      ),
    );
    await storage.incrementFocusRevision();
    gateway.onSaveFocus = () async {
      await storage.incrementFocusRevision();
    };
    expect(
      await executor.executeFocus('u'),
      SyncExecutionResult.localChangedDuringSync,
    );
    expect(
      storage.loadFocusRevision(),
      isNot(storage.loadLastSyncedFocusRevision()),
    );
  });

  test(
    'network failure never advances settings synchronized revision',
    () async {
      await storage.incrementSettingsRevision();
      gateway.throwOnSettingsSave = true;
      await expectLater(executor.executeSettings('u'), throwsStateError);
      expect(storage.loadLastSyncedSettingsRevision(), 0);
      expect(storage.loadSettingsLastSyncAt(), isNull);
    },
  );

  test('logout during settings upload never advances its baseline', () async {
    await storage.incrementSettingsRevision();
    gateway.onSaveSettings = () async => sessionCurrent = false;

    expect(
      await executor.executeSettings('u'),
      SyncExecutionResult.sessionChanged,
    );
    expect(storage.loadLastSyncedSettingsRevision(), 0);
    expect(storage.loadSettingsLastSyncAt(), isNull);
  });

  test('settings conflict supports local and cloud resolution', () async {
    await storage.saveSettingsLastSyncAt(DateTime.utc(2026, 9, 8, 10));
    await storage.incrementSettingsRevision();
    gateway.settings = CloudValue(
      const SyncedSettings(
        completionSoundEnabled: false,
        scheduledProjectAlertsEnabled: false,
        languagePreference: 'fr',
      ),
      gateway.updatedAt,
    );
    expect(await executor.executeSettings('u'), SyncExecutionResult.conflict);

    expect(
      await executor.resolveSettings('u', SyncResolutionChoice.keepLocal),
      SyncExecutionResult.uploaded,
    );
    expect(storage.loadLastSyncedSettingsRevision(), 1);
    expect(storage.loadSettingsGeneration(), 1);

    await storage.incrementSettingsRevision();
    gateway.settingsGeneration = 2;
    gateway.settings = CloudValue(
      const SyncedSettings(
        completionSoundEnabled: false,
        scheduledProjectAlertsEnabled: false,
        languagePreference: 'fr',
      ),
      gateway.updatedAt.add(const Duration(minutes: 1)),
      generation: 2,
    );
    expect(
      await executor.resolveSettings('u', SyncResolutionChoice.useCloud),
      SyncExecutionResult.downloaded,
    );
    expect(appliedSettings?.languagePreference, 'fr');
    expect(storage.loadLastSyncedSettingsRevision(), 2);
    expect(storage.loadSettingsGeneration(), gateway.settings!.generation);
  });

  test('focus conflict supports local and cloud resolution', () async {
    await storage.saveFocusLastSyncAt(DateTime.utc(2026, 9, 8, 10));
    await storage.saveTimer(
      const FocusTimerState(
        projectId: 'local',
        initialSeconds: 1200,
        remainingSeconds: 600,
        status: FocusTimerStatus.paused,
      ),
    );
    await storage.incrementFocusRevision();
    gateway.focus = CloudValue(
      const CloudFocusState(
        projectId: 'cloud',
        status: FocusTimerStatus.paused,
        initialSeconds: 1800,
        remainingSecondsWhenPaused: 900,
      ),
      gateway.updatedAt,
    );
    expect(await executor.executeFocus('u'), SyncExecutionResult.conflict);
    expect(
      await executor.resolveFocus('u', SyncResolutionChoice.keepLocal),
      SyncExecutionResult.uploaded,
    );
    expect(gateway.focus!.value.projectId, 'local');
    expect(storage.loadFocusGeneration(), 1);

    await storage.incrementFocusRevision();
    gateway.focusGeneration = 2;
    gateway.focus = CloudValue(
      const CloudFocusState(
        projectId: 'cloud',
        status: FocusTimerStatus.running,
        initialSeconds: 1800,
        endsAt: null,
      ),
      gateway.updatedAt.add(const Duration(minutes: 1)),
      generation: 2,
    );
    expect(
      await executor.resolveFocus('u', SyncResolutionChoice.useCloud),
      SyncExecutionResult.downloaded,
    );
    expect(appliedFocus?.projectId, 'cloud');
    expect(storage.loadLastSyncedFocusRevision(), 2);
    expect(storage.loadFocusGeneration(), gateway.focus!.generation);
  });

  test('settings first-sync choices establish coherent baselines', () async {
    await storage.incrementSettingsRevision();
    expect(
      await executor.resolveSettings('u', SyncResolutionChoice.keepLocal),
      SyncExecutionResult.uploaded,
    );
    expect(storage.loadLastSyncedSettingsRevision(), 1);
    expect(storage.loadSettingsLastSyncAt(), gateway.updatedAt);

    gateway.settings = CloudValue(
      const SyncedSettings(
        completionSoundEnabled: false,
        scheduledProjectAlertsEnabled: true,
        languagePreference: 'en',
      ),
      gateway.updatedAt.add(const Duration(minutes: 1)),
    );
    expect(
      await executor.resolveSettings('u', SyncResolutionChoice.useCloud),
      SyncExecutionResult.downloaded,
    );
    expect(storage.loadSettingsLastSyncAt(), gateway.settings!.updatedAt);
  });

  test('focus first-sync choices establish coherent baselines', () async {
    await storage.saveTimer(
      const FocusTimerState(
        projectId: 'local',
        initialSeconds: 600,
        remainingSeconds: 300,
        status: FocusTimerStatus.paused,
      ),
    );
    await storage.incrementFocusRevision();
    expect(
      await executor.resolveFocus('u', SyncResolutionChoice.keepLocal),
      SyncExecutionResult.uploaded,
    );
    expect(storage.loadLastSyncedFocusRevision(), 1);
    expect(storage.loadFocusLastSyncAt(), gateway.updatedAt);

    gateway.focus = CloudValue(
      const CloudFocusState(
        projectId: 'cloud',
        status: FocusTimerStatus.paused,
        initialSeconds: 900,
        remainingSecondsWhenPaused: 450,
      ),
      gateway.updatedAt.add(const Duration(minutes: 1)),
    );
    expect(
      await executor.resolveFocus('u', SyncResolutionChoice.useCloud),
      SyncExecutionResult.downloaded,
    );
    expect(storage.loadFocusLastSyncAt(), gateway.focus!.updatedAt);
  });

  test('stale settings upload is rejected without overwriting cloud', () async {
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await storage.saveSettingsLastSyncAt(baseline);
    await storage.saveSettingsGeneration(0);
    await storage.saveCompletionSoundEnabled(false);
    await storage.incrementSettingsRevision();
    gateway.settings = CloudValue(
      const SyncedSettings(
        completionSoundEnabled: true,
        scheduledProjectAlertsEnabled: true,
        languagePreference: 'system',
      ),
      baseline,
      generation: 0,
    );
    var injected = false;
    gateway.onBeforeSaveSettings = () async {
      if (injected) return;
      injected = true;
      gateway.settingsGeneration = 1;
      gateway.settings = CloudValue(
        const SyncedSettings(
          completionSoundEnabled: true,
          scheduledProjectAlertsEnabled: false,
          languagePreference: 'fr',
        ),
        gateway.updatedAt,
        generation: 1,
      );
    };

    expect(await executor.executeSettings('u'), SyncExecutionResult.conflict);
    expect(gateway.settings!.value.languagePreference, 'fr');
    expect(storage.loadSettingsGeneration(), 0);
    expect(storage.loadLastSyncedSettingsRevision(), 0);
  });

  test('stale focus upload is rejected without overwriting cloud', () async {
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await storage.saveFocusLastSyncAt(baseline);
    await storage.saveFocusGeneration(0);
    await storage.saveTimer(
      const FocusTimerState(
        projectId: 'local',
        initialSeconds: 600,
        remainingSeconds: 300,
        status: FocusTimerStatus.paused,
      ),
    );
    await storage.incrementFocusRevision();
    gateway.focus = CloudValue(
      const CloudFocusState(
        projectId: 'baseline',
        status: FocusTimerStatus.paused,
        initialSeconds: 600,
        remainingSecondsWhenPaused: 300,
      ),
      baseline,
      generation: 0,
    );
    var injected = false;
    gateway.onBeforeSaveFocus = () async {
      if (injected) return;
      injected = true;
      gateway.focusGeneration = 1;
      gateway.focus = CloudValue(
        const CloudFocusState(
          projectId: 'concurrent',
          status: FocusTimerStatus.paused,
          initialSeconds: 900,
          remainingSecondsWhenPaused: 450,
        ),
        gateway.updatedAt,
        generation: 1,
      );
    };

    expect(await executor.executeFocus('u'), SyncExecutionResult.conflict);
    expect(gateway.focus!.value.projectId, 'concurrent');
    expect(storage.loadFocusGeneration(), 0);
    expect(storage.loadLastSyncedFocusRevision(), 0);
  });

  test(
    'settings generation succeeds with unresolved server timestamp',
    () async {
      gateway.returnNullSettingsUpdatedAt = true;
      await storage.incrementSettingsRevision();

      expect(await executor.executeSettings('u'), SyncExecutionResult.uploaded);
      expect(storage.loadSettingsGeneration(), 1);
      expect(storage.loadLastSyncedSettingsRevision(), 1);
      expect(storage.loadSettingsLastSyncAt(), isNull);
    },
  );

  test('focus generation succeeds with unresolved server timestamp', () async {
    gateway.returnNullFocusUpdatedAt = true;
    await storage.saveTimer(
      const FocusTimerState(
        projectId: 'local',
        initialSeconds: 600,
        remainingSeconds: 300,
        status: FocusTimerStatus.paused,
      ),
    );
    await storage.incrementFocusRevision();

    expect(await executor.executeFocus('u'), SyncExecutionResult.uploaded);
    expect(storage.loadFocusGeneration(), 1);
    expect(storage.loadLastSyncedFocusRevision(), 1);
    expect(storage.loadFocusLastSyncAt(), isNull);
  });
}
