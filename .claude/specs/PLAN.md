# PLAN : Cavepatate

La v1 (cave, blocs, structures, butin, ambiance, commande) est implémentée : voir `SPEC.md`.
Ce plan couvre la **v2 : hameaux et églises** (section du même nom dans `SPEC.md`).
Chaque tâche se termine par : lint + load_test OK, traductions à jour si du texte visible change.

## T01 — Outils partagés et formes de construction   [fait]
Fichiers : src/structures.lua, src/hamlets.lua (nouveau), init.lua, src/mapgen.lua (init_ids), .claude/CLAUDE.md (arborescence)
Dépend de : —
- Exposer `fits`, `put`, `put_air`, `get`, `reserve`, `chest_facedir` sur `st` (sans changer leur comportement).
- Créer `src/hamlets.lua`, chargé après `structures.lua` dans `init.lua`.
- `shape(forme, matériau, facedir)` → content ID + param2 : More Blocks (`cavepatate:<forme>_<mat>[_variante]`), sinon escaliers et dalles MTG (`stairs:stair_cavepatate_<mat>`, `stairs:slab_…`, les pentes devenant des escaliers), sinon bloc plein. Résolution mise en cache au premier usage.
- IDs ajoutés à `init_ids()` : `default:glass`, `default:bookshelf`, `tuber_door_a` + `doors:hidden`, `tuber_fence`, `tuber_fence_gate_closed`, `fryer`, `potato_slicer`, `tuber_stem`, toutes optionnelles via `opt_id` quand elles viennent d'un mod facultatif.
Fait quand : un appel de `shape` donne un nœud valide dans les 3 configurations (More Blocks / stairs seul / ni l'un ni l'autre), vérifié par un `core.log` temporaire dans le test de chargement ; lint + load_test OK.

