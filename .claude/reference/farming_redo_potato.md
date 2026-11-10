# Farming Redo : la pomme de terre et ses dérivés (données vérifiées)

Source : codeberg.org/tenplus1/farming, commit `b9d6932` (7 nov. 2026), `farming.version = "20261019"`, `farming.mod = "redo"`.
**Minetest Game seul n'a PAS de pomme de terre** (son farming = blé + coton). Il faut Farming Redo, dont le nom de mod est aussi `farming` et qui remplace celui de MTG.

## Items

| Item | Fichier source | Obtention | Groupes | Consommation |
|---|---|---|---|---|
| `farming:potato` | `crops/potato.lua:11` | récolte de `farming:potato_4`, plants sauvages (mapgen) | `compostability=48, seed=2, food_potato=1` | `on_use` : 1 chance sur 3 de **−1 PV**, sinon +1. **C'est aussi la graine** (`on_place` plante `farming:potato_1`) |
| `farming:baked_potato` | `item_food.lua:1159` | cuisson `group:food_potato`, `cooktime = 10` | `eatable=6, flammable=2, food=2` | +6 |
| `farming:potato_salad` | `item_food.lua:859` | craft vertical : `group:food_cucumber` / `farming:baked_potato` / `group:food_bowl` | `eatable=10, flammable=2, food=2` | +10, rend `farming:bowl` |
| `farming:potato_omelet` | `item_food.lua:681` | `group:food_egg, group:food_potato, group:food_onion` / poêle, `group:food_bowl` | `compostability=65, eatable=6, …` | +6, rend un bol |
| `farming:spanish_potatoes` | `item_food.lua:670` | 2 patates + persil + œuf + farine + oignon + ail + bol + poêle | `compostability=65, eatable=8, …` | +8, rend un bol |
| `farming:samosa` | `item_food.lua:107` | `group:food_flour, group:food_potato, group:food_chili_powder` / huile / casserole → **2** | `compostability=55, eatable=6, …` | +6 |

Nodes de culture (ne se stockent pas) : `farming:potato_1` … `farming:potato_4` (4 stades, `drop = ""` sauf le dernier).
`farming.registered_plants["farming:potato"] = { crop = "farming:potato", seed = "farming:potato", steps = 4, … }`.
Les groupes `eatable`, `flammable`, `food` viennent de `farming.add_eatable(item, hp, type)` (`init.lua:717`).

## Cas particuliers à gérer

- **La patate peut être désactivée** : réglage `farming_potato = 0`, défaut `0.002` (`settingtypes.txt:38`). `crops/potato.lua` n'est alors pas chargé : `farming:potato` n'existe pas, mais les plats dérivés restent enregistrés. Leurs recettes à base de `group:food_potato` deviennent simplement infaisables.
- `farming:baked_potato` n'est enregistré que si `not farming.mcl`, donc pas sous MineClone/VoxeLibre.
- Alias de compatibilité : `farming_plus:potato_item` → `farming:potato`, `farming_plus:potato_seed` → `farming:potato`.
- Sous MineClone, Farming Redo ajoute `food_potato = 1` à `mcl_farming:potato_item`.
- Textures existantes réutilisables (dans le mod farming) : `farming_potato.png`, `farming_baked_potato.png`, `farming_potato_salad.png`, `farming_potato_omelet.png`, `farming_spanish_potatoes.png`, `farming_samosa.png`, `farming_potato_1..4.png`.

## Reconnaître une patate / un dérivé de façon robuste

```lua
local POTATO_DERIVATIVES = {      -- dérivés sans groupe dédié : liste explicite
	"farming:baked_potato", "farming:potato_salad", "farming:potato_omelet",
	"farming:spanish_potatoes", "farming:samosa",
}
-- `core.get_item_group(name, "food_potato") > 0` couvre la patate crue, y compris les alias et la variante MineClone.
```

## Revérifier après une mise à jour de Farming Redo

```bash
F=~/Library/Application\ Support/minetest/mods/farming    # emplacement une fois installé
grep -rhoE '"farming:[a-z_0-9]*potat[a-z_0-9]*"' --include='*.lua' "$F" | sort | uniq -c
grep -rn "group:food_potato\|farming:baked_potato" --include='*.lua' "$F"   # recettes qui consomment de la patate
```
