---
name: luanti-api
description: Référence et règles de l'API Lua de Luanti 5.18 (ex-Minetest) pour le mod cavepatate. À utiliser dès qu'on écrit, modifie, relit ou débogue du code Lua du mod (nodes, items, crafts, callbacks, métadonnées, inventaires, timers, ABM/LBM, formspecs, protection), ou quand on se demande si une fonction/un champ existe et avec quelle signature.
---

# API Luanti : méthode et règles

## 1. Ne jamais deviner une API : vérifier

La doc officielle 5.18 est en local. Procédure systématique avant d'utiliser une fonction ou un champ qu'on ne connaît pas avec certitude :

```bash
grep -n -i "<sujet>" .claude/reference/lua_api.toc.txt         # trouver la section
sed -n '<début>,<fin>p' .claude/reference/lua_api.md            # lire la plage utile (pas tout le fichier)
grep -n "core.get_node_timer\|NodeTimerRef" .claude/reference/lua_api.md
```

Index des sections clés : `.claude/reference/README.md`. API Minetest Game (coffres, sfinv, stairs, sons `default.node_sound_*`) : `.claude/reference/mtg_game_api.txt`.
Pour comprendre un comportement précis, lire l'implémentation : builtin du moteur (`~/Downloads/luanti.app/Contents/Resources/builtin/game/`) et mods MTG (`~/Library/Application Support/minetest/games/minetest_game/mods/`). `default/chests.lua` et `default/furnace.lua` sont les modèles de référence pour un node à inventaire et à timer.

## 2. Règles d'or

- `core.*` uniquement (`minetest.*` est un alias historique).
- Cible **≥ 5.8**. Pour toute API plus récente, garde de version : `if core.features.on_timer_four_args then … end` (liste à la ligne ~6186 de lua_api.md).
- Une seule globale `cavepatate`. Tout est `local`. Pas de fonction globale « utilitaire ».
- Enregistrements (`register_node`, `register_craft`, `register_abm`, `register_lbm`, `register_on_*`) **uniquement au chargement**.
- Les positions sont des tables mutables. Ne jamais garder une référence passée par le moteur : `vector.copy(pos)`. Utiliser `vector.new`, `vector.add`, `vector.offset`, `vector.equals`, et `core.hash_node_position(pos)` comme clé de table.
- `core.get_player_by_name(name)` peut renvoyer `nil` (joueur parti). Les callbacks reçoivent parfois `nil` ou un objet non-joueur pour `player` / `placer` / `digger` (pistons, tubes, mods de machines). Toujours : `local name = player and player:get_player_name() or ""`.
- Les ItemStack sont des objets : `ItemStack(x)`, `stack:get_name()`, `:get_count()`, `:take_item(n)`, `:get_meta()`. Une copie modifiée doit être **réécrite** (`inv:set_stack(...)`, `return itemstack`).
- Métadonnées : `get_int/set_int`, `get_float/set_float`, `get_string/set_string`. `set_string(key, "")` **supprime** la clé. Pas de table directement : `core.serialize`/`core.deserialize` (ou `core.write_json`), avec parcimonie car c'est envoyé aux clients sauf `meta:mark_as_private(keys)`.
- `core.after` ne survit pas à un redémarrage et ne doit pas porter d'état de jeu. Pour la logique par node : **node timer** (persistant). Pour un état qui évolue dans le temps : horodatage (`core.get_gametime()`) + calcul à la demande.
- ABM = coût permanent sur tous les blocs actifs. À éviter sauf besoin réel (interval ≥ 10, chance élevée, `neighbors` restrictif ; `without_neighbors` seulement en 5.10+). LBM pour migrer/initialiser des nodes au chargement.
- Logs : `core.log("action"|"warning"|"error", "[cavepatate] ...")`. Pas de `print` dans le code livré.

## 3. Définition de node : antisèche

```lua
local S = cavepatate.S
local util = cavepatate.util

core.register_node(util.name("exemple"), {
	description = S("Example"),
	tiles = { util.tex("exemple_top"), util.tex("exemple_top"), util.tex("exemple_side"),
		util.tex("exemple_side"), util.tex("exemple_side"), util.tex("exemple_front") },
	-- ordre des tiles : +Y, -Y, +X, -X, +Z, -Z ; avec facedir la face « avant » (vers le joueur) est la 6e
	paramtype2 = "facedir",          -- orientation à la pose (avec on_place = core.rotate_node si besoin)
	is_ground_content = false,       -- OBLIGATOIRE pour un node construit (sinon les grottes du mapgen le creusent)
	groups = { choppy = 2, oddly_breakable_by_hand = 2 },
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos) end,                                   -- init meta/inventaire/timer
	after_place_node = function(pos, placer, itemstack, pointed_thing) end, -- propriétaire, etc.
	can_dig = function(pos, player) return true end,                    -- refuser si inventaire non vide
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing) end, -- doit renvoyer itemstack si modifié
	on_receive_fields = function(pos, formname, fields, sender) end,    -- formspec de meta "formspec"
	on_timer = function(pos, elapsed, node, timeout) end,               -- `node`/`timeout` : 5.14+ seulement ; renvoyer true = relancer
	allow_metadata_inventory_put = function(pos, listname, index, stack, player) return stack:get_count() end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player) return stack:get_count() end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player) return count end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player) end,
	on_destruct = function(pos) end,
	after_dig_node = function(pos, oldnode, oldmetadata, digger) end,
	preserve_metadata = function(pos, oldnode, oldmeta, drops) end,     -- garder la meta dans l'item lâché
	on_blast = function(pos, intensity) end,                            -- TNT : définir pour protéger le contenu
})
```

Groupes utiles : outils `cracky / choppy / snappy / crumbly / oddly_breakable_by_hand / dig_immediate` (1 = le plus dur), `flammable`, `not_in_creative_inventory = 1`, `wood = 1`, `stone = 1`, `food_*` (Farming Redo). Les groupes servent aussi dans les recettes : `"group:wood"`.

## 4. Pièges classiques à vérifier systématiquement

1. `is_ground_content = false` oublié sur un node construit.
2. Inventaire perdu au minage : `can_dig` doit refuser si `inv:is_empty("main")` est faux, ou bien lâcher le contenu dans `on_destruct`/`after_dig_node`.
3. Callbacks d'inventaire sans contrôle de protection (n'importe qui vide la cave).
4. `on_rightclick` qui ne renvoie pas `itemstack` après l'avoir modifié (duplication / perte).
5. Accès `player:...` sans vérifier que `player` est un vrai joueur (`player:is_player()`).
6. Modification de `core.registered_nodes[x]` directement au lieu de `core.override_item`.
7. Recette qui entre en conflit avec une recette existante (même motif). Vérifier dans les sources MTG/farming.
8. Texture référencée mais absente de `textures/` (le serveur ne le signale pas, le client affiche une texture manquante).
9. Formspec construit avec des chaînes non échappées : `core.formspec_escape(texte)`.
10. Travail lourd dans `globalstep` ou dans un ABM, au lieu d'un timer / d'un calcul paresseux.

## Mettre à jour la TOC (après remplacement de lua_api.md)

```bash
cd .claude/reference && awk '
/^```/ {f=!f; prev=""; next}
f {next}
/^={3,}$/ && prev!="" {print (NR-1)": # "prev; prev=""; next}
/^-{3,}$/ && prev!="" && prev !~ /^[*|-]/ {print (NR-1)": ## "prev; prev=""; next}
/^#{1,4} [^#]/ {print NR": "$0}
{prev=$0}' lua_api.md > lua_api.toc.txt
```
