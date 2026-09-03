import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/domain/focus_project.dart';
import '../application/today_controller.dart';

import '../application/focus_timer_controller.dart';
import '../application/focus_timer_state.dart';

import '../../../core/window/window_mode_controller.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(todayProjectsProvider);

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
        label: const Text('Mini-bar'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aujourd’hui',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Concentre-toi sur un seul projet à la fois.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ProjectsPanel(projects: projects),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: _ActiveProjectPanel(project: activeProject),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsPanel extends StatelessWidget {
  const _ProjectsPanel({required this.projects});

  final List<FocusProject> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Text(
              'Projets du jour',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () => _showAddProjectDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = projects[index];

              return _ProjectCard(
                project: project,
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

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau projet'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du projet',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée en minutes',
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: task1Controller,
                    decoration: const InputDecoration(labelText: 'Tâche 1'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: task2Controller,
                    decoration: const InputDecoration(labelText: 'Tâche 2'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
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
              child: const Text('Ajouter'),
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
    final nameController = TextEditingController(text: project.name);

    final durationController = TextEditingController(
      text: project.durationMinutes.toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier le projet'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom du projet'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durée en minutes',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
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
              child: const Text('Enregistrer'),
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
    if (project.status == FocusProjectStatus.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer le projet actif.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le projet ?'),
          content: Text('Le projet "${project.name}" sera supprimé.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
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
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
  });

  final FocusProject project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final active = project.status == FocusProjectStatus.active;

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
                child: Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('${project.durationMinutes} min'),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'reactivate') {
                    onReactivate();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  if (project.status == FocusProjectStatus.completed)
                    const PopupMenuItem(
                      value: 'reactivate',
                      child: Text('Réactiver'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !active,
                    child: Text(
                      active ? 'Suppression impossible' : 'Supprimer',
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
}

class _ActiveProjectPanel extends ConsumerWidget {
  const _ActiveProjectPanel({required this.project});

  final FocusProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              _statusLabel(timer, isCurrentTimer),
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
            const SizedBox(height: 36),
            Center(
              child: Text(
                _formatSeconds(remainingSeconds),
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w300,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _timerCaption(timer, isCurrentTimer),
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
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),

            Row(
              children: [
                const Text(
                  'Tâches',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => _showAddTaskDialog(context, ref, project),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
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
                'Aucune tâche pour ce projet.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              for (final task in project.tasks)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  value: task.isCompleted,
                  onChanged: (_) {
                    ref
                        .read(todayProjectsProvider.notifier)
                        .toggleTask(project.id, task.id);
                  },
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
    final controller = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ajouter une tâche'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tâche',
                hintText: 'Ex. Lancer les tests',
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
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text('Ajouter'),
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

  static List<Widget> _buildTimerButtons({
    required WidgetRef ref,
    required FocusTimerState timer,
    required bool isCurrentTimer,
    required FocusProject project,
    required FocusTimerController controller,
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
          label: const Text('Préparer'),
        ),
      ];
    }

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return [
          FilledButton.icon(
            onPressed: controller.start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Démarrer'),
          ),
        ];

      case FocusTimerStatus.running:
        return [
          FilledButton.tonalIcon(
            onPressed: controller.pause,
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
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
            label: const Text('Terminer'),
          ),
        ];

      case FocusTimerStatus.paused:
        return [
          FilledButton.icon(
            onPressed: controller.resume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reprendre'),
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
            label: const Text('Terminer'),
          ),
        ];

      case FocusTimerStatus.completed:
        return [
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Terminé'),
          ),
        ];
    }
  }

  static String _statusLabel(FocusTimerState timer, bool isCurrentTimer) {
    if (!isCurrentTimer) {
      return 'EN ATTENTE';
    }

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return 'PRÊT';
      case FocusTimerStatus.running:
        return 'EN COURS';
      case FocusTimerStatus.paused:
        return 'EN PAUSE';
      case FocusTimerStatus.completed:
        return 'TERMINÉ';
    }
  }

  static String _timerCaption(FocusTimerState timer, bool isCurrentTimer) {
    if (!isCurrentTimer) {
      return 'durée prévue';
    }

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return 'prêt à démarrer';
      case FocusTimerStatus.running:
        return 'restantes';
      case FocusTimerStatus.paused:
        return 'en pause';
      case FocusTimerStatus.completed:
        return 'session terminée';
    }
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
