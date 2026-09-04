import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'project_schedule_state.dart';

final projectScheduleProvider =
    NotifierProvider<ProjectScheduleController, ProjectScheduleState>(
      ProjectScheduleController.new,
    );

class ProjectScheduleController extends Notifier<ProjectScheduleState> {
  Timer? _ticker;

  @override
  ProjectScheduleState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });

    _startTicker();

    return ProjectScheduleState(now: DateTime.now());
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      state = ProjectScheduleState(now: DateTime.now());
    });
  }
}
