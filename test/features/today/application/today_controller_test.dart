import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusday/core/cloud/sync_mutation_bus.dart';
import 'package:focusday/core/storage/focusday_storage.dart';
import 'package:focusday/core/storage/storage_provider.dart';
import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/projects/domain/focus_task.dart';
import 'package:focusday/features/today/application/today_controller.dart';

void main() {
  FocusProject orderedTaskProject() => const FocusProject(
    id: 'ordered',
    name: 'Ordered',
    durationMinutes: 30,
    status: FocusProjectStatus.active,
    tasks: [
      FocusTask(id: 'a', title: 'A'),
      FocusTask(id: 'b', title: 'B'),
      FocusTask(id: 'c', title: 'C'),
      FocusTask(id: 'd', title: 'D'),
    ],
  );

  List<String> taskIds(ProviderContainer container) => container
      .read(todayProjectsProvider)
      .firstWhere((project) => project.id == 'ordered')
      .tasks
      .map((task) => task.id)
      .toList();

  test('completed tasks move last while preserving both relative orders', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(todayProjectsProvider.notifier);
    controller.replaceAllProjects([orderedTaskProject()]);

    controller.toggleTask('ordered', 'b');
    expect(taskIds(container), ['a', 'c', 'd', 'b']);

    controller.toggleTask('ordered', 'a');
    expect(taskIds(container), ['c', 'd', 'b', 'a']);
    final tasks = container.read(todayProjectsProvider).single.tasks;
    expect(tasks.take(2).every((task) => !task.isCompleted), isTrue);
    expect(tasks.skip(2).every((task) => task.isCompleted), isTrue);
  });

  test('uncompleted task returns at the end of the active section', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(todayProjectsProvider.notifier);
    controller.replaceAllProjects([orderedTaskProject()]);
    controller.toggleTask('ordered', 'b');
    controller.toggleTask('ordered', 'a');

    controller.toggleTask('ordered', 'b');

    expect(taskIds(container), ['c', 'd', 'b', 'a']);
    expect(
      container
          .read(todayProjectsProvider)
          .single
          .tasks
          .firstWhere((task) => task.id == 'b')
          .isCompleted,
      isFalse,
    );
  });

  test('task reorder does not affect another project', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(todayProjectsProvider.notifier);
    const other = FocusProject(
      id: 'other',
      name: 'Other',
      durationMinutes: 20,
      tasks: [FocusTask(id: 'x', title: 'X')],
    );
    controller.replaceAllProjects([orderedTaskProject(), other]);

    controller.toggleTask('ordered', 'b');

    final unchanged = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'other');
    expect(unchanged.tasks.map((task) => task.id), ['x']);
    expect(unchanged.tasks.single, same(other.tasks.single));
  });

  test('task order persists and marks projects for synchronization', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FocusDayStorage(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [focusDayStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final controller = container.read(todayProjectsProvider.notifier);
    controller.replaceAllProjects([orderedTaskProject()]);
    final notification = container.read(syncMutationBusProvider).changes.first;

    controller.toggleTask('ordered', 'b');
    expect(await notification, SyncDomain.projects);

    final reloaded = FocusDayStorage(await SharedPreferences.getInstance());
    expect(reloaded.loadProjects()!.single.tasks.map((task) => task.id), [
      'a',
      'c',
      'd',
      'b',
    ]);
    expect(reloaded.loadProjectsDirty(), isTrue);
    expect(reloaded.loadProjectsRevision(), 1);
  });

  test('terminer Bogoka active Formation .NET', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(todayProjectsProvider.notifier)
        .completeProjectAndActivateNext('bogoka');

    final projects = container.read(todayProjectsProvider);

    expect(
      projects.firstWhere((project) => project.id == 'bogoka').status,
      FocusProjectStatus.completed,
    );

    expect(
      projects.firstWhere((project) => project.id == 'dotnet').status,
      FocusProjectStatus.active,
    );

    final activeProjects = projects.where(
      (project) => project.status == FocusProjectStatus.active,
    );

    expect(activeProjects.length, 1);
  });

  test('ajoute un nouveau projet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(todayProjectsProvider.notifier)
        .addProject(
          name: 'Nouveau projet',
          durationMinutes: 45,
          taskTitles: ['Tâche 1', 'Tâche 2'],
        );

    final projects = container.read(todayProjectsProvider);

    final added = projects.last;

    expect(added.name, 'Nouveau projet');
    expect(added.durationMinutes, 45);
    expect(added.tasks.length, 2);
  });

  test('modifie un projet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(todayProjectsProvider.notifier)
        .updateProject(
          projectId: 'dotnet',
          name: 'Formation C#',
          durationMinutes: 45,
        );

    final project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'dotnet');

    expect(project.name, 'Formation C#');
    expect(project.durationMinutes, 45);
  });

  test('ne supprime pas le projet actif', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(todayProjectsProvider.notifier).deleteProject('bogoka');

    final projects = container.read(todayProjectsProvider);

    expect(projects.any((project) => project.id == 'bogoka'), isTrue);
  });

  test('supprime un projet en attente', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(todayProjectsProvider.notifier).deleteProject('akoffa');

    final projects = container.read(todayProjectsProvider);

    expect(projects.any((project) => project.id == 'akoffa'), isFalse);
  });

  test('ajoute modifie et supprime une tâche', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.addTask(projectId: 'dotnet', title: 'Créer endpoint API');

    var project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'dotnet');

    expect(project.tasks.length, 1);

    final taskId = project.tasks.first.id;

    controller.updateTask(
      projectId: 'dotnet',
      taskId: taskId,
      title: 'Créer endpoint REST',
    );

    project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'dotnet');

    expect(project.tasks.first.title, 'Créer endpoint REST');

    controller.deleteTask(projectId: 'dotnet', taskId: taskId);

    project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'dotnet');

    expect(project.tasks, isEmpty);
  });

  test('active le nouveau projet quand tous les autres sont terminés', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.completeProjectAndActivateNext('bogoka');
    controller.completeProjectAndActivateNext('dotnet');
    controller.completeProjectAndActivateNext('ovoodoc');
    controller.completeProjectAndActivateNext('akoffa');

    final beforeAdd = container.read(todayProjectsProvider);

    expect(
      beforeAdd.any((project) => project.status == FocusProjectStatus.active),
      isFalse,
    );

    controller.addProject(name: 'Nouveau projet actif', durationMinutes: 25);

    final projects = container.read(todayProjectsProvider);
    final added = projects.last;

    expect(added.name, 'Nouveau projet actif');
    expect(added.status, FocusProjectStatus.active);

    expect(
      projects
          .where((project) => project.status == FocusProjectStatus.active)
          .length,
      1,
    );
  });

  test('fait remonter le prochain projet actif en première position', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.completeProjectAndActivateNext('bogoka');

    final projects = container.read(todayProjectsProvider);

    expect(projects.first.id, 'dotnet');
    expect(projects.first.status, FocusProjectStatus.active);

    expect(
      projects.lastWhere((project) => project.id == 'bogoka').status,
      FocusProjectStatus.completed,
    );
  });

  test('réactive un projet terminé et le remet en première position', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.completeProjectAndActivateNext('bogoka');

    controller.reactivateProject('bogoka');

    final projects = container.read(todayProjectsProvider);

    expect(projects.first.id, 'bogoka');
    expect(projects.first.status, FocusProjectStatus.active);

    final dotnet = projects.firstWhere((project) => project.id == 'dotnet');

    expect(dotnet.status, FocusProjectStatus.waiting);

    expect(
      projects
          .where((project) => project.status == FocusProjectStatus.active)
          .length,
      1,
    );
  });

  test('réordonne les projets en attente sans déplacer le projet actif', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.reorderWaitingProject(projectId: 'akoffa', newWaitingIndex: 0);

    final projects = container.read(todayProjectsProvider);

    expect(projects[0].id, 'bogoka');
    expect(projects[0].status, FocusProjectStatus.active);

    expect(projects[1].id, 'akoffa');
    expect(projects[1].status, FocusProjectStatus.waiting);

    expect(projects[2].id, 'dotnet');
    expect(projects[3].id, 'ovoodoc');

    expect(
      projects
          .where((project) => project.status == FocusProjectStatus.active)
          .length,
      1,
    );
  });

  test('met à jour le titre et la description d’une tâche', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.updateTask(
      projectId: 'bogoka',
      taskId: 'bogoka-1',
      title: 'Nouvelle tâche',
      description: 'Détails de la tâche',
    );

    final project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'bogoka');

    final task = project.tasks.firstWhere((task) => task.id == 'bogoka-1');

    expect(task.title, 'Nouvelle tâche');
    expect(task.description, 'Détails de la tâche');
  });

  test('programme un projet à une date et une heure données', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    final scheduledAt = DateTime(2026, 9, 5, 14, 30);

    controller.scheduleProject(projectId: 'bogoka', scheduledAt: scheduledAt);

    final project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'bogoka');

    expect(project.scheduledAt, scheduledAt);
  });

  test('supprime la programmation d’un projet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    final scheduledAt = DateTime(2026, 9, 5, 14, 30);

    controller.scheduleProject(projectId: 'bogoka', scheduledAt: scheduledAt);

    controller.clearProjectSchedule('bogoka');

    final project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'bogoka');

    expect(project.scheduledAt, isNull);
  });

  test('démarre un projet en attente et remplace le projet actif', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.startProject('dotnet');

    final projects = container.read(todayProjectsProvider);

    expect(projects.first.id, 'dotnet');
    expect(projects.first.status, FocusProjectStatus.active);

    final bogoka = projects.firstWhere((project) => project.id == 'bogoka');

    expect(bogoka.status, FocusProjectStatus.waiting);

    expect(
      projects
          .where((project) => project.status == FocusProjectStatus.active)
          .length,
      1,
    );
  });

  test('met à jour les notes d’un projet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(todayProjectsProvider.notifier);

    controller.updateProjectNotes(
      projectId: 'bogoka',
      notes: 'Préparer la prochaine émission et vérifier le micro.',
    );

    final project = container
        .read(todayProjectsProvider)
        .firstWhere((project) => project.id == 'bogoka');

    expect(
      project.notes,
      'Préparer la prochaine émission et vérifier le micro.',
    );
  });

  test(
    'rapid project mutations persist monotone revisions and notify sync',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = FocusDayStorage(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [focusDayStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final notifications = container
          .read(syncMutationBusProvider)
          .changes
          .take(3)
          .toList();
      final controller = container.read(todayProjectsProvider.notifier);

      controller.updateProjectNotes(projectId: 'bogoka', notes: 'one');
      controller.updateProjectNotes(projectId: 'bogoka', notes: 'two');
      controller.updateProjectNotes(projectId: 'bogoka', notes: 'three');

      expect(await notifications, [
        SyncDomain.projects,
        SyncDomain.projects,
        SyncDomain.projects,
      ]);
      expect(storage.loadProjectsRevision(), 3);
      expect(storage.loadProjectsDirty(), isTrue);
      expect(storage.loadProjects()!.first.notes, 'three');
    },
  );
}
