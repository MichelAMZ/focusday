enum AiChatRole { user, assistant }

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.projectId,
    this.projectName,
  });

  final String id;
  final AiChatRole role;
  final String text;
  final DateTime createdAt;
  final String? projectId;
  final String? projectName;

  // Explicit allowlist: never serialize controller, request or proposal state.
  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (projectId != null) 'projectId': projectId,
    if (projectName != null) 'projectName': projectName,
  };

  factory AiChatMessage.fromJson(Map<String, Object?> json) {
    const allowed = {
      'id',
      'role',
      'text',
      'createdAt',
      'projectId',
      'projectName',
    };
    if (json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Invalid history fields');
    }
    String text(String key, int max) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > max) {
        throw const FormatException('Invalid history value');
      }
      return value;
    }

    final role = AiChatRole.values
        .where((r) => r.name == json['role'])
        .firstOrNull;
    final date = DateTime.tryParse(text('createdAt', 40));
    if (role == null || date == null) {
      throw const FormatException('Invalid history metadata');
    }
    return AiChatMessage(
      id: text('id', 200),
      role: role,
      text: text('text', 20000),
      createdAt: date.toUtc(),
      projectId: json['projectId'] == null ? null : text('projectId', 200),
      projectName: json['projectName'] == null
          ? null
          : text('projectName', 1000),
    );
  }
}
