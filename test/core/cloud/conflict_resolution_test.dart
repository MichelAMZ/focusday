import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/core/cloud/conflict_resolution.dart';
import 'package:focusday/core/cloud/focusday_sync_executor.dart';

void main() {
  test('cancel is non-destructive and invokes no resolution', () async {
    var calls = 0;

    final result = await applySyncResolutionChoice(null, (choice) async {
      calls++;
      return SyncExecutionResult.uploaded;
    });

    expect(result, isNull);
    expect(calls, 0);
  });
}
