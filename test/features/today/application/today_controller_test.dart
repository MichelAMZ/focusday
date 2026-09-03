import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focusday/features/projects/domain/focus_project.dart';
import 'package:focusday/features/today/application/today_controller.dart';

void main() {
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
}
