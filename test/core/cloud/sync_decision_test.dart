import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/cloud/sync_decision.dart';

void main() {
  group('decideSync', () {
    final baseline = DateTime.utc(2026, 9, 7, 10);

    test('returns firstSync when no local sync baseline exists', () {
      final decision = decideSync(
        localChanged: false,
        localLastSyncAt: null,
        cloudLastSyncAt: null,
      );

      expect(decision, SyncDecision.firstSync);
    });

    test('returns noAction when neither side changed', () {
      final decision = decideSync(
        localChanged: false,
        localLastSyncAt: baseline,
        cloudLastSyncAt: baseline,
      );

      expect(decision, SyncDecision.noAction);
    });

    test('returns upload when only local data changed', () {
      final decision = decideSync(
        localChanged: true,
        localLastSyncAt: baseline,
        cloudLastSyncAt: baseline,
      );

      expect(decision, SyncDecision.upload);
    });

    test('returns download when only cloud data changed', () {
      final decision = decideSync(
        localChanged: false,
        localLastSyncAt: baseline,
        cloudLastSyncAt: baseline.add(const Duration(minutes: 5)),
      );

      expect(decision, SyncDecision.download);
    });

    test('returns conflict when both local and cloud data changed', () {
      final decision = decideSync(
        localChanged: true,
        localLastSyncAt: baseline,
        cloudLastSyncAt: baseline.add(const Duration(minutes: 10)),
      );

      expect(decision, SyncDecision.conflict);
    });
  });
}
