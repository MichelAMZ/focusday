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

    final hasActiveProject = state.any(
      (project) => project.status == FocusProjectStatus.active,
    );

    final newProjectStatus = hasActiveProject
        ? FocusProjectStatus.waiting
        : FocusProjectStatus.active;

    state = [
      ...state,
      FocusProject(
        id: projectId,
        name: trimmedName,
        durationMinutes: durationMinutes,
        tasks: tasks,
        status: newProjectStatus,
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
    String description = '',
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();

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
                  task.copyWith(
                    title: trimmedTitle,
                    description: trimmedDescription,
                  )
                else
                  task,
            ],
          )
        else
          project,
    ];

    _persist();
  }

  void scheduleProject({
    required String projectId,
    required DateTime scheduledAt,
  }) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(scheduledAt: scheduledAt)
        else
          project,
    ];

    _persist();
  }

  void clearProjectSchedule(String projectId) {
    state = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(clearScheduledAt: true)
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

    for (var i = 0; i < updatedProjects.length; i++) {
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

    state = _sortProjectsByPriority(updatedProjects);
    _persist();
  }

  void reactivateProject(String projectId) {
    final targetExists = state.any((project) => project.id == projectId);

    if (!targetExists) {
      return;
    }

    final updatedProjects = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(status: FocusProjectStatus.active)
        else if (project.status == FocusProjectStatus.active)
          project.copyWith(status: FocusProjectStatus.waiting)
        else
          project,
    ];

    state = _sortProjectsByPriority(updatedProjects);

    _persist();
  }

  void startProject(String projectId) {
    final targetExists = state.any((project) => project.id == projectId);

    if (!targetExists) {
      return;
    }

    final updatedProjects = [
      for (final project in state)
        if (project.id == projectId)
          project.copyWith(status: FocusProjectStatus.active)
        else if (project.status == FocusProjectStatus.active)
          project.copyWith(status: FocusProjectStatus.waiting)
        else
          project,
    ];

    state = _sortProjectsByPriority(updatedProjects);

    _persist();
  }

  void reorderWaitingProject({
    required String projectId,
    required int newWaitingIndex,
  }) {
    final waitingProjects = state
        .where((project) => project.status == FocusProjectStatus.waiting)
        .toList();

    final oldWaitingIndex = waitingProjects.indexWhere(
      (project) => project.id == projectId,
    );

    if (oldWaitingIndex == -1) {
      return;
    }

    final boundedIndex = newWaitingIndex.clamp(0, waitingProjects.length - 1);

    if (oldWaitingIndex == boundedIndex) {
      return;
    }

    final movedProject = waitingProjects.removeAt(oldWaitingIndex);

    waitingProjects.insert(boundedIndex, movedProject);

    var waitingIndex = 0;

    final updatedProjects = [
      for (final project in state)
        if (project.status == FocusProjectStatus.waiting)
          waitingProjects[waitingIndex++]
        else
          project,
    ];

    state = _sortProjectsByPriority(updatedProjects);

    _persist();
  }

  List<FocusProject> _sortProjectsByPriority(List<FocusProject> projects) {
    final active = projects.where(
      (project) => project.status == FocusProjectStatus.active,
    );

    final paused = projects.where(
      (project) => project.status == FocusProjectStatus.paused,
    );

    final waiting = projects.where(
      (project) => project.status == FocusProjectStatus.waiting,
    );

    final completed = projects.where(
      (project) => project.status == FocusProjectStatus.completed,
    );

    return [...active, ...paused, ...waiting, ...completed];
  }
}
