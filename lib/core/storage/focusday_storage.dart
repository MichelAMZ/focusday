import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/projects/domain/focus_project.dart';
import '../../features/today/application/focus_timer_state.dart';

class FocusDayStorage {
  FocusDayStorage(this.preferences);

  final SharedPreferences preferences;

  static const _projectsKey = 'focusday.projects.v1';
  static const _timerKey = 'focusday.timer.v1';
  static const _completionSoundEnabledKey =
      'focusday.settings.completionSoundEnabled';
  static const _scheduledProjectAlertsEnabledKey =
      'focusday.settings.scheduledProjectAlertsEnabled';
  static const _languagePreferenceKey = 'focusday.settings.languagePreference';
  static const _projectsUpdatedAtKey = 'focusday.sync.projectsUpdatedAt';
  static const _lastSyncAtKey = 'focusday.sync.lastSyncAt';
  static const _projectsDirtyKey = 'focusday.sync.projectsDirty';
  static const _projectsRevisionKey = 'focusday.sync.projectsRevision';
  static const _lastSyncedProjectsRevisionKey =
      'focusday.sync.lastSyncedProjectsRevision';
  static const _settingsRevisionKey = 'focusday.sync.settingsRevision';
  static const _lastSyncedSettingsRevisionKey =
      'focusday.sync.lastSyncedSettingsRevision';
  static const _settingsLastSyncAtKey = 'focusday.sync.settingsLastSyncAt';
  static const _focusRevisionKey = 'focusday.sync.focusRevision';
  static const _lastSyncedFocusRevisionKey =
      'focusday.sync.lastSyncedFocusRevision';
  static const _focusLastSyncAtKey = 'focusday.sync.focusLastSyncAt';
  static const _syncOwnerUidKey = 'focusday.sync.ownerUid';
  static const _projectsGenerationKey = 'focusday.sync.projectsGeneration';
  static const _settingsGenerationKey = 'focusday.sync.settingsGeneration';
  static const _focusGenerationKey = 'focusday.sync.focusGeneration';

