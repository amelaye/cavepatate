---
name: luanti-mapgen
description: Génération des grandes caves patate du mod cavepatate (monde normal, Y −5000 à −3000) — placement par cellules, ellipsoïde déformé, coque, alignement sur les chunks, sol et sous-biomes, structures procédurales qui ne sortent jamais du chunk, butin par LBM, lumière d'ambiance, performance, pièges connus (is_ground_content, jointures de chunks), et méthode de vérification visuelle. À utiliser pour toute modification de src/cave.lua, src/mapgen.lua, src/structures.lua ou src/loot.lua.
---

# Génération de la cave patate

Architecture éprouvée, calquée sur le mod Friandises du même auteur (`~/Documents/Friandises/mapgen.lua`, `structures.lua`, à relire pour comparer). Spécification à jour : `.claude/specs/SPEC.md`.

## 0. Principes non négociables

- Monde normal : pas de dimension, pas de portail, pas de mobs. Contenu original, sans nom, texture ou plan copié de Minecraft.
- **Déterministe** : `PcgRandom(blockseed)` dans le générateur, `PcgRandom(graine, cx, cz)` pour le placement. Jamais de `math.random`.
- Toute grandeur utilisée par plusieurs chunks (cave, sol, biome, site de l'arène) se calcule par une **fonction pure** de `src/cave.lua`, à partir de bruits ponctuels. Chaque chunk obtient ainsi la même réponse.
- Une structure **n'écrit jamais hors de minp..maxp** : `fits()` sinon abandon, puis `reserve()` de son emprise.

## 1. Fichiers

| Fichier | Rôle |
|---|---|
| `src/cave.lua` | réglages, bruits, `cave.get(cx, cz)`, `caves_in(minp, maxp)`, `find_nearest`, `floor_at`, `biome_at`, `pillar_at`, `arena_site`, `chunk_geometry`, évitement de Friandises |
| `src/mapgen.lua` | `register_on_generated` (main env) : `carve` (creusement, matériaux par sous-biome `MATERIALS`, sentiers, eau, coque veinée, conversion des minerais MTG `c.ore_map`, contamination, repérage des points de lumière) puis `decorate` (arène, structures du sol et du plafond, nuages, petites décorations `FLOOR_DECOR`) ; lumière posée à la fin là où l'air est resté libre ; `cavepatate.content_ids()` exporte les IDs |
| `src/structures.lua` | constructeurs `st.<nom>(ctx, x, y, z, blighted)` (24, tous testés) + `st.arena(ctx, site)` ; `st.tuber_tree` sert aussi à la pousse d'arbre (wood.lua) |
| `src/loot.lua` | LBM marqueurs → `default:chest` garni |

`ctx` = `{ data, p2, area, minp, maxp, sx, sy, pr, c (content IDs), cav, reserved }`. Les colonnes calculées par `carve` sont dans `col_floor/col_biome/col_pillar[(z-minp.z)*sx + (x-minp.x) + 1]`.

## 2. Ajouter une structure

1. Écrire `function st.ma_structure(ctx, x, y, z, blighted)` dans `structures.lua`. `(x, y, z)` est le premier nœud d'air au-dessus du sol (ou le dernier sous le plafond).
2. Commencer par `if not fits(ctx, x0, y0, z0, x1, y1, z1) then return false end`. Pour les ruines, vérifier aussi `unevenness(...)`.
3. Écrire avec `put` (écrase) ou `put_air` (seulement dans l'air). Coffres : `put(ctx, x, y, z, c.loot, chest_facedir(fx, fz))`.
4. Finir par `reserve(...)` et `return true`.
5. L'ajouter avec un poids dans `FLOOR_FEATURES` ou `CEILING_FEATURES` (`mapgen.lua`), par sous-biome.
6. Nouveau bloc utilisé ? L'ajouter à `init_ids()` dans `mapgen.lua`.

Structure unique par cave, comme l'arène : site calculé dans `cave.lua` à partir des seuls bruits, mis en cache dans `cav`, construit par le chunk qui contient le site en entier (y compris en Y).

## 3. Pièges connus (vécus)

- **`is_ground_content = false` sur tous les nœuds de la cave.** Sinon les grottes et cavernes de MTG du chunk voisin, générées plus tard, creusent la couche de recouvrement (1 nœud) à la jointure des chunks. Cela laisse une ligne d'air dans le sol et perce la coque.
- Le mapgen ne peut ni remplir un inventaire ni poser de métadonnées utiles : marqueur + LBM `run_at_every_load = true`. Un LBM à `false` ne tourne jamais sur un bloc fraîchement généré.
- `chunksize` peut être un vecteur (5.15+) : passer par `cave.chunk_geometry()`.
- Bruits : `core.get_value_noise_map or core.get_perlin_map` et `core.get_value_noise or core.get_perlin` (renommés en 5.12). Les bruits ponctuels se créent **après** le chargement (graine du monde), donc paresseusement.
- Les décorations du moteur (`register_decoration`) passent **avant** `on_generated` et ne voient pas nos cavernes. Toutes les décorations de la cave sont posées par `decorate`.
- Après une modification du générateur, il faut un **nouveau monde** : les chunks déjà générés ne changent plus.

## 4. Performance

Mesure de référence : 100 à 420 ms par chunk de cave (moyenne 170 ms), environ 40 chunks par cave. Règles :
- sortie immédiate si le chunk est hors de `[YMIN, YMAX]` ou ne touche aucune boîte de cave ;
- buffers (`data`, `p2data`, bruits, colonnes) réutilisés ; boucle `z, x, y` avec `vi += ystride`, `ni += sx` ;
- ne pas chercher le plafond quand il ne peut pas être dans le chunk (`ceiling_in_chunk`) ;
- `cavepatate.last_gen_us` donne le temps du dernier chunk.

## 5. Vérifier une modification

1. `lint.sh` + `load_test.sh` (skill `luanti-test`) : chargement sans erreur.
2. **Génération** : en jeu, nouveau monde (`/luanti-play --new --launch`), `/cavepatate goto`. Ou, pour une vérification automatique, un outil **temporaire hors projet** (scratchpad) :
   - un mini-mod de test lié dans `worldmods/` d'un monde jetable (mapgen v7) ;
   - il appelle `cavepatate.cave.find_nearest`, `core.emerge_area` sur une coupe verticale et une tranche horizontale, lit les nœuds au VoxelManip, écrit des grilles texte, puis appelle `core.request_shutdown()` ;
   - les grilles sont converties en PNG avec `png_write` de `pixelart.py`, puis regardées.

   Cet outil ne doit **jamais** entrer dans le projet (règle de l'utilisateur : un seul mod, `cavepatate`). Le supprimer après usage.
