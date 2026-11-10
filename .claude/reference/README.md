# Documentation de référence (hors-ligne)

| Fichier | Contenu | Source |
|---|---|---|
| `lua_api.md` | API Lua officielle de **Luanti 5.18.0** (~12 900 lignes) | github.com/luanti-org/luanti, tag 5.18.0, `doc/lua_api.md` |
| `lua_api.toc.txt` | Table des matières de `lua_api.md` avec numéros de ligne | généré |
| `mtg_game_api.txt` | API de Minetest Game (chests, farming, stairs, doors, sfinv…) | copie de `games/minetest_game/game_api.txt` |
| `mtg_game_api.toc.txt` | Sections de `mtg_game_api.txt` | généré |
| `farming_redo_api.txt` | API de Farming Redo (TenPlus1) | codeberg.org/tenplus1/farming, `api.txt` |

## Lire efficacement

Ne jamais charger `lua_api.md` en entier. Chercher la section dans la TOC puis lire la plage :

```bash
grep -n -i "node definition\|formspec\|NodeMetaRef" .claude/reference/lua_api.toc.txt
sed -n '10802,11285p' .claude/reference/lua_api.md      # plage trouvée dans la TOC
grep -n "get_node_timer" .claude/reference/lua_api.md   # recherche directe d'une fonction
```

## Sections les plus utiles (lignes dans lua_api.md, version 5.18.0)

| Sujet | Ligne |
|---|---|
| Structure d'un mod / mod.conf / conventions de nommage | 278 / 481 |
| Textures et modificateurs (`^[colorize`, `^[transform`…) | 617 / 661 |
| Sons (`SimpleSoundSpec`) | 1331 |
| Nodes : paramtypes, drawtypes, nodeboxes | 1534 / 1560 / 1715 / 1829 |
| Items, groupes, groupes spéciaux, temps de minage | 2291 / 2438 / 2551 / 2636 |
| Métadonnées node / item | 2875 / 2936 |
| Formspecs : éléments, versions, styles | 2995 / 3067 / 3103 / 3825 |
| Inventaires (emplacements, listes joueur) | 4138 |
| Traductions (`.tr`, `.po`, échappements) | 4745 / 4963 |
| Utilitaires `core.*` / enregistrement / callbacks globaux | 6145 / 6521 / 6629 |
| Accès à l'environnement (`get_node`, `set_node`, `find_nodes_in_area`…) | 6961 |
| Inventaire, formspec, gestion d'items (fonctions) | 7391 / 7431 / 7490 |
| Timing (`core.after`), schémas, stockage de mod | 7715 / 8040 / 8159 |
| Classes : `InvRef`, `ItemStack`, `MetaDataRef`, `NodeMetaRef`, `NodeTimerRef`, `ObjectRef` | 8633 / 8703 / 8818 / 8929 / 8945 / 8972 |
| Définitions : ABM, LBM, tuiles, **item**, **node**, recettes de craft | 10358 / 10418 / 10490 / 10552 / 10802 / 11325 |
| Feature flags `core.features` (dispo par version) | 6186 |

## Sources de code lisibles localement

- Builtin du moteur (implémentation Lua de `core.*`) : `~/Downloads/luanti.app/Contents/Resources/builtin/game/` (`item.lua`, `register.lua`, `misc.lua`…)
- Mods de Minetest Game, très bons exemples : `~/Library/Application Support/minetest/games/minetest_game/mods/`
  - coffres : `default/chests.lua` · four (timer + formspec + inventaires) : `default/furnace.lua`
  - farming MTG : `farming/api.lua`, `farming/init.lua`

## Mettre à jour (nouvelle version de Luanti)

```bash
V=5.18.0   # version cible
curl -sSfL -o .claude/reference/lua_api.md https://raw.githubusercontent.com/luanti-org/luanti/$V/doc/lua_api.md
# puis régénérer la TOC (commande dans .claude/skills/luanti-api/SKILL.md, section « Mettre à jour la TOC »)
```
