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
  const AiAssistantTaskContext({required this.title, required this.completed});

  final String title;
  final bool completed;

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
  });

  final String text;
  final String? conversationId;
  final AiResponseMetadata metadata;

  factory AiResponse.fromJson(Map<String, Object?> json) {
    final text = json['text'];
    final conversationId = json['conversationId'];
    final metadata = json['metadata'];
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
    );
  }
}