  List<FocusProject>? loadProjects() {
    final raw = preferences.getString(_projectsKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return null;
      }

      return decoded
          .map(
            (item) =>
                FocusProject.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProjects(List<FocusProject> projects) async {
    final encoded = jsonEncode(
      projects.map((project) => project.toJson()).toList(),
    );

    await preferences.setString(_projectsKey, encoded);
  }

  Future<void> clearProjects() async {
    await preferences.remove(_projectsKey);
  }

  FocusTimerState? loadTimer() {
    final raw = preferences.getString(_timerKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return null;
      }

      return FocusTimerState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTimer(FocusTimerState timer) async {
    final encoded = jsonEncode(timer.toJson());

    await preferences.setString(_timerKey, encoded);
  }

  Future<void> clearTimer() async {
    await preferences.remove(_timerKey);
  }

  bool loadCompletionSoundEnabled() {
    return preferences.getBool(_completionSoundEnabledKey) ?? true;
  }

  Future<void> saveCompletionSoundEnabled(bool enabled) async {
    await preferences.setBool(_completionSoundEnabledKey, enabled);
  }

  bool loadScheduledProjectAlertsEnabled() {
    return preferences.getBool(_scheduledProjectAlertsEnabledKey) ?? true;
  }

  Future<void> saveScheduledProjectAlertsEnabled(bool enabled) async {
    await preferences.setBool(_scheduledProjectAlertsEnabledKey, enabled);
  }

  String? loadLanguagePreference() {
    return preferences.getString(_languagePreferenceKey);
  }

  Future<void> saveLanguagePreference(String preference) async {
    await preferences.setString(_languagePreferenceKey, preference);
  }

  DateTime? loadProjectsUpdatedAt() {
    final raw = preferences.getString(_projectsUpdatedAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> saveProjectsUpdatedAt(DateTime value) async {
    await preferences.setString(
      _projectsUpdatedAtKey,
      value.toUtc().toIso8601String(),
    );
  }

  DateTime? loadLastSyncAt() {
    final raw = preferences.getString(_lastSyncAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> saveLastSyncAt(DateTime value) async {
    await preferences.setString(
      _lastSyncAtKey,
      value.toUtc().toIso8601String(),
    );
  }

  bool loadProjectsDirty() {
    return preferences.getBool(_projectsDirtyKey) ?? false;
  }

  Future<void> saveProjectsDirty(bool value) async {
    await preferences.setBool(_projectsDirtyKey, value);
  }

  int loadProjectsRevision() {
    return preferences.getInt(_projectsRevisionKey) ?? 0;
  }

  int loadLastSyncedProjectsRevision() {
    return preferences.getInt(_lastSyncedProjectsRevisionKey) ?? 0;
  }

  Future<void> saveLastSyncedProjectsRevision(int value) async {
    await preferences.setInt(_lastSyncedProjectsRevisionKey, value);
  }

  Future<int> incrementProjectsRevision() async {
    final nextRevision = loadProjectsRevision() + 1;
    await preferences.setInt(_projectsRevisionKey, nextRevision);
    return nextRevision;
  }

  int loadSettingsRevision() => preferences.getInt(_settingsRevisionKey) ?? 0;
  int loadLastSyncedSettingsRevision() =>
      preferences.getInt(_lastSyncedSettingsRevisionKey) ?? 0;
  DateTime? loadSettingsLastSyncAt() =>
      _loadUtcDateTime(_settingsLastSyncAtKey);
  Future<int> incrementSettingsRevision() =>
      _incrementRevision(_settingsRevisionKey, loadSettingsRevision());
  Future<void> saveLastSyncedSettingsRevision(int value) =>
      preferences.setInt(_lastSyncedSettingsRevisionKey, value);
  Future<void> saveSettingsLastSyncAt(DateTime value) =>
      _saveUtcDateTime(_settingsLastSyncAtKey, value);

  int loadFocusRevision() => preferences.getInt(_focusRevisionKey) ?? 0;
  int loadLastSyncedFocusRevision() =>
      preferences.getInt(_lastSyncedFocusRevisionKey) ?? 0;
  DateTime? loadFocusLastSyncAt() => _loadUtcDateTime(_focusLastSyncAtKey);
  Future<int> incrementFocusRevision() =>
      _incrementRevision(_focusRevisionKey, loadFocusRevision());
  Future<void> saveLastSyncedFocusRevision(int value) =>
      preferences.setInt(_lastSyncedFocusRevisionKey, value);
  Future<void> saveFocusLastSyncAt(DateTime value) =>
      _saveUtcDateTime(_focusLastSyncAtKey, value);

  String? loadSyncOwnerUid() => preferences.getString(_syncOwnerUidKey);
  Future<void> saveSyncOwnerUid(String uid) =>
      preferences.setString(_syncOwnerUidKey, uid);

  /// Associates future synchronization metadata with [uid] without deleting
  /// any local user data. Domain baselines from another account are discarded.
  Future<void> prepareSyncOwner(String uid) async {
    if (loadSyncOwnerUid() == uid) return;
    await preferences.remove(_projectsUpdatedAtKey);
    await preferences.remove(_lastSyncAtKey);
    await preferences.remove(_settingsLastSyncAtKey);
    await preferences.remove(_focusLastSyncAtKey);
    await preferences.remove(_projectsGenerationKey);
    await preferences.remove(_settingsGenerationKey);
    await preferences.remove(_focusGenerationKey);
    await saveLastSyncedProjectsRevision(loadProjectsRevision());
    await saveLastSyncedSettingsRevision(loadSettingsRevision());
    await saveLastSyncedFocusRevision(loadFocusRevision());
    await saveSyncOwnerUid(uid);
  }

  Future<bool> establishProjectsSyncBaseline({
    required String uid,
    required int synchronizedRevision,
    DateTime? serverLastSyncAt,
    int? cloudGeneration,
  }) async {
    if (serverLastSyncAt == null && cloudGeneration == null) return false;
    if (loadProjectsRevision() != synchronizedRevision) return false;

    await prepareSyncOwner(uid);
    if (loadProjectsRevision() != synchronizedRevision) return false;

    if (serverLastSyncAt != null) {
      await saveLastSyncAt(serverLastSyncAt);
    }
    await saveLastSyncedProjectsRevision(synchronizedRevision);
    if (cloudGeneration != null) {
      await saveProjectsGeneration(cloudGeneration);
    }
    if (loadProjectsRevision() != synchronizedRevision) return false;

    if (serverLastSyncAt != null) {
      await saveProjectsUpdatedAt(serverLastSyncAt);
    }
    await saveProjectsDirty(false);
    return loadSyncOwnerUid() == uid &&
        loadProjectsRevision() == synchronizedRevision;
  }

  int? loadProjectsGeneration() => preferences.getInt(_projectsGenerationKey);
  int? loadSettingsGeneration() => preferences.getInt(_settingsGenerationKey);
  int? loadFocusGeneration() => preferences.getInt(_focusGenerationKey);
  Future<void> saveProjectsGeneration(int value) =>
      preferences.setInt(_projectsGenerationKey, value);
  Future<void> saveSettingsGeneration(int value) =>
      preferences.setInt(_settingsGenerationKey, value);
  Future<void> saveFocusGeneration(int value) =>
      preferences.setInt(_focusGenerationKey, value);

  DateTime? _loadUtcDateTime(String key) {
    final raw = preferences.getString(key);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _saveUtcDateTime(String key, DateTime value) =>
      preferences.setString(key, value.toUtc().toIso8601String());

  Future<int> _incrementRevision(String key, int current) async {
    final next = current + 1;
    await preferences.setInt(key, next);
    return next;
  }
}
