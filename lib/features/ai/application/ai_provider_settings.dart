import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage_provider.dart';
import '../../auth/application/auth_controller.dart';

// New providers can be added here without changing cloud settings.
// FocusDay V2: personal OpenAI API key configuration
enum AiProviderMode { disabled, chatgpt, personalOpenAi, focusday }

class AiProviderSettings {
  const AiProviderSettings({
    this.mode = AiProviderMode.focusday,
    this.keyConfigured = false,
  });
  final AiProviderMode mode;
  final bool keyConfigured;
}

// Secret is not part of observable/serializable Riverpod state.
class SessionAiKey {
  String? _key;
  String? _owner;
  void configure(String key, String owner) {
    _key = key;
    _owner = owner;
  }

  String? forOwner(String? owner) =>
      owner != null && owner == _owner ? _key : null;
  void clear() {
    _key = null;
    _owner = null;
  }

  @override
  String toString() => 'SessionAiKey([redacted])';
}

final sessionAiKeyProvider = Provider<SessionAiKey>((ref) {
  final vault = SessionAiKey();
  ref.onDispose(vault.clear);
  return vault;
});
final aiSessionOwnerProvider = Provider<String?>(
  (ref) => ref.watch(authStateChangesProvider).asData?.value?.uid,
);
final aiProviderSettingsProvider =
    NotifierProvider<AiProviderSettingsController, AiProviderSettings>(
      AiProviderSettingsController.new,
    );

class AiProviderSettingsController extends Notifier<AiProviderSettings> {
  Future<void> _writes = Future.value();
  bool _watchingOwner = false;
  @override
  AiProviderSettings build() {
    final saved = ref.read(focusDayStorageProvider)?.loadAiProviderMode();
    return AiProviderSettings(
      mode:
          AiProviderMode.values
              .where(
                (m) => m.name == saved && m != AiProviderMode.personalOpenAi,
              )
              .firstOrNull ??
          AiProviderMode.focusday,
    );
  }

  Future<void> setMode(AiProviderMode mode) {
    ref.read(sessionAiKeyProvider).clear();
    state = AiProviderSettings(mode: mode);
    final storage = ref.read(focusDayStorageProvider);
    _writes = _writes.catchError((Object _) {}).then((_) async {
      await storage?.saveAiProviderMode(mode.name);
    });
    return _writes;
  }

  bool configureKey(String value) {
    final key = value.trim();
    final owner = ref.read(aiSessionOwnerProvider);
    if (state.mode != AiProviderMode.personalOpenAi ||
        owner == null ||
        key.isEmpty ||
        key.length > 512 ||
        RegExp(r'\s').hasMatch(key)) {
      return false;
    }
    ref.read(sessionAiKeyProvider).configure(key, owner);
    state = AiProviderSettings(mode: state.mode, keyConfigured: true);
    // Installed only after configuration; no Firebase dependency for disabled/ChatGPT.
    if (!_watchingOwner) {
      _watchingOwner = true;
      ref.listen<String?>(aiSessionOwnerProvider, (previous, next) {
        if (previous != next) deleteKey();
      });
    }
    return true;
  }

  void deleteKey() {
    ref.read(sessionAiKeyProvider).clear();
    state = AiProviderSettings(mode: state.mode);
  }
}
