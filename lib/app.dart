import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/window/window_mode_controller.dart';
import 'features/projects/domain/focus_project.dart';
import 'features/today/application/focus_timer_controller.dart';
import 'features/today/application/focus_timer_state.dart';
import 'features/today/application/today_controller.dart';
import 'features/today/presentation/mini_bar_page.dart';
import 'features/today/presentation/today_page.dart';

class FocusDayApp extends ConsumerStatefulWidget {
  const FocusDayApp({super.key});

  @override
  ConsumerState<FocusDayApp> createState() => _FocusDayAppState();
}

class _FocusDayAppState extends ConsumerState<FocusDayApp> {
  bool _completionSyncScheduled = false;

  @override
  Widget build(BuildContext context) {
    final windowMode = ref.watch(focusWindowModeProvider);
    final timer = ref.watch(focusTimerProvider);
    final projects = ref.watch(todayProjectsProvider);

    _scheduleCompletedProjectSync(timer, projects);

    return MaterialApp(
      title: 'FocusDay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: windowMode == FocusWindowMode.mini
          ? const MiniBarPage()
          : const TodayPage(),
    );
  }

  void _scheduleCompletedProjectSync(
    FocusTimerState timer,
    List<FocusProject> projects,
  ) {
    if (_completionSyncScheduled) {
      return;
    }

    if (timer.status != FocusTimerStatus.completed) {
      return;
    }

    final hasMatchingActiveProject = projects.any(
      (project) =>
          project.id == timer.projectId &&
          project.status == FocusProjectStatus.active,
    );

    if (!hasMatchingActiveProject) {
      return;
    }

    _completionSyncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _completionSyncScheduled = false;
      _synchronizeCompletedProject();
    });
  }

  void _synchronizeCompletedProject() {
    final timer = ref.read(focusTimerProvider);

    if (timer.status != FocusTimerStatus.completed) {
      return;
    }

    final projects = ref.read(todayProjectsProvider);

    final matchingProjectIsActive = projects.any(
      (project) =>
          project.id == timer.projectId &&
          project.status == FocusProjectStatus.active,
    );

    if (!matchingProjectIsActive) {
      return;
    }

    ref
        .read(todayProjectsProvider.notifier)
        .completeProjectAndActivateNext(timer.projectId);

    final updatedProjects = ref.read(todayProjectsProvider);

    FocusProject? nextProject;

    for (final project in updatedProjects) {
      if (project.status == FocusProjectStatus.active) {
        nextProject = project;
        break;
      }
    }

    if (nextProject != null) {
      ref
          .read(focusTimerProvider.notifier)
          .reset(
            projectId: nextProject.id,
            durationMinutes: nextProject.durationMinutes,
          );
    }
  }
}
