import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_provider.dart';
import '../../projects/domain/focus_project.dart';
import '../../projects/domain/focus_task.dart';

final todayProjectsProvider =
    NotifierProvider<TodayProjectsController, List<FocusProject>>(
      TodayProjectsController.new,
    );

class TodayProjectsController extends Notifier<List<FocusProject>> {
  @override
  List<FocusProject> build() {
    final storage = ref.watch(focusDayStorageProvider);
    final savedProjects = storage?.loadProjects();

    if (savedProjects != null && savedProjects.isNotEmpty) {
      return savedProjects;
    }

    return _defaultProjects;
  }

  List<FocusProject> get _defaultProjects => const [
    FocusProject(
      id: 'bogoka',
      name: 'Bogoka',
      durationMinutes: 60,
      status: FocusProjectStatus.active,
      tasks: [
        FocusTask(id: 'bogoka-1', title: 'Définir les tâches de la session'),
        FocusTask(id: 'bogoka-2', title: 'Travailler sur le projet'),
        FocusTask(id: 'bogoka-3', title: 'Lancer les tests'),
        FocusTask(id: 'bogoka-4', title: 'Créer un checkpoint'),
      ],
    ),
    FocusProject(
      id: 'dotnet',
      name: 'Formation .NET',
      durationMinutes: 30,
      tasks: [],
    ),
    FocusProject(
      id: 'ovoodoc',
      name: 'OvooDoc',
      durationMinutes: 30,
      tasks: [],
    ),
    FocusProject(id: 'akoffa', name: 'Akoffa', durationMinutes: 30, tasks: []),
  ];

  void _persist() {
    final storage = ref.read(focusDayStorageProvider);

    if (storage == null) {
      return;
    }

    storage.saveProjects(state);
  }

  void toggleTask(String projectId, String taskId) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            tasks: [
              for (final task in project.tasks)
                if (task.id == taskId)
                  task.copyWith(isCompleted: !task.isCompleted)
                else
                  task,
            ],
          )
        else
          project,
    ];

    _persist();
  }

  void addProject({
    required String name,
    required int durationMinutes,
    List<String> taskTitles = const [],
  }) {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty || durationMinutes <= 0) {
      return;
    }

    final projectId = 'project-${DateTime.now().microsecondsSinceEpoch}';

    final tasks = [
      for (var i = 0; i < taskTitles.length; i++)
        if (taskTitles[i].trim().isNotEmpty)
          FocusTask(id: '$projectId-task-$i', title: taskTitles[i].trim()),
    ];

    state = [
      ...state,
      FocusProject(
        id: projectId,
        name: trimmedName,
        durationMinutes: durationMinutes,
        tasks: tasks,
      ),
    ];

    _persist();
  }

  void updateProject({
    required String projectId,
    required String name,
    required int durationMinutes,
  }) {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty || durationMinutes <= 0) {
      return;
    }

    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(name: trimmedName, durationMinutes: durationMinutes)
        else
          project,
    ];

    _persist();
  }

  void deleteProject(String projectId) {
    FocusProject? project;

    for (final item in state) {
      if (item.id == projectId) {
        project = item;
        break;
      }
    }

    if (project == null) {
      return;
    }

    if (project.status == FocusProjectStatus.active) {
      return;
    }

    state = state.where((item) => item.id != projectId).toList();

    _persist();
  }

  void addTask({required String projectId, required String title}) {
    final trimmedTitle = title.trim();

    if (trimmedTitle.isEmpty) {
      return;
    }

    final taskId = '$projectId-task-${DateTime.now().microsecondsSinceEpoch}';

    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            tasks: [
              ...project.tasks,
              FocusTask(id: taskId, title: trimmedTitle),
            ],
          )
        else
          project,
    ];

    _persist();
  }

  void updateTask({
    required String projectId,
    required String taskId,
    required String title,
  }) {
    final trimmedTitle = title.trim();

    if (trimmedTitle.isEmpty) {
      return;
    }

    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            tasks: [
              for (final task in project.tasks)
                if (task.id == taskId)
                  task.copyWith(title: trimmedTitle)
                else
                  task,
            ],
          )
        else
          project,
    ];

    _persist();
  }

  void deleteTask({required String projectId, required String taskId}) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(
            tasks: project.tasks.where((task) => task.id != taskId).toList(),
          )
        else
          project,
    ];

    _persist();
  }

  void completeProjectAndActivateNext(String projectId) {
    final currentIndex = state.indexWhere((project) => project.id == projectId);

    if (currentIndex == -1) {
      return;
    }

    final updatedProjects = [...state];

    updatedProjects[currentIndex] = updatedProjects[currentIndex].copyWith(
      status: FocusProjectStatus.completed,
    );

    int? nextIndex;

    for (var i = currentIndex + 1; i < updatedProjects.length; i++) {
      if (updatedProjects[i].status == FocusProjectStatus.waiting) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex != null) {
      updatedProjects[nextIndex] = updatedProjects[nextIndex].copyWith(
        status: FocusProjectStatus.active,
      );
    }

    state = updatedProjects;

    _persist();
  }
}
