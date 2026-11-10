---
name: luanti-spec
description: Transforme une demande ou spécification de l'utilisateur pour le mod cavepatate en spécification structurée (.claude/specs/SPEC.md) et en plan de tâches ordonnées (.claude/specs/PLAN.md), après avoir levé les ambiguïtés. À utiliser quand l'utilisateur donne ou modifie des spécifications, des idées de blocs, de structures ou de génération.
argument-hint: "[texte de la spécification]"
---

# De la spécification au plan

Entrée : `$ARGUMENTS` et/ou le message de l'utilisateur, plus `.claude/specs/SPEC.md` s'il existe déjà (on le **met à jour**, on ne repart pas de zéro).

## Étapes

1. **Lire le contexte** : `.claude/CLAUDE.md` (périmètre : grande cave thématique patate, monde normal, pas de dimension, de portail ni de mobs, uniquement la patate et ses dérivés), le SPEC/PLAN existant, les skills `luanti-mapgen` et `luanti-farming`.
2. **Vérifier la faisabilité** dans Luanti (doc `.claude/reference/`) et repérer ce qui sort du périmètre ou copierait un jeu existant. Dans ce cas, proposer un équivalent original.
3. **Lister les ambiguïtés** qui changent réellement l'implémentation : taille et profondeur de la cave, rareté, liste des blocs, recettes, structures, butin, interactions avec Farming Redo. Poser les questions avec AskUserQuestion (4 au maximum, chaque option avec sa conséquence, l'option recommandée en premier). Tout le reste se tranche par une valeur par défaut raisonnable, **notée** dans la spec.
4. **Écrire `.claude/specs/SPEC.md`**, en français :
   - Vision (3 à 5 lignes) et hors-périmètre explicite
   - Blocs et items : tableau `nom technique | nom affiché (fr/en) | rôle | obtention/génération | propriétés (lumière, grimpable, groupes, dureté) | recette`
   - Génération : profondeur, rareté, forme, habillage, décorations, minerais
   - Structures : rôle, taille approximative, fréquence, contenu des coffres (un croquis ASCII si utile)
   - Réglages (`settingtypes.txt`) et compatibilité (Luanti ≥ 5.8, Farming Redo optionnel/requis)
   - Critères d'acceptation vérifiables, en jeu et par les tests
5. **Écrire `.claude/specs/PLAN.md`** : tâches petites, ordonnées, chacune livrable et testable seule.
   ```
   ## T03 — Roche-patate et variantes   [à faire]
   Fichiers : src/nodes.lua, textures/…, locale/
   Dépend de : T01
   Fait quand : nodes enregistrés, textures présentes, traductions, lint + load_test OK
   ```
   Ordre type : socle (nodes de base + textures) → génération de la zone → habillage et décorations → structures → butin et recettes → réglages → commande `/patate` → finitions.
6. Présenter un résumé court à l'utilisateur (vision, nombre de blocs/structures, premières tâches) et demander validation avant d'implémenter.
