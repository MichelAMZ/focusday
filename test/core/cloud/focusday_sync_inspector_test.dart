import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusday/core/cloud/focusday_sync_inspector.dart';
import 'package:focusday/core/cloud/sync_decision.dart';
import 'package:focusday/core/cloud/sync_metadata_reader.dart';
import 'package:focusday/core/storage/focusday_storage.dart';

class FakeSyncMetadataReader implements SyncMetadataReader {
  FakeSyncMetadataReader(this.lastSyncAt);

  final DateTime? lastSyncAt;

  @override
  Future<DateTime?> loadLastSyncAt(String userId) async {
    return lastSyncAt;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns firstSync when no local baseline exists', () async {
    final preferences = await SharedPreferences.getInstance();
    final localStorage = FocusDayStorage(preferences);

    final inspector = FocusDaySyncInspector(
      cloudStorage: FakeSyncMetadataReader(null),
      localStorage: localStorage,
    );

    final decision = await inspector.inspect('user-1');

    expect(decision, SyncDecision.firstSync);
  });

  test('returns upload when only local projects changed', () async {
    final preferences = await SharedPreferences.getInstance();
    final localStorage = FocusDayStorage(preferences);

    final baseline = DateTime.utc(2026, 9, 7, 10);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(true);

    final inspector = FocusDaySyncInspector(
      cloudStorage: FakeSyncMetadataReader(baseline),
      localStorage: localStorage,
    );

    final decision = await inspector.inspect('user-1');

    expect(decision, SyncDecision.upload);
  });

  test('returns download when only cloud changed', () async {
    final preferences = await SharedPreferences.getInstance();
    final localStorage = FocusDayStorage(preferences);

    final baseline = DateTime.utc(2026, 9, 7, 10);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(false);

    final inspector = FocusDaySyncInspector(
      cloudStorage: FakeSyncMetadataReader(
        baseline.add(const Duration(minutes: 5)),
      ),
      localStorage: localStorage,
    );

    final decision = await inspector.inspect('user-1');

    expect(decision, SyncDecision.download);
  });

  test('returns conflict when local and cloud both changed', () async {
    final preferences = await SharedPreferences.getInstance();
    final localStorage = FocusDayStorage(preferences);

    final baseline = DateTime.utc(2026, 9, 7, 10);
    await localStorage.saveLastSyncAt(baseline);
    await localStorage.saveProjectsDirty(true);

    final inspector = FocusDaySyncInspector(
      cloudStorage: FakeSyncMetadataReader(
        baseline.add(const Duration(minutes: 10)),
      ),
      localStorage: localStorage,
    );

    final decision = await inspector.inspect('user-1');

    expect(decision, SyncDecision.conflict);
  });

  test('matching local and synchronized revisions are locally clean', () async {
    final preferences = await SharedPreferences.getInstance();
    final storage = FocusDayStorage(preferences);
    final baseline = DateTime.utc(2026, 9, 8, 10);
    await storage.saveLastSyncAt(baseline);
    await storage.incrementProjectsRevision();
    await storage.saveLastSyncedProjectsRevision(1);
    await storage.saveProjectsDirty(false);

    final decision = await FocusDaySyncInspector(
      cloudStorage: FakeSyncMetadataReader(baseline),
      localStorage: storage,
    ).inspect('user-1');
    expect(decision, SyncDecision.noAction);
  });

  test(
    'newer local revision requires upload even when legacy dirty is false',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = FocusDayStorage(preferences);
      final baseline = DateTime.utc(2026, 9, 8, 10);
      await storage.saveLastSyncAt(baseline);
      await storage.incrementProjectsRevision();
      await storage.saveProjectsDirty(false);

      final decision = await FocusDaySyncInspector(
        cloudStorage: FakeSyncMetadataReader(baseline),
        localStorage: storage,
      ).inspect('user-1');
      expect(decision, SyncDecision.upload);
    },
  );

  test(
    'legacy dirty remains conservative when synchronized revision is absent',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = FocusDayStorage(preferences);
      final baseline = DateTime.utc(2026, 9, 8, 10);
      await storage.saveLastSyncAt(baseline);
      await storage.saveProjectsDirty(true);

      final decision = await FocusDaySyncInspector(
        cloudStorage: FakeSyncMetadataReader(baseline),
        localStorage: storage,
      ).inspect('user-1');
      expect(decision, SyncDecision.upload);
    },
  );
}