## T02 — Sites des hameaux   [fait]
Fichiers : src/cave.lua, settingtypes.txt
Dépend de : —
- Réglage `cavepatate_cavity_hamlets` (int 3, de 1 à 3) ; toute cave a au moins un hameau.
- `cave.hamlet_sites(cav)` est une fonction pure, mise en cache dans `cav`. Les candidats sont les centres de chunk dans `rx·0,7 × rz·0,7`, en Champs ou en Bosquet (`biome_at` au centre et aux 4 coins de l'emprise de 64×64), avec un sol au sec et un écart de hauteur ≤ 8 (échantillons `floor_at` tous les 8 nœuds). On exclut le chunk de l'arène et les chunks voisins d'un hameau déjà retenu. On garde les plus plats, puis on tire 2 ou 3 sites (au plus le réglage) avec `PcgRandom(cav.x, cav.z)`.
- Chaque site vaut `{ x, z, y = sol de la place, seed }`.
Fait quand : pour 3 caves de la graine de test, la liste est stable d'un appel à l'autre et d'un chunk à l'autre, aucun site ne tombe dans le chunk de l'arène, et le réglage à 0 donne une liste vide ; lint + load_test OK.

## T03 — Chaumière   [fait]
Fichiers : src/hamlets.lua
Dépend de : T01
- `st.cottage(ctx, x, y, z, facing, pr)` : fondation, soubassement, murs (3 variantes), poteaux en tige, fenêtres, porte (ou ouverture), toit à deux pans en pentes avec coins et débord, pignons, cheminée.
- Meubles : table, chaises, friteuse ou trancheuse, étagère, tapis, fruit-lampe, coffre `cavepatate:loot`.
- `fits` puis `reserve` ; renvoie l'emprise utilisée.
Fait quand : une chaumière posée par une commande de test **temporaire** (scratchpad, jamais dans le mod) est complète dans les 4 orientations ; lint + load_test OK.

## T04 — Église   [fait]
Fichiers : src/hamlets.lua
Dépend de : T01
- `st.church(ctx, x, y, z, facing, pr)` : nef 7×13 en briques de roche-tubercule, contreforts, toit en pentes de briques calcinées, clocher 5×5 de 18 à 22 nœuds, chambre des cloches ouverte, patate vigoureuse pendue, flèche pyramidale, germe au sommet.
- Intérieur : allée de tapis, bancs en escaliers, chœur surélevé (dalles), autel (piédestal + germe), fenêtres hautes, double porte, coffre `cavepatate:loot_rich`.
Fait quand : l'église est complète dans les 4 orientations (même vérification temporaire que T03) ; lint + load_test OK.

## T05 — Hameau et intégration au générateur   [fait]
Fichiers : src/hamlets.lua, src/mapgen.lua
Dépend de : T02, T03, T04
- `st.hamlet(ctx, site)` : place nivelée avec puits et lampadaires, église côté place, 3 ou 4 chaumières autour, portes vers la place, potagers clos, chemins de `tuber_path` sur le relief. Disposition tirée par `PcgRandom(site.seed)`. Un bâtiment qui ne tient pas est déplacé ou omis, jamais coupé.
- Dans `decorate` : juste après l'arène, construire chaque site du chunk courant (site entier dans minp..maxp, y compris en Y), puis réserver l'emprise du hameau.
Fait quand : la génération headless d'une cave de la graine de test (outil temporaire hors projet, voir le skill luanti-mapgen §5) montre en coupe et en vue de dessus 2 ou 3 hameaux complets, sans chevauchement avec d'autres structures ; le temps par chunk de hameau reste ≤ +100 ms ; lint + load_test OK.

## T06 — Commande `/cavepatate`   [fait, révisée]
Fichiers : src/commands.lua, locale/template.txt, locale/cavepatate.fr.tr
Dépend de : T02
- Révisé à la demande de l'utilisateur : la commande `/patate` devient `/cavepatate`, sans paramètre (coordonnées de la cave ; chaque cave contient des hameaux). La sous-commande `hamlet` est retirée.
Fait quand : la commande répond dans les deux cas ; `update_translations.py --check` OK ; lint + load_test OK.

## T07 — Vérification et finitions   [fait, sauf la visite en jeu]
Fichiers : README.md, .claude/specs/SPEC.md, .claude/skills/luanti-mapgen/SKILL.md
Dépend de : T05, T06
- load_test avec More Blocks, sans More Blocks, et sans `doors`.
- En jeu, dans un nouveau monde (`/luanti-play --new --launch`) : `/cavepatate`, visite (portes, coffres, lumière, toits, raccords de chunk).
- Mettre à jour README (anglais), SPEC (mesures) et le skill luanti-mapgen (structures multi-bâtiments, `shape`).
Fait quand : tous les critères d'acceptation de la v2 dans `SPEC.md` sont vérifiés.

## T08 — Huile de friture à la place de l'eau   [fait]
Fichiers : src/nodes.lua, src/mapgen.lua, src/structures.lua, mod.conf (bucket), locale/
Dépend de : —
- Liquide `cavepatate:frying_oil_source/_flowing`, seau si `bucket` ; `c.water` → `c.oil` (lacs, rigoles, puits).
- Nettoyage des liquides étrangers (crues des grottes du moteur) autour du chunk, dans le creux des caves.
Fait quand : la génération headless ne montre plus d'eau dans la cave, et l'huile remplit les lacs (fait : 17 803 nœuds d'huile, 0 nœud étranger).

## Écarts et restes (2026-11-25)
- Critères de site assouplis, détail dans SPEC (sans cela, aucun site sur la graine de test).
- Pas d'étagère `default:bookshelf` dans les chaumières ; flèche de l'église sans germe au sommet (tour de 6).
- Revue (agent luanti-reviewer) : points traités : décorations de plafond dans les maisons, portes au niveau de la place, remise des bords limitée à la coque et au creux, profileur, haut de porte double, `is_ground_content` des marqueurs, réglage 1 à 3, petits chunks, exports inutiles, bassin et patate monumentale au lieu du puits. Laissés et documentés : param2 non remis, liquides posés par un joueur près d'un chunk non généré, terre humide qui sèche, limite Everness 5.9+, cohabitation avec paleocave (même profondeur) à arbitrer.
- Lint indisponible sur la machine Windows (ni LuaJIT ni luacheck) ; Python 3.10 est là, sous `python`.
- À faire en jeu (nouveau monde) : `/cavepatate`, portes, coffres, lumière, toits, raccords.
