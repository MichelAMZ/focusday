# Premier appel local read-only

## Configuration par l'utilisateur uniquement

Codex ne crée ni ne renseigne de clé ou de secret. Aucun .env réel n'a été créé.
Le chargeur existant lit process.env, pas automatiquement un fichier .env.
Les variantes .env.*, *.env et *.env.* sont maintenant ignorées ; les exemples
.env.example restent versionnables. git add -f peut toujours forcer un ajout :
gitignore protège les ajouts ordinaires, pas un contournement explicite.

Depuis PowerShell, à la racine du dépôt, saisir la clé dans une invite masquée
(elle ne figure pas dans la commande ni dans l'historique) :

```powershell
$focusdayKey = Read-Host 'Clé OpenAI locale' -AsSecureString
$env:OPENAI_API_KEY = [System.Net.NetworkCredential]::new('', $focusdayKey).Password
Remove-Variable focusdayKey
$focusdayBytes = New-Object byte[] 32
$focusdayRng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$focusdayRng.GetBytes($focusdayBytes)
$env:FOCUSDAY_AI_SAFETY_SECRET = [Convert]::ToBase64String($focusdayBytes)
$focusdayRng.Dispose()
[Array]::Clear($focusdayBytes, 0, $focusdayBytes.Length)
Remove-Variable focusdayBytes, focusdayRng
$env:OPENAI_MODEL = 'gpt-5.6-luna'
$env:OPENAI_STORE = 'false'
$env:OPENAI_TIMEOUT_MS = '20000'
npm.cmd --prefix server run build
node server/scripts/openai-readonly-smoke.mjs --live
```

Le secret HMAC est généré en mémoire, sans affichage ni fichier. Ne transmettre
aucun secret dans la conversation. Les variables d'un terminal utilisateur ne
sont pas héritées par un processus Codex déjà lancé. Exécuter le test dans ce
même terminal, puis communiquer uniquement son résumé non sensible.
Alternative si l'utilisateur crée lui-même server/.env ignoré :
`node --env-file=server/.env server/scripts/openai-readonly-smoke.mjs --live`.
Ne pas utiliser les deux chemins pour éviter un deuxième appel involontaire.

Après le test, effacer les variables de cette session :

```powershell
Remove-Item Env:OPENAI_API_KEY, Env:FOCUSDAY_AI_SAFETY_SECRET
```

## Chemin testé

Harness manuel uniquement : AiService → OpenAiResponsesProvider → SDK officiel
→ Responses. Aucun serveur HTTP local ni route d'authentification alternative.
Le statut HTTP rapporté est celui de Responses ; backendValidation décrit
la validation dans le backend, pas un test du endpoint Firebase authentifié.
Le endpoint normal et son verifyIdToken restent inchangés.

Un seul appel, retries désactivés, modèle imposé par vérification de la configuration,
store=false, timeout de 20 secondes. SDK logging désactivé même si OPENAI_LOG est défini.
Le contexte est synthétique et fixe. La pseudonymisation utilise une identité de
fixture non Firebase. Le schéma de ce harness impose proposedActions=[] ; le
contrôle local rejette également toute action. Aucune capacité de mutation.
Les sorties console contiennent seulement des métadonnées de réussite ou un
diagnostic fixe : jamais la clé, le texte modèle, l'identifiant ou l'erreur brute.

Le modèle demandé figure dans la
[documentation officielle Responses](https://developers.openai.com/api/docs/guides/your-data#api-endpoint-tool-and-model-support).
L'accès du compte, le quota, la facturation et l'acceptation du schéma doivent
encore être vérifiés par l'appel réel. En cas d'échec : pas de fallback modèle,
pas de retry automatique ; diagnostic distinguant délai, connexion,
authentification, accès modèle, quota/facturation/débit et requête incompatible.

## Audit taskId — aucun contrat modifié

Le contexte serveur ne contient que title/completed. Flutter conserve localTaskId
localement, puis valide action.taskId contre les tâches du projet courant et
revalide après confirmation.

Recommandation 15D.2-D : C, mapping éphémère non sensible par requête.
Associer chaque tâche autorisée à une référence aléatoire temporaire ; conserver
la correspondance avec l'ID réel côté client/backend de confiance, liée à la
requête, l'utilisateur et au projet. Le schéma pourra limiter les références
à une enum du snapshot, mais la validation déterministe doit rejeter toute
référence absente, expirée, rejouée ou d'un autre projet. Résoudre uniquement
via le mapping, jamais via un ID inventé par le modèle, puis confirmer et
revalider localement l'état actuel avant mutation.
Ne pas utiliser un ordinal seul : il devient ambigu si la liste est réordonnée.
Un prompt ne suffit pas à imposer l'appartenance d'un identifiant.

## État initial

Toutes les variables requises étaient absentes du processus inspecté.
Aucun appel réel possible tant que l'utilisateur n'a pas configuré les secrets.
Les six alertes npm de 15D.2-A restent hors périmètre.
