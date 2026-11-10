# Cavepatate : mod Luanti

Mod **`cavepatate`** pour **Luanti** (ex-Minetest), jeu **Minetest Game** + **Farming Redo**.

**Vision** : une **grande cave thématique « pomme de terre »**, générée sous terre dans le **monde normal**, inspirée de l'esprit de la *Poisonous Potato Update* de Minecraft. Le mod comprend la génération de la cave, ses **blocs** et ses **structures**.
**Hors périmètre** : dimension, portail, mobs, ambre (sous toutes ses formes), tout ce qui n'est pas la patate ou ses dérivés.
**Originalité** : on reprend des *types* de blocs et une ambiance (roche-patate, blocs de patate, patate empoisonnée, racines, arbres-patates, ruines), **jamais** les noms, textures ou plans de structures de Minecraft.

Spécifications : `.claude/specs/SPEC.md` (validée par l'utilisateur) et plan `.claude/specs/PLAN.md`.

## Règle n°1 : la racine EST le mod

Le dossier racine est le mod lui-même, tel qu'il sera installé dans `mods/cavepatate`.
- À la racine, **uniquement des fichiers du mod** : `mod.conf`, `init.lua`, `src/`, `textures/`, `sounds/`, `models/`, `locale/`, `schematics/` si besoin, `settingtypes.txt`, `README.md`, `LICENSE.txt`, `screenshot.png`.
- **Jamais** de sous-dossier `cavepatate/`, de `tests/`, `tools/`, `docs/`, ni de **mod annexe** (pas de mod de test).
- Tout l'outillage Claude vit dans `.claude/` (ignoré par Luanti).

## Arborescence du mod

```
mod.conf                  depends = default, farming · optional_depends = stairs, walls, doors, dye, vessels, moreblocks, friandises
init.lua                  namespace global `cavepatate` + chargement ordonné de src/*.lua (rien d'autre)
settingtypes.txt          réglages serveur (cellule, chance, profondeur, alignement, structures, lumière)
README.md                 présentation du mod (anglais)
src/util.lua              util.name("x") -> "cavepatate:x", util.tex("x") -> "cavepatate_x.png", util.item_exists
src/items.lua             objets (patate vénéneuse, pelures, frites, huiles, sève…) + cavepatate.eat_risky
src/nodes.lua             roches, minerais, sols, végétation de cave, nœuds techniques (cave_light, loot)
src/blocks.lua            blocs de patate, compressions, purée, tête, pelures (16 couleurs), briques, nuage
src/wood.lua              bois de tubercule : tige, planches, feuilles, pousse, fruit, pédicelle, porte, trappe, barrières
src/machines.lua          friteuse, trancheuse, raffinerie, pile, piédestal, tubercule flottant
src/shapes.lua            More Blocks (stairsplus) ou escaliers/dalles MTG, murets
src/crafts.lua            recettes (ignorées si un ingrédient d'un autre mod manque)
src/cave.lua              placement par cellules + fonctions pures : floor_at, biome_at, pillar_at, arena_site
src/structures.lua        constructeurs procéduraux (jamais hors du chunk)
src/mapgen.lua            on_generated : carve + decorate
src/loot.lua              LBM : marqueurs -> coffres garnis
src/commands.lua          /cavepatate [goto]
textures/                 cavepatate_<objet>[_<face>].png (16×16, originales ; sources dans .claude/textures_src/)
locale/                   template.txt + cavepatate.fr.tr
```

## Environnement

- Luanti **5.18.0** : `~/Downloads/luanti.app/Contents/MacOS/luanti` (variable `LUANTI_BIN` pour en changer)
- Données utilisateur : `~/Library/Application Support/minetest/` (jeu `minetest_game`, `mods/`, `worlds/`)
- Farming Redo : **à installer** dans `~/Library/Application Support/minetest/mods/farming`, puis ajouter `farming` dans `.claude/test_mods.txt`. Pour le test headless sans l'installer : `EXTRA_WORLDMODS=<chemin d'un clone> load_test.sh`
- LuaJIT 2.1 présent · luacheck absent (`brew install luacheck` recommandé ; sinon fallback LuaJIT)
- Python 3 (sans PIL) pour les scripts de textures et de traduction

## Compatibilité

- **Luanti ≥ 5.8** (minimum de MTG) tant que la version du serveur cible est inconnue. API récentes protégées : `core.get_value_noise_map or core.get_perlin_map` et `core.get_value_noise or core.get_perlin` (renommés en 5.12), `core.features.*`. Génération dans le main env (comme Friandises).
- Fonctionne sous tous les mapgens de MTG. Rien n'est généré en `singlenode`.
- Patates : Farming Redo (`farming.mod == "redo"`). `farming:potato` (groupe `food_potato`) et les dérivés `farming:baked_potato`, `potato_salad`, `potato_omelet`, `spanish_potatoes`, `samosa`. Données vérifiées : `.claude/reference/farming_redo_potato.md`. Sans Farming Redo, ou avec la patate désactivée, le mod se charge et la cave se génère quand même. Seuls les contenus liés aux items de farming sont omis.

## Conventions de code (Lua)

- API **`core.*`** (jamais `minetest.*`). Tabulations, lignes ≤ 120 caractères.
- Une seule globale : `cavepatate`. Tout le reste en `local`. `local S = cavepatate.S` en tête des fichiers de `src/`. Tous les nœuds de la cave ont `is_ground_content = false` (voir skill luanti-mapgen, « Pièges connus »).
- Noms `cavepatate:<nom>` en snake_case anglais. Textures `cavepatate_<nom>.png`.
- Chaînes visibles : `S("...")` en anglais, traduites en français dans `locale/cavepatate.fr.tr`. Paramètres `@1`, jamais de concaténation.
- Enregistrements uniquement au chargement. Génération déterministe (`PcgRandom(blockseed)`, pas de `math.random`), sortie immédiate hors plage Y, buffers réutilisés.
- Logique pure (bruit, seuils, choix de structures) séparée de la colle moteur.

## Commandes

| But | Commande |
|---|---|
| Lint (luacheck ou fallback LuaJIT) | `.claude/skills/luanti-test/scripts/lint.sh` |
| Test de chargement headless (monde temporaire hors projet) | `.claude/skills/luanti-test/scripts/load_test.sh [secondes]` |
| Traductions | `python3 .claude/skills/luanti-i18n/scripts/update_translations.py [--check]` |
| Textures `.claude/textures_src/*.px` → `textures/` | `python3 .claude/skills/luanti-textures/scripts/pixelart.py build .claude/textures_src` |
| Monde de dev (lien du mod, `--new` recrée, `--launch` lance) | `.claude/skills/luanti-play/scripts/dev_world.sh [--new] [--launch]` |

## Workflow

1. `/luanti-spec` : spécification → `SPEC.md` + `PLAN.md` (après questions de clarification).
2. `/luanti-feature <tâche>` : implémentation complète d'une tâche (code, textures, i18n, lint, test, revue).
3. `/luanti-play [--new] [--launch]` : vérification en jeu, dans un nouveau monde après toute modification du générateur.

Skills de connaissance : `luanti-api`, `luanti-mapgen`, `luanti-farming`, `luanti-textures`, `luanti-i18n`, `luanti-test`.
Agents : `luanti-architect` (conception, plan), `luanti-dev` (implémentation), `luanti-reviewer` (revue, lecture seule), `luanti-tester` (tests, diagnostic), `luanti-pixel-artist` (textures).
Documentation hors-ligne : `.claude/reference/README.md`.

## Questions ouvertes

- Version de Luanti du **serveur** cible (le client local est en 5.18) ?
- Licence du code et des médias (MTG : LGPL 2.1 pour le code, CC BY-SA 3.0 pour les médias) ?
