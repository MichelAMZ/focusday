import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/domain/focus_project.dart';
import '../application/today_controller.dart';

import '../application/focus_timer_controller.dart';
import '../application/focus_timer_state.dart';

import '../../../core/window/window_mode_controller.dart';
import '../../projects/domain/focus_task.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/account_page.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_page.dart';
import '../../../l10n/app_localizations.dart';

import '../application/project_schedule_controller.dart';
import '../application/project_schedule_state.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  final Map<String, ProjectSchedulePhase> _previousSchedulePhases = {};
  bool _scheduleAlertPending = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projects = ref.watch(todayProjectsProvider);
    final scheduleState = ref.watch(projectScheduleProvider);

    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authStateChangesProvider);

    if (settings.scheduledProjectAlertsEnabled) {
      _checkScheduleAlerts(projects, scheduleState);
    }

    final activeProject = projects.firstWhere(
      (project) => project.status == FocusProjectStatus.active,
      orElse: () => projects.first,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(focusWindowModeProvider.notifier).enterMiniMode();
        },
        icon: const Icon(Icons.view_stream_outlined),
        label: Text(l10n.miniBarLabel),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/focusday_logo_cropped.png',
                    height: 54,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.todayTitle,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.todaySubtitle,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  authState.when(
                    data: (user) {
                      final email = user?.email?.trim();
                      final initial = email != null && email.isNotEmpty
                          ? email.substring(0, 1).toUpperCase()
                          : '?';

                      return Tooltip(
                        message: user == null
                            ? 'Compte non connecté'
                            : 'Connecté : ${email ?? 'Compte Firebase'}',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => const AccountPage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: user == null
                                ? const CircleAvatar(
                                    radius: 18,
                                    child: Icon(Icons.person_outline, size: 20),
                                  )
                                : user.photoURL != null &&
                                      user.photoURL!.isNotEmpty
                                ? CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(
                                      user.photoURL!,
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 18,
                                    child: Text(initial),
                                  ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(width: 52, height: 52),
                    error: (error, stackTrace) => const CircleAvatar(
                      radius: 18,
                      child: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.settingsTooltip,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    final showNotesPanel =
                        constraints.maxWidth >= 1050 &&
                        activeProject.notes.trim().isNotEmpty;
                    if (!isWide) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 420,
                              child: _ProjectsPanel(projects: projects),
                            ),
                            const SizedBox(height: 24),
                            _ActiveProjectPanel(project: activeProject),
                            if (activeProject.notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 320,
                                child: _ProjectNotesPanel(
                                  project: activeProject,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _ProjectsPanel(projects: projects),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: showNotesPanel ? 3 : 5,
                          child: _ActiveProjectPanel(project: activeProject),
                        ),
                        if (showNotesPanel) ...[
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _ProjectNotesPanel(project: activeProject),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkScheduleAlerts(
    List<FocusProject> projects,
    ProjectScheduleState scheduleState,
  ) {
    if (_scheduleAlertPending) {
      return;
    }

    for (final project in projects) {
      final scheduledAt = project.scheduledAt;

      if (scheduledAt == null || project.status == FocusProjectStatus.active) {
        continue;
      }

      final scheduleKey = '${project.id}:${scheduledAt.toIso8601String()}';

      final currentPhase = scheduleState.phaseFor(scheduledAt);
      final previousPhase = _previousSchedulePhases[scheduleKey];

      _previousSchedulePhases[scheduleKey] = currentPhase;

      if (previousPhase == ProjectSchedulePhase.soon &&
          currentPhase == ProjectSchedulePhase.due) {
        _scheduleAlertPending = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          _showScheduleAlert(project);
        });

        return;
      }
    }
  }

  Future<void> _showScheduleAlert(FocusProject project) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.projectDueTitle),
          content: Text(l10n.projectDueMessage(project.name)),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.okButton),
            ),
          ],
        );
      },
    );

    if (mounted) {
      setState(() {
        _scheduleAlertPending = false;
      });
    }
  }
}

Future<void> _editProjectNotes(
  BuildContext context,
  FocusProject project,
) async {
  final notesController = TextEditingController(text: project.notes);
  final l10n = AppLocalizations.of(context)!;

  final notes = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.notesTitle(project.name)),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: notesController,
            autofocus: true,
            minLines: 10,
            maxLines: 18,
            decoration: InputDecoration(
              hintText: l10n.notesHint,
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.cancelButton),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop(notesController.text);
            },
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.saveButton),
          ),
        ],
      );
    },
  );

  notesController.dispose();

  if (notes == null || !context.mounted) {
    return;
  }

  ProviderScope.containerOf(context)
      .read(todayProjectsProvider.notifier)
      .updateProjectNotes(projectId: project.id, notes: notes);
}

