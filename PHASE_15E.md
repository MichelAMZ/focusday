# FocusDay 15E — sélecteur de fournisseur IA

## Audit et décisions V1

Le worktree de 15D a été conservé. Le gateway Flutter par défaut était simulé ;
le contexte actif, les propositions, leur validation locale et leur confirmation
étaient déjà séparés. Les préférences générales sont synchronisées : le choix IA
utilise donc une clé indépendante, focusday.local.aiProvider, sans révision cloud.
Le projet n'avait pas de stockage sécurisé OS. Aucun package ajouté : Web et
Windows utilisent uniquement une clé en mémoire de session. Le futur stockage
OS Windows reste une évolution séparée.

Trois modes : disabled (défaut), chatgpt, personalOpenAi. Aucun mode payant
FocusDay activé. L'enum, les gateways et la factory de service permettent une
extension ultérieure sans ajouter de secrets aux paramètres synchronisés.

## Parcours UI

Paramètres → Assistant IA : Désactivé / ChatGPT / Ma clé OpenAI API.

- Désactivé : aucun gateway appelé, aucun composeur ou proposition.
- ChatGPT : aperçu humain du seul contexte actif, puis copie explicite vers
  le presse-papiers. Aucune ouverture automatique, URL de partage, intégration
  de compte, manipulation de cookie, scraping ou retour automatique d'actions.
- Ma clé : saisie masquée, Configurer, Supprimer la clé et statut. Connexion
  Firebase requise pour configurer une clé liée au compte. Le champ est effacé
  après configuration. La conversation et la confirmation 15D restent utilisées.
  Quota/facturation/débit et clé/accès refusé ont des messages FR/EN sans erreur brute.

Le choix seul survit au redémarrage. La clé est absente de SharedPreferences,
Firestore, paramètres synchronisés et états observables de conversation.
Elle n'est pas restaurée après F5 ou fermeture de l'application. La suppression,
le changement de mode et le changement de compte l'effacent du coffre de session.
Les chaînes Dart sont gérées par le GC : cela supprime les références applicatives,
sans promettre une remise à zéro physique instantanée de la mémoire.

Un changement de mode ou de clé vide la conversation et les propositions.
Un compteur de génération empêche une réponse tardive de recréer cet état.
Les propositions ne sont confirmables qu'en mode personnel configuré.
Les tests 15D de confirmation et revalidation locale restent exécutés.

## Contrat et sécurité du backend

POST /api/ai/respond :

- Authorization: Bearer <Firebase ID token>
- X-FocusDay-OpenAI-Key: <clé personnelle de cette requête>
- JSON existant augmenté uniquement de providerMode: personalOpenAi.

La clé ne fait pas partie du JSON du contexte, d'une URL ou d'une query string.
Firebase Auth, rate limiting et validation précèdent la factory personnelle.
Chaque requête crée un service/provider distinct, sans cache, variable globale
de clé ni fallback vers OPENAI_API_KEY. server.ts ne configure plus le service
global de l'ancien montage ; l'injection ai optionnelle reste disponible pour
les tests existants. Les modes inconnus/désactivés/ChatGPT sont rejetés par l'API.

Le HMAC safety_identifier utilise le secret serveur et l'UID vérifié. Le provider
reçoit le pseudonyme, jamais l'UID brut. store=false est imposé par la factory
personnelle, même si OPENAI_STORE était configuré autrement. Modèle et timeout
restent choisis côté serveur. SDK logLevel=off, retries désactivés. Aucune
capacité d'exécution backend ; parsing et validation stricte des actions conservés.

Les logs applicatifs contiennent seulement requestId local, durée et statut.
Les réponses portent Cache-Control: no-store. Les clés ne sont pas journalisées
par les tests ou le SDK. Une future infrastructure HTTP/APM/proxy devra également
exclure Authorization et X-FocusDay-OpenAI-Key de ses journaux et traces.

## Transport et test UI local

Le gateway personnel exige HTTPS, sauf http://localhost, http://127.0.0.1 et
http://[::1] pour le développement. Les redirections HTTP ne sont pas suivies.
L'identité courante est revérifiée après l'attente du token Firebase pour éviter
de transmettre une clé d'une autre session.

