// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FocusDay';

  @override
  String get todayTitle => 'Aujourd’hui';

  @override
  String get todaySubtitle => 'Concentre-toi sur un seul projet à la fois.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get focusSectionTitle => 'Focus';

  @override
  String get completionSoundTitle => 'Son de fin de focus';

  @override
  String get completionSoundSubtitle => 'Joue un son lorsque le minuteur atteint 00:00.';

  @override
  String get scheduledAlertsTitle => 'Alertes des projets planifiés';

  @override
  String get scheduledAlertsSubtitle => 'Affiche une alerte lorsqu’un projet atteint son heure de démarrage.';

  @override
  String get miniBarLabel => 'Mini-bar';

  @override
  String get projectDueTitle => 'Projet à démarrer';

  @override
  String projectDueMessage(String projectName) {
    return 'Il est temps de démarrer \"$projectName\".';
  }

  @override
  String get okButton => 'OK';

  @override
  String get settingsTooltip => 'Paramètres';

  @override
  String notesTitle(String projectName) {
    return 'Notes — $projectName';
  }

  @override
  String get notesHint => 'Idées, remarques, décisions, liens, points à vérifier...';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get saveButton => 'Enregistrer';

  @override
  String get projectsOfDayTitle => 'Projets du jour';

  @override
  String get addButton => 'Ajouter';

  @override
  String get newProjectTitle => 'Nouveau projet';

  @override
  String get projectNameLabel => 'Nom du projet';

  @override
  String get durationMinutesLabel => 'Durée en minutes';

  @override
  String get task1Label => 'Tâche 1';

  @override
  String get task2Label => 'Tâche 2';

  @override
  String get editProjectTitle => 'Modifier le projet';

  @override
  String get activeProjectDeleteError => 'Impossible de supprimer le projet actif.';

  @override
  String get deleteProjectTitle => 'Supprimer le projet ?';

  @override
  String deleteProjectMessage(String projectName) {
    return 'Le projet \"$projectName\" sera supprimé.';
  }

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get changeProjectTitle => 'Changer de projet ?';

  @override
  String changeProjectMessage(String activeProjectName, String projectName) {
    return '\"$activeProjectName\" est actuellement actif.\n\nVoulez-vous passer à \"$projectName\" ?';
  }

  @override
  String get changeProjectButton => 'Changer de projet';

  @override
  String get scheduleSoonLabel => 'Bientôt';

  @override
  String get scheduleDueLabel => 'À démarrer';

  @override
  String get startButton => 'Démarrer';

  @override
  String get changePriorityTooltip => 'Modifier la priorité';

  @override
  String get actionsTooltip => 'Actions';

  @override
  String get editButton => 'Modifier';

  @override
  String get reactivateButton => 'Réactiver';

  @override
  String get scheduleButton => 'Programmer';

  @override
  String get editScheduleButton => 'Modifier la programmation';

  @override
  String get clearScheduleButton => 'Supprimer la programmation';

  @override
  String get notesMenuItem => 'Notes';

  @override
  String get deleteUnavailableLabel => 'Suppression impossible';

  @override
  String get notesPanelTitle => 'Notes';

  @override
  String get editNotesTooltip => 'Modifier les notes';

  @override
  String get tasksTitle => 'Tâches';

  @override
  String get noTasksMessage => 'Aucune tâche pour ce projet.';

  @override
  String get addTaskTitle => 'Ajouter une tâche';

  @override
  String get taskLabel => 'Tâche';

  @override
  String get taskExampleHint => 'Ex. Lancer les tests';

  @override
  String get taskDetailsTitle => 'Détails de la tâche';

  @override
  String get taskTitleLabel => 'Titre';

  @override
  String get taskDescriptionLabel => 'Description';

  @override
  String get taskDescriptionHint => 'Ajouter les détails de cette tâche...';

  @override
  String get prepareButton => 'Préparer';

  @override
  String get pauseButton => 'Pause';

  @override
  String get finishButton => 'Terminer';

  @override
  String get resumeButton => 'Reprendre';

  @override
  String get completedButton => 'Terminé';

  @override
  String get timerStatusWaiting => 'EN ATTENTE';

  @override
  String get timerStatusReady => 'PRÊT';

  @override
  String get timerStatusRunning => 'EN COURS';

  @override
  String get timerStatusPaused => 'EN PAUSE';

  @override
  String get timerStatusCompleted => 'TERMINÉ';

  @override
  String get timerCaptionPlannedDuration => 'durée prévue';

  @override
  String get timerCaptionReady => 'prêt à démarrer';

  @override
  String get timerCaptionRemaining => 'restantes';

  @override
  String get timerCaptionPaused => 'en pause';

  @override
  String get timerCaptionCompleted => 'session terminée';

  @override
  String get languageSectionTitle => 'Langue';

  @override
  String get languagePreferenceTitle => 'Langue de l’application';

  @override
  String get languageAutomatic => 'Automatique';

  @override
  String get languageAutomaticSubtitle => 'Utiliser la langue du système.';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';
}
