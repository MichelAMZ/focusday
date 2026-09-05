// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FocusDay';

  @override
  String get todayTitle => 'Today';

  @override
  String get todaySubtitle => 'Focus on one project at a time.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get focusSectionTitle => 'Focus';

  @override
  String get completionSoundTitle => 'Focus completion sound';

  @override
  String get completionSoundSubtitle => 'Plays a sound when the timer reaches 00:00.';

  @override
  String get scheduledAlertsTitle => 'Scheduled project alerts';

  @override
  String get scheduledAlertsSubtitle => 'Shows an alert when a project reaches its scheduled start time.';

  @override
  String get miniBarLabel => 'Mini-bar';

  @override
  String get projectDueTitle => 'Project ready to start';

  @override
  String projectDueMessage(String projectName) {
    return 'It is time to start \"$projectName\".';
  }

  @override
  String get okButton => 'OK';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String notesTitle(String projectName) {
    return 'Notes — $projectName';
  }

  @override
  String get notesHint => 'Ideas, notes, decisions, links, things to check...';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get saveButton => 'Save';

  @override
  String get projectsOfDayTitle => 'Today\'s projects';

  @override
  String get addButton => 'Add';

  @override
  String get newProjectTitle => 'New project';

  @override
  String get projectNameLabel => 'Project name';

  @override
  String get durationMinutesLabel => 'Duration in minutes';

  @override
  String get task1Label => 'Task 1';

  @override
  String get task2Label => 'Task 2';

  @override
  String get editProjectTitle => 'Edit project';

  @override
  String get activeProjectDeleteError => 'The active project cannot be deleted.';

  @override
  String get deleteProjectTitle => 'Delete project?';

  @override
  String deleteProjectMessage(String projectName) {
    return 'The project \"$projectName\" will be deleted.';
  }

  @override
  String get deleteButton => 'Delete';

  @override
  String get changeProjectTitle => 'Switch project?';

  @override
  String changeProjectMessage(String activeProjectName, String projectName) {
    return '\"$activeProjectName\" is currently active.\n\nDo you want to switch to \"$projectName\"?';
  }

  @override
  String get changeProjectButton => 'Switch project';

  @override
  String get scheduleSoonLabel => 'Soon';

  @override
  String get scheduleDueLabel => 'Ready to start';

  @override
  String get startButton => 'Start';

  @override
  String get changePriorityTooltip => 'Change priority';

  @override
  String get actionsTooltip => 'Actions';

  @override
  String get editButton => 'Edit';

  @override
  String get reactivateButton => 'Reactivate';

  @override
  String get scheduleButton => 'Schedule';

  @override
  String get editScheduleButton => 'Edit schedule';

  @override
  String get clearScheduleButton => 'Remove schedule';

  @override
  String get notesMenuItem => 'Notes';

  @override
  String get deleteUnavailableLabel => 'Cannot delete';

  @override
  String get notesPanelTitle => 'Notes';

  @override
  String get editNotesTooltip => 'Edit notes';

  @override
  String get tasksTitle => 'Tasks';

  @override
  String get noTasksMessage => 'No tasks for this project.';

  @override
  String get addTaskTitle => 'Add task';

  @override
  String get taskLabel => 'Task';

  @override
  String get taskExampleHint => 'E.g. Run the tests';

  @override
  String get taskDetailsTitle => 'Task details';

  @override
  String get taskTitleLabel => 'Title';

  @override
  String get taskDescriptionLabel => 'Description';

  @override
  String get taskDescriptionHint => 'Add details about this task...';

  @override
  String get prepareButton => 'Prepare';

  @override
  String get pauseButton => 'Pause';

  @override
  String get finishButton => 'Finish';

  @override
  String get resumeButton => 'Resume';

  @override
  String get completedButton => 'Completed';

  @override
  String get timerStatusWaiting => 'WAITING';

  @override
  String get timerStatusReady => 'READY';

  @override
  String get timerStatusRunning => 'IN PROGRESS';

  @override
  String get timerStatusPaused => 'PAUSED';

  @override
  String get timerStatusCompleted => 'COMPLETED';

  @override
  String get timerCaptionPlannedDuration => 'planned duration';

  @override
  String get timerCaptionReady => 'ready to start';

  @override
  String get timerCaptionRemaining => 'remaining';

  @override
  String get timerCaptionPaused => 'paused';

  @override
  String get timerCaptionCompleted => 'session completed';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languagePreferenceTitle => 'Application language';

  @override
  String get languageAutomatic => 'Automatic';

  @override
  String get languageAutomaticSubtitle => 'Use the system language.';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get windowsStartupSectionTitle => 'Windows startup';

  @override
  String get windowsStartupTitle => 'Start FocusDay with Windows';

  @override
  String get windowsStartupSubtitle => 'Automatically launch FocusDay when you sign in to Windows.';

  @override
  String get miniBarNoProject => 'No project';

  @override
  String get miniBarRestoreTooltip => 'Restore FocusDay';

  @override
  String get miniBarCloseTooltip => 'Close FocusDay';
}
