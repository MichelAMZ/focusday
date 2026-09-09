import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusday/core/cloud/sync_mutation_bus.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/core/storage/storage_provider.dart';
import 'package:focusday/features/ai/application/ai_action_executor.dart';
import 'package:focusday/features/ai/application/ai_proposed_action_validator.dart';
import 'package:focusday/features/ai/domain/ai_assistant_models.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/focus_timer_controller.dart';
import 'package:focusday/features/today/application/focus_timer_state.dart';
import 'package:focusday/features/today/application/today_controller.dart';

void main() {
  const project = FocusProject(
    id: 'active',
    name: 'Active',
    durationMinutes: 25,
    status: FocusProjectStatus.active,
    notes: 'Old',
    tasks: [
      FocusTask(id: 'a', title: 'A'),
      FocusTask(id: 'b', title: 'B'),
      FocusTask(id: 'done', title: 'Done', isCompleted: true),
    ],
  );
  const other = FocusProject(
    id: 'other',
    name: 'Other',
    durationMinutes: 15,
    tasks: [FocusTask(id: 'x', title: 'X')],
  );
  const idle = FocusTimerState(
    projectId: 'active',
    initialSeconds: 1500,
    remainingSeconds: 1500,
  );
  const running = FocusTimerState(
    projectId: 'active',
    initialSeconds: 1500,
    remainingSeconds: 1200,
    status: FocusTimerStatus.running,
  );
  const validator = AiProposedActionValidator();

  AiProposedAction action(
    AiProposedActionType type, {
    String? title,
    String? description,
    String? taskId,
    String? newTitle,
    String? newNotes,
    int? durationMinutes,
  }) => AiProposedAction(
    type: type,
    title: title,
    description: description,
    taskId: taskId,
    newTitle: newTitle,
    newNotes: newNotes,
    durationMinutes: durationMinutes,
  );

  group('validator', () {
    test('parsing rejects unknown, malformed and unexpected fields', () {
      for (final json in <Map<String, Object?>>[
        {'type': 'unknown'},
        {'type': 'addTask', 'title': 42},
        {'type': 'completeTask', 'taskId': 'a', 'title': 'extra'},
      ]) {
        expect(
          () => AiProposedAction.fromJson(json),
          throwsA(isA<AiAssistantException>()),
        );
      }
    });

    test('add and rename validation', () {
      expect(
        validator.validate(
          action(
            AiProposedActionType.addTask,
            title: ' New ',
            description: 'Details',
          ),
          project,
          idle,
        ),
        isTrue,
      );
      expect(
        validator.validate(
          action(AiProposedActionType.addTask, title: '   '),
          project,
          idle,
        ),
        isFalse,
      );
      expect(
        validator.validate(
          action(
            AiProposedActionType.addTask,
            title: 'New',
            description: 'x' * 501,
          ),
          project,
          idle,
        ),
        isFalse,
      );
      expect(
        validator.validate(
          action(
            AiProposedActionType.renameTask,
            taskId: 'a',
            newTitle: 'Renamed',
          ),
          project,
          idle,
        ),
        isTrue,
      );
      expect(
        validator.validate(
          action(
            AiProposedActionType.renameTask,
            taskId: 'missing',
            newTitle: 'Renamed',
          ),
          project,
          idle,
        ),
        isFalse,
      );
    });

    test('complete and reopen require the expected current state', () {
      expect(
        validator.validate(
          action(AiProposedActionType.completeTask, taskId: 'a'),
          project,
          idle,
        ),
        isTrue,
      );
      expect(
        validator.validate(
          action(AiProposedActionType.completeTask, taskId: 'done'),
          project,
          idle,
        ),
        isFalse,
      );
      expect(
        validator.validate(
          action(AiProposedActionType.reopenTask, taskId: 'done'),
          project,
          idle,
        ),
        isTrue,
      );
      expect(
        validator.validate(
          action(AiProposedActionType.reopenTask, taskId: 'a'),
          project,
          idle,
        ),
        isFalse,
      );
    });

    test('notes and duration boundaries', () {
      expect(
        validator.validate(
          action(AiProposedActionType.updateProjectNotes, newNotes: ''),
          project,
          idle,
        ),
        isTrue,
      );
      expect(
        validator.validate(
          action(AiProposedActionType.updateProjectNotes, newNotes: 'x' * 5001),
          project,
          idle,
        ),
        isFalse,
      );
      for (final value in [1, 480]) {
        expect(
          validator.validate(
            action(
              AiProposedActionType.setFocusDuration,
              durationMinutes: value,
            ),
            project,
            idle,
          ),
          isTrue,
        );
      }
      for (final value in [0, 481]) {
        expect(
          validator.validate(
            action(
              AiProposedActionType.setFocusDuration,
              durationMinutes: value,
            ),
            project,
            idle,
          ),
          isFalse,
        );
      }
      expect(
        validator.validate(
          action(AiProposedActionType.setFocusDuration, durationMinutes: 30),
          project,
          running,
        ),
        isFalse,
      );
    });

    test('contradictory batches are rejected', () {
      final batches = [
        [
          action(AiProposedActionType.completeTask, taskId: 'a'),
          action(AiProposedActionType.reopenTask, taskId: 'a'),
        ],
        [
          action(AiProposedActionType.renameTask, taskId: 'a', newTitle: 'One'),
          action(AiProposedActionType.renameTask, taskId: 'a', newTitle: 'Two'),
        ],
        [
          action(AiProposedActionType.setFocusDuration, durationMinutes: 20),
          action(AiProposedActionType.setFocusDuration, durationMinutes: 30),
        ],
      ];
      for (final batch in batches) {
        expect(validator.validateAll(batch, project, idle), isFalse);
      }
    });
  });

  ProviderContainer createContainer({FocusDayStorage? storage}) {
    final container = ProviderContainer(
      overrides: [
        if (storage != null) focusDayStorageProvider.overrideWithValue(storage),
      ],
    );
    container.read(todayProjectsProvider.notifier).replaceAllProjects([
      project,
      other,
    ]);
    container
        .read(focusTimerProvider.notifier)
        .reset(projectId: project.id, durationMinutes: 25);
    return container;
  }

  AiActionExecutor executor(ProviderContainer container) => AiActionExecutor(
    projects: container.read(todayProjectsProvider.notifier),
    timer: container.read(focusTimerProvider.notifier),
  );

  FocusProject active(ProviderContainer container) => container
      .read(todayProjectsProvider)
      .firstWhere((item) => item.id == project.id);

  group('executor', () {
    test('executes add, rename and notes through existing APIs', () {
      final container = createContainer();
      addTearDown(container.dispose);
      expect(
        executor(container).executeConfirmed([
          action(
            AiProposedActionType.addTask,
            title: ' Added ',
            description: ' Description ',
          ),
          action(
            AiProposedActionType.renameTask,
            taskId: 'a',
            newTitle: 'Renamed',
          ),
          action(
            AiProposedActionType.updateProjectNotes,
            newNotes: 'New notes',
          ),
        ]),
        isTrue,
      );
      final updated = active(container);
      expect(
        updated.tasks.firstWhere((task) => task.id == 'a').title,
        'Renamed',
      );
      final added = updated.tasks.firstWhere((task) => task.title == 'Added');
      expect(added.description, 'Description');
      expect(updated.notes, 'New notes');
      expect(
        container.read(todayProjectsProvider).last.toJson(),
        other.toJson(),
      );
    });

    test('complete and reopen preserve controller task ordering', () {
      final container = createContainer();
      addTearDown(container.dispose);
      final execute = executor(container);
      expect(
        execute.executeConfirmed([
          action(AiProposedActionType.completeTask, taskId: 'a'),
        ]),
        isTrue,
      );
      expect(active(container).tasks.map((task) => task.id), [
        'b',
        'done',
        'a',
      ]);
      expect(
        execute.executeConfirmed([
          action(AiProposedActionType.reopenTask, taskId: 'done'),
        ]),
        isTrue,
      );
      expect(active(container).tasks.map((task) => task.id), [
        'b',
        'done',
        'a',
      ]);
      expect(active(container).tasks[1].isCompleted, isFalse);
    });

    test('invalid or contradictory batch performs zero mutation', () {
      final container = createContainer();
      addTearDown(container.dispose);
      final before = container.read(todayProjectsProvider);
      expect(
        executor(container).executeConfirmed([
          action(AiProposedActionType.addTask, title: 'Would add'),
          action(
            AiProposedActionType.renameTask,
            taskId: 'missing',
            newTitle: 'Invalid',
          ),
        ]),
        isFalse,
      );
      expect(container.read(todayProjectsProvider), same(before));
      expect(
        executor(container).executeConfirmed([
          action(AiProposedActionType.completeTask, taskId: 'a'),
          action(AiProposedActionType.reopenTask, taskId: 'a'),
        ]),
        isFalse,
      );
      expect(container.read(todayProjectsProvider), same(before));
    });

    test('stale proposal is revalidated before every batch mutation', () {
      final container = createContainer();
      addTearDown(container.dispose);
      final execute = executor(container);
      container.read(todayProjectsProvider.notifier).toggleTask('active', 'a');
      final before = container.read(todayProjectsProvider);
      expect(
        execute.executeConfirmed([
          action(AiProposedActionType.completeTask, taskId: 'a'),
          action(AiProposedActionType.addTask, title: 'Never added'),
        ]),
        isFalse,
      );
      expect(container.read(todayProjectsProvider), same(before));
      expect(active(container).tasks.last.isCompleted, isTrue);
    });

    test('focus duration reset never starts the timer', () {
      final container = createContainer();
      addTearDown(container.dispose);
      expect(
        executor(container).executeConfirmed([
          action(AiProposedActionType.setFocusDuration, durationMinutes: 45),
        ]),
        isTrue,
      );
      final timer = container.read(focusTimerProvider);
      expect(active(container).durationMinutes, 45);
      expect(timer.initialSeconds, 2700);
      expect(timer.remainingSeconds, 2700);
      expect(timer.status, FocusTimerStatus.idle);
      expect(timer.endTime, isNull);
    });

    test(
      'normal persistence and synchronization pipeline is preserved',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = FocusDayStorage(await SharedPreferences.getInstance());
        final container = createContainer(storage: storage);
        addTearDown(container.dispose);
        final notification = container
            .read(syncMutationBusProvider)
            .changes
            .firstWhere((domain) => domain == SyncDomain.projects);
        expect(
          executor(container).executeConfirmed([
            action(AiProposedActionType.addTask, title: 'Persisted'),
          ]),
          isTrue,
        );
        expect(await notification, SyncDomain.projects);
        expect(storage.loadProjectsDirty(), isTrue);
        expect(storage.loadProjectsRevision(), 1);
        expect(
          storage.loadProjects()!.first.tasks.any(
            (task) => task.title == 'Persisted',
          ),
          isTrue,
        );
      },
    );
  });
}
