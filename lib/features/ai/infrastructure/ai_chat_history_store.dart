import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage/storage_provider.dart';
import '../domain/ai_chat_message.dart';

final aiChatHistoryStoreProvider = Provider<AiChatHistoryStore?>((ref) {
  final storage = ref.watch(focusDayStorageProvider);
  return storage == null ? null : AiChatHistoryStore(storage.preferences);
});

class AiHistorySnapshot {
  const AiHistorySnapshot(this.messages, {this.invalid = false});
  final List<AiChatMessage> messages;
  final bool invalid;
}

class AiChatHistoryStore {
  AiChatHistoryStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'focusday.local.assistantHistory.v1';
  static const maxMessages = 100;
  Future<void> _writes = Future.value();

  AiHistorySnapshot load() {
    try {
      final raw = preferences.getString(key);
      if (raw == null) return const AiHistorySnapshot([]);
      if (raw.length > 4000000) throw const FormatException();
      final value = jsonDecode(raw);
      if (value is! Map ||
          value['version'] != 1 ||
          value.keys.any((k) => k != 'version' && k != 'messages') ||
          value['messages'] is! List ||
          (value['messages'] as List).length > maxMessages) {
        throw const FormatException();
      }
      final ids = <String>{};
      final messages = <AiChatMessage>[];
      for (final entry in value['messages'] as List) {
        if (entry is! Map) throw const FormatException();
        final message = AiChatMessage.fromJson(
          Map<String, Object?>.from(entry),
        );
        if (ids.add(message.id)) messages.add(message);
      }
      return AiHistorySnapshot(List.unmodifiable(messages));
    } catch (_) {
      // Do not log malformed content, which may contain private user text.
      return const AiHistorySnapshot([], invalid: true);
    }
  }

  Future<bool> save(List<AiChatMessage> messages) {
    // Serialize before queuing: later state changes cannot alter this snapshot.
    final recent = messages.skip(
      messages.length > maxMessages ? messages.length - maxMessages : 0,
    );
    try {
      final values = recent.map((message) => message.toJson()).toList();
      for (final value in values) {
        AiChatMessage.fromJson(value);
      }
      final encoded = jsonEncode({'version': 1, 'messages': values});
      if (encoded.length > 4000000) return Future.value(false);
      return _enqueue(() => preferences.setString(key, encoded));
    } catch (_) {
      return Future.value(false);
    }
  }

  Future<bool> clear() => _enqueue(() => preferences.remove(key));

  Future<bool> _enqueue(Future<bool> Function() operation) {
    final result = _writes.then((_) async {
      try {
        return await operation();
      } catch (_) {
        return false;
      }
    });
    _writes = result.then((_) {});
    return result;
  }
}
