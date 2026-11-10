---
name: luanti-feature
description: Implémente de bout en bout une tâche du plan du mod cavepatate (code Lua, textures, traductions, lint, test de chargement, revue) en respectant les conventions du projet. À utiliser quand l'utilisateur demande d'implémenter une tâche (ex. « fais T03 »), un bloc, une structure ou une partie de la génération.
argument-hint: "<identifiant de tâche ou description>"
---

# Implémenter une tâche

Tâche : `$ARGUMENTS`. Si elle n'est pas dans `.claude/specs/PLAN.md` et qu'elle est non triviale, passer d'abord par `/luanti-spec`.

## Déroulé

1. **Cadrer** : relire la tâche, la section correspondante de `SPEC.md`, et les fichiers concernés. Rappel : la racine = le mod, aucun fichier hors-mod à la racine, aucun mod annexe.
2. **Vérifier l'API** (skill `luanti-api`) pour chaque fonction ou champ dont on n'est pas certain. Génération : skill `luanti-mapgen`. Patates : skill `luanti-farming` et `.claude/reference/farming_redo_potato.md`.
3. **Coder** dans `src/<domaine>.lua`, puis ajouter le `load("<domaine>")` dans `init.lua` à la bonne place. Mettre `mod.conf` à jour si une dépendance s'ajoute. Respecter les conventions de `.claude/CLAUDE.md`.
4. **Textures** pour chaque nouveau node ou item : sources `.claude/textures_src/*.px` → `build` → aperçu regardé (skill `luanti-textures`). Pour un lot important, déléguer à l'agent `luanti-pixel-artist`.
5. **Traductions** : `update_translations.py`, puis remplir le français (skill `luanti-i18n`).
6. **Vérifier** : `lint.sh` puis `load_test.sh` doivent être à 0. Si la tâche touche aux patates : avec et sans Farming Redo. Corriger jusqu'au vert, sans désactiver un contrôle pour le faire passer.
7. **Revue** : faire relire le diff par l'agent `luanti-reviewer`, et traiter les points bloquants.
8. **Clore** : cocher la tâche dans `PLAN.md` (`[fait]`), noter les écarts par rapport à la spec. Indiquer à l'utilisateur ce qui est à vérifier en jeu (`/luanti-play --new --launch` si la génération a changé).

Ne jamais déclarer « terminé » sans les sorties de `lint.sh` et `load_test.sh` à 0. S'ils échouent, le dire avec la sortie.
