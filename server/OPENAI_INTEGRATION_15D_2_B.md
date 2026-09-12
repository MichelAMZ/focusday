# OpenAI Responses — phase 15D.2-B

L'adaptateur utilise le SDK officiel déjà installé et responses.create.
Le modèle, store (false par défaut) et timeout viennent de la configuration
serveur. Aucun modèle Flutter, changement de dépendance ou secret ajouté.
Le timeout est passé par requête avec maxRetries=0 afin d'éviter sa multiplication.

La sortie demandée est { message, proposedActions }, via text.format json_schema
strict, fonctionnalité documentée dans les
[Structured Outputs officiels](https://developers.openai.com/api/docs/guides/structured-outputs).
Le modèle serveur choisi devra supporter Responses et ce format ; la compatibilité
du modèle et les autorisations du compte restent à valider lors d'une phase autorisant
les appels réels. Aucun appel réel dans cette phase.

Le parsing et la validation locale restent obligatoires : types, champs en trop,
longueurs, plages, taille du lot, doublons et écritures contradictoires sont contrôlés.
Une réponse incomplète ou un refus est rejeté. Le message structuré est converti
en text pour préserver le contrat Flutter existant. L'absence d'actions est acceptée.
Les erreurs ne renvoient que les codes publics existants, jamais le contenu fournisseur.

Seuls message utilisateur, langue, temps de focus et nom/tâches/statuts/notes du
projet actif sont sérialisés. La projection explicite exclut les propriétés
supplémentaires même pour un appelant interne. safety_identifier est le HMAC
calculé par AiService, pas le Firebase UID. Aucun historique distant n'est
réutilisé via conversationId. Les champs de texte libre peuvent eux-mêmes
contenir des données saisies par l'utilisateur : cette allowlist structurelle
n'est pas un détecteur universel de secrets dans le texte.

Les six types d'actions existants sont conservés. Le contexte actuel ne contient
pas de taskId : le prompt interdit de les inventer et demande du conseil textuel
pour renommer/terminer/rouvrir une tâche. La validité référentielle et l'état courant
restent vérifiés localement après confirmation, comme en 15D.1.
Le provider n'expose ni outil ni callback de mutation et ne peut exécuter ces actions.

Les tests injectent un client simulé ou un transport fetch simulé dans le vrai SDK,
y compris pour vérifier l'annulation au timeout. Ils couvrent aussi la route HTTP,
la pseudonymisation, les logs et le blocage des propositions contradictoires.
Les tests ne lisent aucune clé réelle et ne lancent pas server.ts.

Les six alertes npm modérées documentées dans DEPENDENCY_SECURITY_AUDIT_15D_2_A.md
restent inchangées. Aucun commit, push, déploiement, changement Firebase rules
ou modification Flutter.
