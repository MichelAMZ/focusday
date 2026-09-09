enum AiAssistantErrorCategory {
  unauthenticated,
  unavailable,
  timeout,
  rateLimited,
  invalidRequest,
  serverError,
}

class AiAssistantException implements Exception {
  const AiAssistantException(this.category, {this.statusCode});

  final AiAssistantErrorCategory category;
  final int? statusCode;
}

class AiAssistantTaskContext {
  const AiAssistantTaskContext({
    required this.title,
    required this.completed,
    this.localTaskId,
  });

  final String title;
  final bool completed;
  // Local-only metadata used by the fake gateway. Never serialized upstream.
  final String? localTaskId;

  Map<String, Object?> toJson() => {'title': title, 'completed': completed};
}

class AiAssistantProjectContext {
  const AiAssistantProjectContext({
    required this.name,
    required this.tasks,
    this.notes,
  });

  final String name;
  final List<AiAssistantTaskContext> tasks;
  final String? notes;

  Map<String, Object?> toJson() => {
    'name': name,
    'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
    if (notes != null) 'notes': notes,
  };
}

class AiAssistantContext {
  const AiAssistantContext({
    required this.language,
    required this.focusRemainingSeconds,
    this.activeProject,
  });

  final String language;
  final int focusRemainingSeconds;
  final AiAssistantProjectContext? activeProject;

  Map<String, Object?> toJson() => {
    'language': language,
    'focusRemainingSeconds': focusRemainingSeconds,
    if (activeProject != null) 'activeProject': activeProject!.toJson(),
  };
}

class AiRequest {
  const AiRequest({
    required this.message,
    required this.context,
    this.conversationId,
  });

  final String message;
  final String? conversationId;
  final AiAssistantContext context;

  Map<String, Object?> toJson() => {
    'message': message,
    if (conversationId != null) 'conversationId': conversationId,
    'context': context.toJson(),
  };
}

class AiResponseMetadata {
  const AiResponseMetadata({this.requestId});

  final String? requestId;
}

class AiResponse {
  const AiResponse({
    required this.text,
    this.conversationId,
    this.metadata = const AiResponseMetadata(),
    this.proposedActions = const [],
  });

  final String text;
  final String? conversationId;
  final AiResponseMetadata metadata;
  final List<AiProposedAction> proposedActions;

  factory AiResponse.fromJson(Map<String, Object?> json) {
    final text = json['text'];
    final conversationId = json['conversationId'];
    final metadata = json['metadata'];
    final rawActions = json['proposedActions'];
    if (text is! String || text.trim().isEmpty) {
      throw const AiAssistantException(AiAssistantErrorCategory.serverError);
    }
    if (conversationId != null && conversationId is! String) {
      throw const AiAssistantException(AiAssistantErrorCategory.serverError);
    }
    String? requestId;
    if (metadata != null) {
      if (metadata is! Map) {
        throw const AiAssistantException(AiAssistantErrorCategory.serverError);
      }
      final rawRequestId = metadata['requestId'];
      if (rawRequestId != null && rawRequestId is! String) {
        throw const AiAssistantException(AiAssistantErrorCategory.serverError);
      }
      requestId = rawRequestId as String?;
    }
    return AiResponse(
      text: text,
      conversationId: conversationId as String?,
      metadata: AiResponseMetadata(requestId: requestId),
      proposedActions: rawActions == null
          ? const []
          : _parseActions(rawActions),
    );
  }

  static List<AiProposedAction> _parseActions(Object raw) {
    if (raw is! List || raw.length > 10) {
      throw const AiAssistantException(AiAssistantErrorCategory.serverError);
    }
    return raw
        .map((value) {
          if (value is! Map) {
            throw const AiAssistantException(
              AiAssistantErrorCategory.serverError,
            );
          }
          return AiProposedAction.fromJson(Map<String, Object?>.from(value));
        })
        .toList(growable: false);
  }
}

enum AiProposedActionType {
  addTask,
  renameTask,
  completeTask,
  reopenTask,
  updateProjectNotes,
  setFocusDuration,
}

class AiProposedAction {
  const AiProposedAction({
    required this.type,
    this.title,
    this.description,
    this.taskId,
    this.newTitle,
    this.newNotes,
    this.durationMinutes,
  });

  final AiProposedActionType type;
  final String? title;
  final String? description;
  final String? taskId;
  final String? newTitle;
  final String? newNotes;
  final int? durationMinutes;

  factory AiProposedAction.fromJson(Map<String, Object?> json) {
    final typeName = json['type'];
    final type = AiProposedActionType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    if (type == null) {
      throw const AiAssistantException(AiAssistantErrorCategory.serverError);
    }
    final allowed = switch (type) {
      AiProposedActionType.addTask => {'type', 'title', 'description'},
      AiProposedActionType.renameTask => {'type', 'taskId', 'newTitle'},
      AiProposedActionType.completeTask ||
      AiProposedActionType.reopenTask => {'type', 'taskId'},
      AiProposedActionType.updateProjectNotes => {'type', 'newNotes'},
      AiProposedActionType.setFocusDuration => {'type', 'durationMinutes'},
    };
    if (json.keys.any((key) => !allowed.contains(key))) {
      throw const AiAssistantException(AiAssistantErrorCategory.serverError);
    }
    String? stringField(String name) {
      final value = json[name];
      if (value != null && value is! String) {
        throw const AiAssistantException(AiAssistantErrorCategory.serverError);
      }
      return value as String?;
    }

    int? intField(String name) {
      final value = json[name];
      if (value != null && value is! int) {
        throw const AiAssistantException(AiAssistantErrorCategory.serverError);
      }
      return value as int?;
    }

    return AiProposedAction(
      type: type,
      title: stringField('title'),
      description: stringField('description'),
      taskId: stringField('taskId'),
      newTitle: stringField('newTitle'),
      newNotes: stringField('newNotes'),
      durationMinutes: intField('durationMinutes'),
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (taskId != null) 'taskId': taskId,
    if (newTitle != null) 'newTitle': newTitle,
    if (newNotes != null) 'newNotes': newNotes,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
  };
}
