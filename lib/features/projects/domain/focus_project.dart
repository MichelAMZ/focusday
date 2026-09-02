import 'focus_task.dart';

enum FocusProjectStatus { waiting, active, paused, completed }

class FocusProject {
  const FocusProject({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.tasks,
    this.status = FocusProjectStatus.waiting,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final List<FocusTask> tasks;
  final FocusProjectStatus status;

  FocusProject copyWith({
    String? id,
    String? name,
    int? durationMinutes,
    List<FocusTask>? tasks,
    FocusProjectStatus? status,
  }) {
    return FocusProject(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tasks: tasks ?? this.tasks,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }

  factory FocusProject.fromJson(Map<String, dynamic> json) {
    final statusName =
        json['status'] as String? ?? FocusProjectStatus.waiting.name;

    final status = FocusProjectStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => FocusProjectStatus.waiting,
    );

    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];

    return FocusProject(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: json['durationMinutes'] as int,
      status: status,
      tasks: rawTasks
          .map(
            (task) =>
                FocusTask.fromJson(Map<String, dynamic>.from(task as Map)),
          )
          .toList(),
    );
  }
}
