# FocusDay — audit 15D.2-A

Date : 10 septembre 2026. Base : main, de1dbc0.

## Décision

Maintien temporaire documenté de la chaîne compatible. Aucune modification de
package.json ou package-lock.json pendant cet audit. Leurs modifications déjà
présentes à l'ouverture (Firebase Admin 14.3.0 et Vitest 4.1.11) sont conservées.
Pas d'override, downgrade, audit fix, commit, push ou déploiement.

## Usages réels

- server/src/server.ts importe initializeApp depuis firebase-admin/app.
- server/src/auth/firebase_auth_verifier.ts importe getAuth depuis firebase-admin/auth
  et appelle getAuth().verifyIdToken(token).
- Aucun import ni appel Storage ou Firestore dans server/src.
- Flutter utilise cloud_firestore (lib/core/cloud), pas Firebase Storage.
  FocusDayCloudStorage est une abstraction Firestore, pas le SDK Storage.
- express et cors sont utilisés par app.ts ; openai est utilisé par le fournisseur
  Responses prévu par l'architecture. Les tests injectent FakeProvider et FakeAuth.
  Les outils TypeScript, tsx, Vitest, Supertest et leurs types servent au build,
  au développement et aux tests. Aucun retrait direct ne se justifie ici.

## Cause et portée

L'audit complet retourne 6 entrées modérées pour une même alerte
[GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq)
(CVE-2026-41907), propagée à travers les dépendants :

```text
firebase-admin@14.3.0
└─ @google-cloud/storage@7.22.0
   ├─ gaxios@6.7.1 → uuid@9.0.1
   ├─ teeny-request@9.0.0 → uuid@9.0.1
   └─ retry-request@7.0.2 → teeny-request@9.0.0 → uuid@9.0.1
```

Le SDK déclare Storage ^7.22.0 et Firestore ^8.7.1 en optionalDependencies.
npm les installe par défaut : « optionnel » autorise l'échec ou l'omission,
et ne signifie pas installation conditionnée aux imports applicatifs.
Voir les [règles npm](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/#optionaldependencies).

L'alerte concerne des écritures partielles silencieuses par uuid v3/v5/v6
lorsqu'un buffer de sortie ou un offset invalide est fourni. Dans le code
installé, gaxios/build/src/gaxios.js et teeny-request/build/src/index.js
appellent uniquement v4() sans buffer, pour leurs frontières multipart.
Le backend utilise aussi node:crypto.randomUUID(), distinct de ce paquet.
Auth/App ne référencent pas cette chaîne Storage ; la branche Auth utilise
google-auth-library 10.9.1 et gaxios 7.3.1.

Conclusion d'analyse statique : aucun chemin exploitable identifié dans les
usages actuels de FocusDay. Cela ne corrige pas le paquet installé et ne vaut
pas garantie pour de futurs usages ni pour d'autres vulnérabilités.

## Options évaluées séparément

### A — Mise à jour supportée

Le registre npm consulté donne firebase-admin latest 14.3.0, Storage 7.22.0
comme dernière version 7.x et Storage latest 8.1.0. Cette dernière sort de
^7.22.0. Aucune mise à jour compatible identifiée ne corrige la chaîne actuelle.
Ne pas imposer Storage 8.x. La suggestion audit fix --force rétrograderait
Firebase Admin vers 10.3.0 : rejetée, jamais exécutée.

### B — Non-installation des dépendances optionnelles

`npm ci --omit=optional` est une option npm supportée. Pour un artefact de
production déjà compilé, `npm ci --omit=dev --omit=optional` permettrait de
ne pas installer les branches optionnelles Storage/Firestore inutilisées.
Cette piste doit être validée dans une installation isolée avec un test réel
du chargement Auth et de la vérification de tokens avant adoption.

L'omission s'applique à toutes les dépendances optionnelles, pas uniquement
à Storage. Le lock contient aussi des binaires optionnels @esbuild ; une
configuration globale pourrait affecter les outils de développement.
Aucune option npm standard documentée d'omission sélective par nom n'a été
identifiée. Ne pas supprimer manuellement des entrées du lock ou node_modules.

Les paquets omis restent résolus dans le lock, conformément à la
[documentation npm omit](https://docs.npmjs.com/cli/v11/using-npm/config/#omit).
`npm audit --omit=optional` retourne ici zéro, mais filtre le rapport sans
modifier l'installation. Ce résultat ne remplace pas les six alertes de
l'audit complet. Aucun .npmrc d'omission et aucune réinstallation appliqués.

### C — Override uuid

Rejeté. uuid 11.1.1 corrige l'alerte mais dépasse la version majeure demandée
par les consommateurs installés. Observer seulement v4() ne démontre pas la
compatibilité complète des contrats, exports et environnements de la chaîne.
Pas d'override sans validation amont et vérifications complètes.

### D — Maintien temporaire

Option retenue pour cette phase. Risque résiduel faible sur le chemin inspecté,
mais six alertes modérées restent présentes dans l'installation et le lock.
Réexaminer à chaque changement de dépendances, avant mise en production,
et avant tout ajout Storage/Firestore côté backend. Contrôle hebdomadaire
recommandé : npm audit, versions Firebase Admin et Storage, plages déclarées,
et suivi de l'advisory. Adopter un correctif 7.x supporté ou une version
Firebase Admin autorisant officiellement une chaîne corrigée, puis relancer
toutes les validations. À défaut, valider séparément l'artefact sans optionnels.

## Validation

- npm --prefix server audit : 6 modérées avant et après (code 1 attendu).
- npm --prefix server ls firebase-admin @google-cloud/storage gaxios teeny-request retry-request uuid : chaîne confirmée.
- npm --prefix server test : 46/46 PASS.
- npm --prefix server run build : PASS.
- npm --prefix server run lint : PASS (TypeScript --noEmit).
- flutter analyze : PASS, aucun problème.
- flutter test : 182/182 PASS.
- Sous PowerShell, npm.cmd utilisé lorsque npm.ps1 était bloqué.
  Après un échec réseau de l'audit, la consultation autorisée du registre a réussi.
- Aucun appel OpenAI réel : fournisseur simulé dans les tests ; serveur non lancé.
- Contrôle des fichiers suivis : aucun .env réel, node_modules, dist, build
  ou clé privée détecté. server/.env.example est un exemple autorisé.
  Recherche de signatures de secrets sans affichage de valeurs ; aucun secret
  détecté dans ce contrôle, qui ne constitue pas une analyse exhaustive d'historique.
- server/node_modules, server/dist et build sont ignorés par Git.

Prêt pour poursuivre 15D.2-B avec ce risque résiduel documenté ; ce constat
n'est pas une approbation de déploiement.
