import 'focus_task.dart';

enum FocusProjectStatus { waiting, active, paused, completed }

class FocusProject {
  const FocusProject({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.tasks,
    this.status = FocusProjectStatus.waiting,
    this.scheduledAt,
    this.notes = '',
  });

  final String id;
  final String name;
  final int durationMinutes;
  final List<FocusTask> tasks;
  final FocusProjectStatus status;
  final DateTime? scheduledAt;
  final String notes;

  FocusProject copyWith({
    String? id,
    String? name,
    int? durationMinutes,
    List<FocusTask>? tasks,
    FocusProjectStatus? status,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    String? notes,
  }) {
    return FocusProject(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tasks: tasks ?? this.tasks,
      status: status ?? this.status,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationMinutes': durationMinutes,
      'status': status.name,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'notes': notes,
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

    final scheduledAtRaw = json['scheduledAt'] as String?;

    return FocusProject(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: json['durationMinutes'] as int,
      status: status,
      scheduledAt: scheduledAtRaw == null
          ? null
          : DateTime.tryParse(scheduledAtRaw),
      notes: json['notes'] as String? ?? '',
      tasks: rawTasks
          .map(
            (task) =>
                FocusTask.fromJson(Map<String, dynamic>.from(task as Map)),
          )
          .toList(),
    );
  }
}
