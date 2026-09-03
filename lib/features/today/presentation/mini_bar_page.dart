import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/window/window_mode_controller.dart';
import '../../projects/domain/focus_project.dart';
import '../application/focus_timer_controller.dart';
import '../application/focus_timer_state.dart';
import '../application/today_controller.dart';

class MiniBarPage extends ConsumerStatefulWidget {
  const MiniBarPage({super.key});

  @override
  ConsumerState<MiniBarPage> createState() => _MiniBarPageState();
}

class _MiniBarPageState extends ConsumerState<MiniBarPage> {
  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  Timer? _blinkTicker;
  bool _borderVisible = true;
  int? _lastBlinkSpeedMs;

  @override
  void initState() {
    super.initState();

    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _blinkTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(todayProjectsProvider);
    final timer = ref.watch(focusTimerProvider);

    if (projects.isEmpty) {
      return const Scaffold(body: Center(child: Text('Aucun projet')));
    }

    final activeProject = projects.firstWhere(
      (project) => project.status == FocusProjectStatus.active,
      orElse: () => projects.first,
    );

    final isCurrentTimer = timer.projectId == activeProject.id;

    final remainingSeconds = isCurrentTimer
        ? timer.remainingSeconds
        : activeProject.durationMinutes * 60;

    final timerColor = _timerColor(context, remainingSeconds);

    _updateBlinking(timer.status, remainingSeconds);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: _borderVisible ? timerColor : Colors.transparent,
            width: remainingSeconds <= 60 ? 3 : 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    timer.status == FocusTimerStatus.running
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    size: 16,
                    color: timerColor,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      activeProject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    _formatSeconds(remainingSeconds),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: timerColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  _TimerActionButton(timer: timer),
                  IconButton(
                    tooltip: 'Restaurer FocusDay',
                    onPressed: () {
                      ref
                          .read(focusWindowModeProvider.notifier)
                          .restoreNormalMode();
                    },
                    icon: const Icon(Icons.open_in_full),
                  ),
                  IconButton(
                    tooltip: 'Fermer FocusDay',
                    onPressed: () {
                      ref.read(focusWindowModeProvider.notifier).closeApp();
                    },
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatDateTime(_now),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateBlinking(FocusTimerStatus status, int remainingSeconds) {
    final shouldBlink =
        status == FocusTimerStatus.running && remainingSeconds <= 300;

    if (!shouldBlink) {
      if (_blinkTicker != null) {
        _blinkTicker?.cancel();
        _blinkTicker = null;
      }

      _lastBlinkSpeedMs = null;

      if (!_borderVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _borderVisible = true;
            });
          }
        });
      }

      return;
    }

    final blinkSpeedMs = remainingSeconds <= 60 ? 250 : 500;

    if (_blinkTicker != null && _lastBlinkSpeedMs == blinkSpeedMs) {
      return;
    }

    _blinkTicker?.cancel();
    _lastBlinkSpeedMs = blinkSpeedMs;

    _blinkTicker = Timer.periodic(Duration(milliseconds: blinkSpeedMs), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _borderVisible = !_borderVisible;
      });
    });
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

  static String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month  $hour:$minute';
  }
}

class _TimerActionButton extends ConsumerWidget {
  const _TimerActionButton({required this.timer});

  final FocusTimerState timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(focusTimerProvider.notifier);

    switch (timer.status) {
      case FocusTimerStatus.idle:
        return IconButton(
          tooltip: 'Démarrer',
          onPressed: controller.start,
          icon: const Icon(Icons.play_arrow),
        );

      case FocusTimerStatus.running:
        return IconButton(
          tooltip: 'Pause',
          onPressed: controller.pause,
          icon: const Icon(Icons.pause),
        );

      case FocusTimerStatus.paused:
        return IconButton(
          tooltip: 'Reprendre',
          onPressed: controller.resume,
          icon: const Icon(Icons.play_arrow),
        );

      case FocusTimerStatus.completed:
        return const IconButton(
          tooltip: 'Terminé',
          onPressed: null,
          icon: Icon(Icons.check_circle),
        );
    }
  }
}
