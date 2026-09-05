import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FocusDay'**
  String get appTitle;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @todaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Focus on one project at a time.'**
  String get todaySubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @focusSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focusSectionTitle;

  /// No description provided for @completionSoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus completion sound'**
  String get completionSoundTitle;

  /// No description provided for @completionSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plays a sound when the timer reaches 00:00.'**
  String get completionSoundSubtitle;

  /// No description provided for @scheduledAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled project alerts'**
  String get scheduledAlertsTitle;

  /// No description provided for @scheduledAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows an alert when a project reaches its scheduled start time.'**
  String get scheduledAlertsSubtitle;

  /// No description provided for @miniBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Mini-bar'**
  String get miniBarLabel;

  /// No description provided for @projectDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Project ready to start'**
  String get projectDueTitle;

  /// No description provided for @projectDueMessage.
  ///
  /// In en, this message translates to:
  /// **'It is time to start \"{projectName}\".'**
  String projectDueMessage(String projectName);

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes — {projectName}'**
  String notesTitle(String projectName);

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Ideas, notes, decisions, links, things to check...'**
  String get notesHint;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @projectsOfDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s projects'**
  String get projectsOfDayTitle;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @newProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProjectTitle;

  /// No description provided for @projectNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectNameLabel;

  /// No description provided for @durationMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration in minutes'**
  String get durationMinutesLabel;

  /// No description provided for @task1Label.
  ///
  /// In en, this message translates to:
  /// **'Task 1'**
  String get task1Label;

  /// No description provided for @task2Label.
  ///
  /// In en, this message translates to:
  /// **'Task 2'**
  String get task2Label;

  /// No description provided for @editProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit project'**
  String get editProjectTitle;

  /// No description provided for @activeProjectDeleteError.
  ///
  /// In en, this message translates to:
  /// **'The active project cannot be deleted.'**
  String get activeProjectDeleteError;

  /// No description provided for @deleteProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get deleteProjectTitle;

  /// No description provided for @deleteProjectMessage.
  ///
  /// In en, this message translates to:
  /// **'The project \"{projectName}\" will be deleted.'**
  String deleteProjectMessage(String projectName);

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @changeProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch project?'**
  String get changeProjectTitle;

  /// No description provided for @changeProjectMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{activeProjectName}\" is currently active.\n\nDo you want to switch to \"{projectName}\"?'**
  String changeProjectMessage(String activeProjectName, String projectName);

  /// No description provided for @changeProjectButton.
  ///
  /// In en, this message translates to:
  /// **'Switch project'**
  String get changeProjectButton;

  /// No description provided for @scheduleSoonLabel.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get scheduleSoonLabel;

  /// No description provided for @scheduleDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready to start'**
  String get scheduleDueLabel;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startButton;

  /// No description provided for @changePriorityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change priority'**
  String get changePriorityTooltip;

  /// No description provided for @actionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsTooltip;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @reactivateButton.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get reactivateButton;

  /// No description provided for @scheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleButton;

  /// No description provided for @editScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Edit schedule'**
  String get editScheduleButton;

  /// No description provided for @clearScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Remove schedule'**
  String get clearScheduleButton;

  /// No description provided for @notesMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesMenuItem;

  /// No description provided for @deleteUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete'**
  String get deleteUnavailableLabel;

  /// No description provided for @notesPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesPanelTitle;

  /// No description provided for @editNotesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit notes'**
  String get editNotesTooltip;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// No description provided for @noTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'No tasks for this project.'**
  String get noTasksMessage;

  /// No description provided for @addTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTaskTitle;

  /// No description provided for @taskLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskLabel;

  /// No description provided for @taskExampleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Run the tests'**
  String get taskExampleHint;

  /// No description provided for @taskDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetailsTitle;

  /// No description provided for @taskTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get taskTitleLabel;

  /// No description provided for @taskDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskDescriptionLabel;

  /// No description provided for @taskDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add details about this task...'**
  String get taskDescriptionHint;

  /// No description provided for @prepareButton.
  ///
  /// In en, this message translates to:
  /// **'Prepare'**
  String get prepareButton;

  /// No description provided for @pauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseButton;

  /// No description provided for @finishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishButton;

  /// No description provided for @resumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeButton;

  /// No description provided for @completedButton.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedButton;

  /// No description provided for @timerStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get timerStatusWaiting;

  /// No description provided for @timerStatusReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get timerStatusReady;

  /// No description provided for @timerStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get timerStatusRunning;

  /// No description provided for @timerStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get timerStatusPaused;

  /// No description provided for @timerStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get timerStatusCompleted;

  /// No description provided for @timerCaptionPlannedDuration.
  ///
  /// In en, this message translates to:
  /// **'planned duration'**
  String get timerCaptionPlannedDuration;

  /// No description provided for @timerCaptionReady.
  ///
  /// In en, this message translates to:
  /// **'ready to start'**
  String get timerCaptionReady;

  /// No description provided for @timerCaptionRemaining.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get timerCaptionRemaining;

  /// No description provided for @timerCaptionPaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get timerCaptionPaused;

  /// No description provided for @timerCaptionCompleted.
  ///
  /// In en, this message translates to:
  /// **'session completed'**
  String get timerCaptionCompleted;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @languagePreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Application language'**
  String get languagePreferenceTitle;

  /// No description provided for @languageAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get languageAutomatic;

  /// No description provided for @languageAutomaticSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the system language.'**
  String get languageAutomaticSubtitle;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
