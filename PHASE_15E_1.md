# Phase 15E.1 — diagnostic avant HTTP

La configuration de compilation `FOCUSDAY_AI_BACKEND_URL` était absente du lancement/build documenté en phase 15E. `String.fromEnvironment` retournait une chaîne vide, puis `aiBackendUriProvider` retournait null. Le provider Riverpod construisait `UnavailableAiAssistantGateway`, dont `respond` levait immédiatement une erreur générique. Aucun token ni appel HTTP n'était alors demandé. Le statut « Configurée » décrivait uniquement la clé de session. Ce chemin est reproduit par un test du câblage réel Riverpod ; la configuration du navigateur de l'utilisateur n'a pas été inspectée.

## Chemin vérifié

Send/Retry → contrôleur → mode et statut de configuration → provider du gateway → validation de l'URL → création du gateway HTTP → currentUser et clé liée au compte → ID token Firebase → nouvelle vérification de la clé après l'attente → POST /api/ai/respond.

Le mode reste dans les préférences locales après navigation. La clé reste exclusivement dans le store de session, liée au compte ; un changement de compte ou de mode l'efface. Aucune récupération de clé serveur globale n'est ajoutée. Web et Windows utilisent le même câblage ; le Web nécessite aussi une origine CORS autorisée une fois l'appel HTTP atteint.

## Correction et retest local

Les configurations `.vscode/launch.json` fournissent explicitement l'URL locale pour Chrome et Windows. Pour Chrome, l'équivalent est :

```powershell
flutter run -d chrome --web-port=5000 --dart-define=FOCUSDAY_AI_BACKEND_URL=http://localhost:8080
```

Arrêter puis relancer complètement l'application : une variable d'environnement PowerShell ou un hot reload ne remplace pas un dart-define. Un build distribué doit aussi être reconstruit avec son URL backend explicite. Aucun fallback localhost implicite n'est ajouté. Le backend doit être démarré séparément sur le port choisi avec sa configuration existante ; l'origine Web doit être autorisée. Aucun serveur ni appel OpenAI réel n'a été lancé pendant cette correction.

URL absente/invalide : message UI dédié FR/EN. HTTPS requis hors loopback ; userinfo, query et fragment rejetés. Les diagnostics DEBUG sont uniquement des codes fixes : provider_not_configured, personal_key_missing, firebase_user_missing, firebase_token_failed, backend_url_missing, backend_url_invalid, gateway_not_created, http_request_failed, backend_response_error. Aucune valeur dynamique sensible n'est journalisée.

Retry réutilise la dernière requête sans ajouter de bulle utilisateur ; après succès il ne renvoie rien. Le test UI échouait avant correction avec deux bulles. Des tests HTTP simulés vérifient plusieurs retries, les préconditions, les erreurs et l'absence de fuite dans les diagnostics.

Firebase Auth, confirmation des actions, store=false et safety_identifier restent préservés. Aucun changement backend pour cette phase. Aucun secret persisté, commit, push ou déploiement.

## Validation

- Flutter : 219 tests passent ; analyse sans problème.
- Backend : 137 tests passent ; build et lint passent.
- npm audit : 6 vulnérabilités modérées existantes dans la chaîne uuid / Storage / firebase-admin ; aucune dépendance modifiée dans cette phase.

## Fichiers de cette phase

- .vscode/launch.json
- PHASE_15E_1.md
- lib/features/ai/application/ai_diagnostics.dart
- lib/features/ai/application/ai_assistant_controller.dart
- lib/features/ai/domain/ai_assistant_models.dart
- lib/features/ai/infrastructure/http_ai_assistant_gateway.dart
- lib/features/ai/presentation/ai_assistant_panel.dart
- lib/l10n/app_en.arb et app_fr.arb
- lib/l10n/app_localizations.dart, app_localizations_en.dart et app_localizations_fr.dart
- test/features/ai/ai_gateway_wiring_test.dart
- test/features/ai/ai_assistant_ui_test.dart
- test/features/ai/ai_assistant_architecture_test.dart
- test/features/ai/http_ai_assistant_gateway_test.dart

Les modifications antérieures de 15D/15E sont conservées.
