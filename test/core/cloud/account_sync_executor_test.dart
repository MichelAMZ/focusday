import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/cloud/account_sync_executor.dart';
import 'package:focusday/core/cloud/account_sync_gateway.dart';
import 'package:focusday/core/cloud/account_sync_models.dart';
import 'package:focusday/core/cloud/focusday_sync_executor.dart';
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
  bool throwOnSettingsSave = false;
  final updatedAt = DateTime.utc(2026, 9, 8, 12);

  @override
  Future<CloudValue<SyncedSettings>?> loadSettings(String userId) async =>
      settings;
  @override
  Future<CloudValue<CloudFocusState>?> loadFocus(String userId) async => focus;
  @override
  Future<DateTime> saveSettings(String userId, SyncedSettings value) async {
    settingsWrites++;
    if (throwOnSettingsSave) throw StateError('offline');
    await onSaveSettings?.call();
    settings = CloudValue(value, updatedAt);
    return updatedAt;
  }

  @override
  Future<DateTime> saveFocus(String userId, CloudFocusState value) async {
    focusWrites++;
    await onSaveFocus?.call();
    focus = CloudValue(value, updatedAt);
    return updatedAt;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FocusDayStorage storage;
  late FakeGateway gateway;
  late AccountSyncExecutor executor;
  late SyncedSettings? appliedSettings;
  late CloudFocusState? appliedFocus;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = FocusDayStorage(await SharedPreferences.getInstance());
    gateway = FakeGateway();
    appliedSettings = null;
    appliedFocus = null;
    executor = AccountSyncExecutor(
      gateway: gateway,
      storage: storage,
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
}
