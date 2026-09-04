import 'package:flutter_test/flutter_test.dart';
import 'package:focusday/features/today/application/project_schedule_state.dart';

void main() {
  group('ProjectScheduleState', () {
    final now = DateTime(2026, 9, 3, 22, 0);

    test('retourne normal sans programmation', () {
      final state = ProjectScheduleState(now: now);

      expect(state.phaseFor(null), ProjectSchedulePhase.normal);
    });

    test('retourne normal à plus de 10 minutes', () {
      final state = ProjectScheduleState(now: now);

      expect(
        state.phaseFor(now.add(const Duration(minutes: 11))),
        ProjectSchedulePhase.normal,
      );
    });

    test('retourne soon à 10 minutes ou moins', () {
      final state = ProjectScheduleState(now: now);

      expect(
        state.phaseFor(now.add(const Duration(minutes: 10))),
        ProjectSchedulePhase.soon,
      );
    });

    test('retourne due à l’heure prévue', () {
      final state = ProjectScheduleState(now: now);

      expect(state.phaseFor(now), ProjectSchedulePhase.due);
    });

    test('retourne due lorsque l’heure est dépassée', () {
      final state = ProjectScheduleState(now: now);

      expect(
        state.phaseFor(now.subtract(const Duration(minutes: 5))),
        ProjectSchedulePhase.due,
      );
    });
  });
}