Le backend exige request.secure ou une connexion socket loopback avec un Host
localhost. Il ne fait pas confiance à un X-Forwarded-Proto envoyé arbitrairement.
Le serveur actuel écoute en HTTP local. Une mise en production derrière un proxy
TLS nécessitera une configuration explicite et restreinte du proxy de confiance
ou une terminaison TLS directement vérifiable par Express ; ce déploiement
n'est pas réalisé dans cette phase.

Les modes Désactivé et ChatGPT fonctionnent sans backend OpenAI.
Pour préparer le mode personnel local, le frontend reçoit seulement l'URL non
secrète du backend via --dart-define=FOCUSDAY_AI_BACKEND_URL=http://localhost:8080.
Le backend reçoit OPENAI_MODEL, OPENAI_TIMEOUT_MS et FOCUSDAY_AI_SAFETY_SECRET
dans son environnement ; il faut aussi les prérequis Firebase Auth habituels.
ALLOWED_ORIGINS doit correspondre à l'origine exacte du frontend.
Aucune clé personnelle dans les dart-defines, assets, fichiers de configuration
Flutter ou bundle. Aucun appel réel n'est nécessaire aux tests automatisés.

## Limites connues

- Pas de stockage sécurisé Windows persistant dans cette V1.
- Mémoire Web de session : pas de protection contre un navigateur compromis/XSS.
- L'allowlist exclut les champs techniques et les autres projets ; le texte libre
  des notes/tâches/messages peut contenir ce que l'utilisateur y a lui-même saisi.
  L'aperçu ChatGPT permet une revue avant copie.
- Aucun taskId envoyé au modèle ; limite 15D.2-B conservée et pas de migration
  du contrat d'actions dans cette phase.
- Les six alertes npm modérées 15D.2-A restent documentées et inchangées.
- L'accès réel au modèle, la facturation et la configuration Firebase/backend
  ne sont pas validés par des appels OpenAI dans cette phase.

## Fichiers de cette phase

- lib/core/storage/focusday_storage.dart
- lib/features/ai/application/ai_provider_settings.dart
- lib/features/ai/application/chatgpt_export.dart
- lib/features/ai/application/ai_assistant_controller.dart
- lib/features/ai/domain/ai_assistant_models.dart
- lib/features/ai/infrastructure/http_ai_assistant_gateway.dart
- lib/features/ai/presentation/ai_provider_settings_section.dart
- lib/features/ai/presentation/ai_assistant_panel.dart
- lib/features/settings/presentation/settings_page.dart
- lib/l10n/app_fr.arb, app_en.arb et les trois fichiers Dart générés
- server/src/app.ts, server/src/server.ts, server/src/validation.ts
- server/src/ai/personal_openai_service.ts
- server/src/ai/openai_responses_provider.ts
- server/test/personal_openai.test.ts, server/test/openai_responses_provider.test.ts
- test/features/ai/ai_provider_modes_test.dart
- test/features/ai/http_ai_assistant_gateway_test.dart
- test/features/ai/ai_assistant_ui_test.dart
- test/features/ai/ai_assistant_architecture_test.dart
- test/core/cloud/account_sync_executor_test.dart
- PHASE_15E.md

Les changements préexistants de .gitignore, des manifests/lock backend et des
fichiers de 15D.2 sont conservés. Aucun reset, restore, checkout, clean, commit,
push, déploiement ou changement de Firebase rules.

## Validation finale

- dart format lib test : exécuté.
- flutter analyze : PASS, aucun problème.
- flutter test : 205/205 PASS.
- flutter build web --release : PASS, build/web généré et ignoré.
- npm --prefix server test : 137/137 PASS.
- npm --prefix server run build : PASS.
- npm --prefix server run lint : PASS.
- npm --prefix server audit : six vulnérabilités modérées, code de sortie 1
  attendu ; aucune correction de dépendance effectuée.
- git diff --check : PASS.
- Scan de signatures de clés OpenAI et clés privées sur fichiers suivis et
  nouveaux fichiers non ignorés : aucun résultat. Aucun .env réel présent.
  Aucun node_modules, dist, build ou .env réel suivi. Les fixtures de tests
  contiennent exclusivement des valeurs factices.
- Aucun appel OpenAI réel et aucune vraie clé utilisée.
