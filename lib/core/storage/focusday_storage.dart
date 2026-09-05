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
}
