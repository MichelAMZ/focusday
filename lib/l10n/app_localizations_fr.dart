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
  String get completionSoundSubtitle =>
      'Joue un son lorsque le minuteur atteint 00:00.';

  @override
  String get scheduledAlertsTitle => 'Alertes des projets planifiés';

  @override
  String get scheduledAlertsSubtitle =>
      'Affiche une alerte lorsqu’un projet atteint son heure de démarrage.';

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
  String get notesHint =>
      'Idées, remarques, décisions, liens, points à vérifier...';

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
  String get activeProjectDeleteError =>
      'Impossible de supprimer le projet actif.';

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

  @override
  String get windowsStartupSectionTitle => 'Démarrage Windows';

  @override
  String get windowsStartupTitle => 'Démarrer FocusDay avec Windows';

  @override
  String get windowsStartupSubtitle =>
      'Lancer automatiquement FocusDay à l’ouverture de votre session Windows.';

  @override
  String get miniBarNoProject => 'Aucun projet';

  @override
  String get miniBarRestoreTooltip => 'Restaurer FocusDay';

  @override
  String get miniBarCloseTooltip => 'Fermer FocusDay';

  @override
  String get syncInProgress => 'Synchronisation…';

  @override
  String get syncComplete => 'Synchronisé.';

  @override
  String get syncConflict =>
      'Conflit local/cloud : choisissez une version dans Compte & Cloud.';

  @override
  String get syncFirstRequired =>
      'Première synchronisation : choisissez sauvegarder ou restaurer.';

  @override
  String get syncPending =>
      'Une modification locale récente reste à synchroniser.';

  @override
  String get syncPendingOffline =>
      'Synchronisation en attente. Vous êtes peut-être hors ligne.';

  @override
  String get syncError => 'Synchronisation momentanément indisponible.';

  @override
  String get syncChoose => 'Choisir';

  @override
  String get syncRetry => 'Réessayer';

  @override
  String get syncResolveAction => 'Résoudre les conflits de synchronisation';

  @override
  String syncResolveTitle(String domain) {
    return 'Résoudre le conflit $domain';
  }

  @override
  String get syncResolveMessage =>
      'Choisissez la version qui doit devenir la version synchronisée.';

  @override
  String get syncKeepLocal => 'Garder mes données locales';

  @override
  String get syncUseCloud => 'Utiliser les données du cloud';

  @override
  String get syncNoConflict => 'Aucun conflit de synchronisation détecté.';

  @override
  String get syncResolutionFailed =>
      'La résolution a échoué. Aucune baseline n’a été modifiée.';

  @override
  String get syncDomainProjects => 'projets';

  @override
  String get syncDomainSettings => 'réglages';

  @override
  String get syncDomainFocus => 'minuteur';

  @override
  String get authOrSeparator => 'ou';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get googleSignInLoading => 'Connexion en cours…';

  @override
  String get googleSignInCancelled => 'Connexion Google annulée.';

  @override
  String get googleSignInFailed => 'Impossible de se connecter avec Google.';

  @override
  String get googleAccountCollision =>
      'Un compte existe déjà avec une autre méthode de connexion.';

  @override
  String get googleNetworkError =>
      'Réseau indisponible. Vérifiez votre connexion et réessayez.';

  @override
  String get googlePopupBlocked =>
      'La fenêtre de connexion Google a été bloquée par le navigateur.';

  @override
  String get googleSignInUnavailable =>
      'La connexion Google n’est pas disponible.';

  @override
  String get googleTooManyRequests =>
      'Trop de tentatives. Réessayez plus tard.';

  @override
  String get aiAssistantTitle => 'Assistant FocusDay';

  @override
  String get aiAssistantTooltip => 'Ouvrir l’assistant';

  @override
  String get aiAssistantEmptyTitle => 'Que voulez-vous faire maintenant ?';

  @override
  String get aiAssistantContext => 'Contexte : projet actif';

  @override
  String aiAssistantContextProject(String projectName) {
    return 'Contexte : $projectName';
  }

  @override
  String get aiAssistantContextNone => 'Contexte : aucun projet actif';

  @override
  String get aiSuggestionNext => 'Quelle est ma prochaine action ?';

  @override
  String get aiSuggestionBreakDown => 'Aide-moi à découper la tâche actuelle';

  @override
  String get aiSuggestionPrioritize => 'Que dois-je prioriser ?';

  @override
  String get aiSuggestionSummary => 'Résume mon projet actif';

  @override
  String get aiInputHint => 'Demandez un conseil…';

  @override
  String get aiSend => 'Envoyer';

  @override
  String get aiSending => 'Réflexion en cours…';

  @override
  String get aiRetry => 'Réessayer';

  @override
  String get aiErrorUnauthenticated =>
      'Connectez-vous pour utiliser l’assistant.';

  @override
  String get aiErrorUnavailable =>
      'L’assistant est momentanément indisponible.';

  @override
  String get aiErrorTimeout => 'La réponse prend trop de temps. Réessayez.';

  @override
  String get aiErrorRateLimited => 'Trop de demandes. Réessayez plus tard.';

  @override
  String get aiErrorInvalidRequest => 'Cette demande ne peut pas être envoyée.';

  @override
  String get aiErrorServer => 'Une erreur est survenue. Réessayez.';

  @override
  String get aiProposalTitle => 'Proposition';

  @override
  String aiProposalProject(String projectName) {
    return 'Projet : $projectName';
  }

  @override
  String get aiProposalAddTask => 'Ajouter une tâche';

  @override
  String aiProposalAddTasks(int count) {
    return 'Ajouter $count tâches';
  }

  @override
  String get aiProposalRenameTask => 'Renommer une tâche';

  @override
  String get aiProposalCompleteTask => 'Marquer comme terminée';

  @override
  String get aiProposalReopenTask => 'Réouvrir la tâche';

  @override
  String get aiProposalUpdateNotes => 'Modifier les notes';

  @override
  String get aiProposalFocusDuration => 'Modifier la durée de focus';

  @override
  String get aiProposalBefore => 'Avant';

  @override
  String get aiProposalAfter => 'Après';

  @override
  String get aiProposalReject => 'Refuser';

  @override
  String get aiProposalConfirm => 'Confirmer';

  @override
  String get aiProposalAdd => 'Ajouter';

  @override
  String get aiProposalApplied => 'Proposition appliquée';

  @override
  String get aiProposalRejected => 'Proposition refusée';

  @override
  String get aiProposalExpired => 'Cette proposition n\'est plus applicable.';

  @override
  String get aiProposalInvalid => 'Action invalide';

  @override
  String get aiProposalMinutes => 'min';
}
