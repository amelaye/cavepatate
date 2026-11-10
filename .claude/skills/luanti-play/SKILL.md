---
name: luanti-play
description: Tester le mod cavepatate en jeu — lier le mod dans le dossier mods de Luanti, créer/recréer le monde de dev dédié (cavepatate_dev), lancer Luanti dedans, checklist de vérification visuelle de la cave générée, lecture du debug.txt. À utiliser quand l'utilisateur veut voir le résultat en jeu ou après une modification du générateur.
disable-model-invocation: true
argument-hint: "[--new] [--launch]"
---

# Tester en jeu

```bash
.claude/skills/luanti-play/scripts/dev_world.sh $ARGUMENTS
```

- Crée (une fois) le lien `~/Library/Application Support/minetest/mods/cavepatate` → ce dossier. Le jeu lit le code en direct ; il suffit de **relancer le monde** après une modification (pas de rechargement à chaud dans Luanti).
- Crée le monde `cavepatate_dev` (créatif, sans dégâts) avec le mod et les mods de `.claude/test_mods.txt`. **Aucun autre monde n'est modifié.**
- `--new` : supprime et recrée ce monde. **Obligatoire après une modification du générateur**, car les chunks déjà générés ne changent plus.
- `--launch` : ouvre Luanti directement dans le monde de dev (joueur `dev`).

Lancer Luanti ouvre une fenêtre sur la machine de l'utilisateur : ne le faire que s'il l'a demandé ou accepté.

## Checklist de vérification (à proposer à l'utilisateur)

1. `/grantme all`, puis `/cavepatate goto` : téléportation vers la zone de cave la plus proche.
2. Taille et forme : grandes salles praticables, transitions progressives avec la pierre normale, pas de trou vers la surface ni vers l'océan.
3. Blocs : textures correctes (aucune texture manquante, qui s'affiche en damier), lumière d'ambiance, plantes et cristaux bien orientés (sol, plafond, murs).
4. Structures : présentes mais rares, posées au sol, non tronquées en bordure de chunk, coffres remplis.
5. Performance : pas de saccade notable pendant l'exploration (génération). Activer le profileur avec la touche F6.
6. Inventaire créatif : tous les blocs `cavepatate:` présents, noms traduits en français.

Après la session : lire les erreurs dans `~/Library/Application Support/minetest/debug.txt` (`grep -n "ERROR\|cavepatate" … | tail -50`).