class _ProjectsPanel extends StatelessWidget {
  const _ProjectsPanel({required this.projects});

  final List<FocusProject> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;

            return Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  l10n.projectsOfDayTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddProjectDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addButton),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: projects.length,
            onReorderItem: (oldIndex, newIndex) {
              final project = projects[oldIndex];

              if (project.status != FocusProjectStatus.waiting) {
                return;
              }

              final waitingProjects = projects
                  .where((item) => item.status == FocusProjectStatus.waiting)
                  .toList();

              final waitingStartIndex = projects.indexWhere(
                (item) => item.status == FocusProjectStatus.waiting,
              );

              if (waitingStartIndex == -1) {
                return;
              }

              var targetWaitingIndex = newIndex - waitingStartIndex;

              targetWaitingIndex = targetWaitingIndex.clamp(
                0,
                waitingProjects.length - 1,
              );

              ProviderScope.containerOf(context)
                  .read(todayProjectsProvider.notifier)
                  .reorderWaitingProject(
                    projectId: project.id,
                    newWaitingIndex: targetWaitingIndex,
                  );
            },

            itemBuilder: (context, index) {
              final project = projects[index];

              return Padding(
                key: ValueKey(project.id),
                padding: EdgeInsets.only(
                  bottom: index == projects.length - 1 ? 0 : 12,
                ),
                child: _ProjectCard(
                  project: project,
                  reorderIndex: index,
                  onEdit: () => _showEditProjectDialog(context, project),
                  onDelete: () => _confirmDeleteProject(context, project),
                  onReactivate: () {
                    final container = ProviderScope.containerOf(context);

                    container
                        .read(todayProjectsProvider.notifier)
                        .reactivateProject(project.id);

                    container
                        .read(focusTimerProvider.notifier)
                        .reset(
                          projectId: project.id,
                          durationMinutes: project.durationMinutes,
                        );
                  },
                  onStart: () async {
                    final confirmed = await _confirmStartProject(
                      context,
                      project,
                    );

                    if (!confirmed || !context.mounted) {
                      return;
                    }

                    final container = ProviderScope.containerOf(context);

                    container
                        .read(todayProjectsProvider.notifier)
                        .startProject(project.id);

                    container
                        .read(focusTimerProvider.notifier)
                        .reset(
                          projectId: project.id,
                          durationMinutes: project.durationMinutes,
                        );
                  },
                  onSchedule: () =>
                      _showScheduleProjectDialog(context, project),
                  onNotes: () => _editProjectNotes(context, project),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddProjectDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    final task1Controller = TextEditingController();
    final task2Controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.newProjectTitle),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.projectNameLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.durationMinutesLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: task1Controller,
                    decoration: InputDecoration(labelText: l10n.task1Label),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: task2Controller,
                    decoration: InputDecoration(labelText: l10n.task2Label),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () {
                final duration = int.tryParse(durationController.text.trim());

                if (nameController.text.trim().isEmpty ||
                    duration == null ||
                    duration <= 0) {
                  return;
                }

                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'duration': duration,
                  'tasks': [
                    task1Controller.text.trim(),
                    task2Controller.text.trim(),
                  ],
                });
              },
              child: Text(l10n.addButton),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    durationController.dispose();
    task1Controller.dispose();
    task2Controller.dispose();

    if (result == null || !context.mounted) {
      return;
    }

    final container = ProviderScope.containerOf(context);

    final projectsBeforeAdd = container.read(todayProjectsProvider);

    final hadActiveProject = projectsBeforeAdd.any(
      (project) => project.status == FocusProjectStatus.active,
    );

    container
        .read(todayProjectsProvider.notifier)
        .addProject(
          name: result['name'] as String,
          durationMinutes: result['duration'] as int,
          taskTitles: result['tasks'] as List<String>,
        );

    if (!hadActiveProject) {
      final projectsAfterAdd = container.read(todayProjectsProvider);

      FocusProject? activeProject;

      for (final project in projectsAfterAdd) {
        if (project.status == FocusProjectStatus.active) {
          activeProject = project;
          break;
        }
      }

      if (activeProject != null) {
        container
            .read(focusTimerProvider.notifier)
            .reset(
              projectId: activeProject.id,
              durationMinutes: activeProject.durationMinutes,
            );
      }
    }
  }

  Future<void> _showEditProjectDialog(
    BuildContext context,
    FocusProject project,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: project.name);

    final durationController = TextEditingController(
      text: project.durationMinutes.toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.editProjectTitle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l10n.projectNameLabel),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.durationMinutesLabel,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () {
                final duration = int.tryParse(durationController.text.trim());

                if (nameController.text.trim().isEmpty ||
                    duration == null ||
                    duration <= 0) {
                  return;
                }

                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'duration': duration,
                });
              },
              child: Text(l10n.saveButton),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    durationController.dispose();

    if (result == null || !context.mounted) {
      return;
    }

    ProviderScope.containerOf(context)
        .read(todayProjectsProvider.notifier)
        .updateProject(
          projectId: project.id,
          name: result['name'] as String,
          durationMinutes: result['duration'] as int,
        );
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    FocusProject project,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    if (project.status == FocusProjectStatus.active) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.activeProjectDeleteError)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteProjectTitle),
          content: Text(l10n.deleteProjectMessage(project.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deleteButton),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    ProviderScope.containerOf(
      context,
    ).read(todayProjectsProvider.notifier).deleteProject(project.id);
  }

  Future<bool> _confirmStartProject(
    BuildContext context,
    FocusProject project,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final container = ProviderScope.containerOf(context);
    final projects = container.read(todayProjectsProvider);

    FocusProject? activeProject;

    for (final item in projects) {
      if (item.status == FocusProjectStatus.active && item.id != project.id) {
        activeProject = item;
        break;
      }
    }

    if (activeProject == null) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.changeProjectTitle),
          content: Text(
            l10n.changeProjectMessage(activeProject!.name, project.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.changeProjectButton),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _showScheduleProjectDialog(
    BuildContext context,
    FocusProject project,
  ) async {
    final now = DateTime.now();

    final initialDate = project.scheduledAt ?? now;
    final initialTime = TimeOfDay.fromDateTime(project.scheduledAt ?? now);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (selectedDate == null || !context.mounted) {
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime == null || !context.mounted) {
      return;
    }

    final scheduledAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    ProviderScope.containerOf(context)
        .read(todayProjectsProvider.notifier)
        .scheduleProject(projectId: project.id, scheduledAt: scheduledAt);
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
    required this.reorderIndex,
    required this.onSchedule,
    required this.onStart,
    required this.onNotes,
  });

  final FocusProject project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;
  final int reorderIndex;
  final VoidCallback onSchedule;
  final VoidCallback onStart;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final active = project.status == FocusProjectStatus.active;

    final scheduleState = ref.watch(projectScheduleProvider);

    final schedulePhase = scheduleState.phaseFor(project.scheduledAt);

    return Opacity(
      opacity: active ? 1 : 0.38,
      child: Card(
        elevation: active ? 3 : 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                active
                    ? Icons.play_circle_fill
                    : project.status == FocusProjectStatus.completed
                    ? Icons.check_circle
                    : Icons.schedule,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          '${project.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (project.scheduledAt != null)
                          Text(
                            _formatScheduledAt(project.scheduledAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                    if (schedulePhase == ProjectSchedulePhase.soon)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.scheduleSoonLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    if (schedulePhase == ProjectSchedulePhase.due &&
                        project.status != FocusProjectStatus.active)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.scheduleDueLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    if (schedulePhase == ProjectSchedulePhase.due &&
                        project.status != FocusProjectStatus.active)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          onPressed: onStart,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(l10n.startButton),
                        ),
                      ),
                  ],
                ),
              ),

              if (project.status == FocusProjectStatus.waiting) ...[
                const SizedBox(width: 8),
                ReorderableDragStartListener(
                  index: reorderIndex,
                  child: Tooltip(
                    message: l10n.changePriorityTooltip,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                ),
              ],
              PopupMenuButton<String>(
                tooltip: l10n.actionsTooltip,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'reactivate') {
                    onReactivate();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'schedule') {
                    onSchedule();
                  } else if (value == 'clearSchedule') {
                    ProviderScope.containerOf(context)
                        .read(todayProjectsProvider.notifier)
                        .clearProjectSchedule(project.id);
                  } else if (value == 'notes') {
                    onNotes();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(l10n.editButton)),
                  if (project.status == FocusProjectStatus.completed)
                    PopupMenuItem(
                      value: 'reactivate',
                      child: Text(l10n.reactivateButton),
                    ),
                  PopupMenuItem(
                    value: 'schedule',
                    child: Text(
                      project.scheduledAt == null
                          ? l10n.scheduleButton
                          : l10n.editScheduleButton,
                    ),
                  ),
                  if (project.scheduledAt != null)
                    PopupMenuItem(
                      value: 'clearSchedule',
                      child: Text(l10n.clearScheduleButton),
                    ),
                  PopupMenuItem(
                    value: 'notes',
                    child: Text(l10n.notesMenuItem),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !active,
                    child: Text(
                      active ? l10n.deleteUnavailableLabel : l10n.deleteButton,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatScheduledAt(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month · $hour:$minute';
  }
}

class _ProjectNotesPanel extends StatelessWidget {
  const _ProjectNotesPanel({required this.project});

  final FocusProject project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.notesPanelTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.editNotesTooltip,
                  onPressed: () => _editProjectNotes(context, project),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      project.notes,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveProjectPanel extends ConsumerWidget {
  const _ActiveProjectPanel({required this.project});

  final FocusProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final completedTasks = project.tasks
        .where((task) => task.isCompleted)
        .length;

    final timer = ref.watch(focusTimerProvider);
    final timerController = ref.read(focusTimerProvider.notifier);

    final isCurrentTimer = timer.projectId == project.id;

    final remainingSeconds = isCurrentTimer
        ? timer.remainingSeconds
        : project.durationMinutes * 60;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusLabel(timer, isCurrentTimer, l10n),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              project.name,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _timerProgress(
                          timer.initialSeconds,
                          remainingSeconds,
                        ),
                        strokeWidth: 10,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _timerColor(context, remainingSeconds),
                        ),
                      ),
                    ),
                    Text(
                      _formatSeconds(remainingSeconds),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        color: _timerColor(context, remainingSeconds),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _timerCaption(timer, isCurrentTimer, l10n),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _buildTimerButtons(
                  ref: ref,
                  timer: timer,
                  isCurrentTimer: isCurrentTimer,
                  project: project,
                  controller: timerController,
                  l10n: l10n,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),

            Row(
              children: [
                Text(
                  l10n.tasksTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => _showAddTaskDialog(context, ref, project),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addButton),
                ),
                const Spacer(),
                Text(
                  '$completedTasks/${project.tasks.length}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (project.tasks.isEmpty)
              Text(
                l10n.noTasksMessage,
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              for (final task in project.tasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: task.isCompleted,
                    onChanged: (_) {
                      ref
                          .read(todayProjectsProvider.notifier)
                          .toggleTask(project.id, task.id);
                    },
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: task.description.isEmpty
                      ? null
                      : Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showEditTaskDialog(context, ref, project, task),
                ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showAddTaskDialog(
    BuildContext context,
    WidgetRef ref,
    FocusProject project,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.addTaskTitle),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.taskLabel,
                hintText: l10n.taskExampleHint,
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();

                if (trimmed.isNotEmpty) {
                  Navigator.of(dialogContext).pop(trimmed);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: Text(l10n.addButton),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (title == null || !context.mounted) {
      return;
    }

    ref
        .read(todayProjectsProvider.notifier)
        .addTask(projectId: project.id, title: title);
  }

  static Future<void> _showEditTaskDialog(
    BuildContext context,
    WidgetRef ref,
    FocusProject project,
    FocusTask task,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.taskDetailsTitle),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.taskTitleLabel),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: l10n.taskDescriptionLabel,
                    hintText: l10n.taskDescriptionHint,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();

                if (title.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop({
                  'title': title,
                  'description': descriptionController.text.trim(),
                });
              },
              child: Text(l10n.saveButton),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (result == null || !context.mounted) {
      return;
    }

    ref
        .read(todayProjectsProvider.notifier)
        .updateTask(
          projectId: project.id,
          taskId: task.id,
          title: result['title']!,
          description: result['description'] ?? '',
        );
  }

  static List<Widget> _buildTimerButtons({
    required WidgetRef ref,
    required FocusTimerState timer,
    required bool isCurrentTimer,
    required FocusProject project,
    required FocusTimerController controller,
    required AppLocalizations l10n,
  }) {
    if (!isCurrentTimer) {
      return [
        FilledButton.icon(
          onPressed: () {
            controller.reset(
              projectId: project.id,
              durationMinutes: project.durationMinutes,
            );
          },
          icon: const Icon(Icons.timer_outlined),
          label: Text(l10n.prepareButton),
        ),
      ];
    }

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return [
          FilledButton.icon(
            onPressed: controller.start,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startButton),
          ),
        ];

      case FocusTimerStatus.running:
        return [
          FilledButton.tonalIcon(
            onPressed: controller.pause,
            icon: const Icon(Icons.pause),
            label: Text(l10n.pauseButton),
          ),
          OutlinedButton.icon(
            onPressed: () => controller.addMinutes(15),
            icon: const Icon(Icons.add),
            label: const Text('+15 min'),
          ),
          FilledButton.icon(
            onPressed: () {
              controller.complete();

              ref
                  .read(todayProjectsProvider.notifier)
                  .completeProjectAndActivateNext(project.id);

              final projects = ref.read(todayProjectsProvider);

              FocusProject? nextProject;

              for (final candidate in projects) {
                if (candidate.status == FocusProjectStatus.active) {
                  nextProject = candidate;
                  break;
                }
              }

              if (nextProject != null) {
                controller.reset(
                  projectId: nextProject.id,
                  durationMinutes: nextProject.durationMinutes,
                );
              }
            },
            icon: const Icon(Icons.check),
            label: Text(l10n.finishButton),
          ),
        ];

      case FocusTimerStatus.paused:
        return [
          FilledButton.icon(
            onPressed: controller.resume,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.resumeButton),
          ),
          OutlinedButton.icon(
            onPressed: () => controller.addMinutes(15),
            icon: const Icon(Icons.add),
            label: const Text('+15 min'),
          ),
          FilledButton.icon(
            onPressed: () {
              controller.complete();

              ref
                  .read(todayProjectsProvider.notifier)
                  .completeProjectAndActivateNext(project.id);

              final projects = ref.read(todayProjectsProvider);

              FocusProject? nextProject;

              for (final candidate in projects) {
                if (candidate.status == FocusProjectStatus.active) {
                  nextProject = candidate;
                  break;
                }
              }

              if (nextProject != null) {
                controller.reset(
                  projectId: nextProject.id,
                  durationMinutes: nextProject.durationMinutes,
                );
              }
            },
            icon: const Icon(Icons.check),
            label: Text(l10n.finishButton),
          ),
        ];

      case FocusTimerStatus.completed:
        return [
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle),
            label: Text(l10n.completedButton),
          ),
        ];
    }
  }

  static String _statusLabel(
    FocusTimerState timer,
    bool isCurrentTimer,
    AppLocalizations l10n,
  ) {
    if (!isCurrentTimer) {
      return l10n.timerStatusWaiting;
    }

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return l10n.timerStatusReady;
      case FocusTimerStatus.running:
        return l10n.timerStatusRunning;
      case FocusTimerStatus.paused:
        return l10n.timerStatusPaused;
      case FocusTimerStatus.completed:
        return l10n.timerStatusCompleted;
    }
  }

  static String _timerCaption(
    FocusTimerState timer,
    bool isCurrentTimer,
    AppLocalizations l10n,
  ) {
    if (!isCurrentTimer) {
      return l10n.timerCaptionPlannedDuration;
    }

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return l10n.timerCaptionReady;
      case FocusTimerStatus.running:
        return l10n.timerCaptionRemaining;
      case FocusTimerStatus.paused:
        return l10n.timerCaptionPaused;
      case FocusTimerStatus.completed:
        return l10n.timerCaptionCompleted;
    }
  }

  static double _timerProgress(int initialSeconds, int remainingSeconds) {
    if (initialSeconds <= 0) {
      return 1.0;
    }

    final progress = 1 - (remainingSeconds / initialSeconds);

    return progress.clamp(0.0, 1.0);
  }

  static Color _timerColor(BuildContext context, int remainingSeconds) {
    if (remainingSeconds <= 60) {
      return Colors.red.shade700;
    }

    if (remainingSeconds <= 300) {
      return Colors.orange.shade800;
    }

    if (remainingSeconds <= 600) {
      return Colors.green.shade700;
    }

    return Theme.of(context).colorScheme.primary;
  }

  static String _formatSeconds(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;

    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
