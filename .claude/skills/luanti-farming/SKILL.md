---
name: luanti-farming
description: Intégration de la pomme de terre de Farming Redo dans le mod cavepatate — noms exacts des items patate et dérivés (baked_potato, potato_salad, potato_omelet, spanish_potatoes, samosa), groupe food_potato, détection de Farming Redo, cas où la patate est absente ou désactivée, recettes et conflits. À utiliser dès qu'on référence un item de farming, qu'on filtre les items acceptés par une cave, ou qu'on ajoute une recette/un dérivé de la patate.
---

# Pomme de terre (Farming Redo)

**Périmètre du mod : uniquement la pomme de terre et ses dérivés.** Aucun autre légume ni aliment.

Données vérifiées (noms, groupes, recettes, numéros de ligne) : `.claude/reference/farming_redo_potato.md`. **Lire ce fichier avant d'écrire du code qui touche aux patates.** API générale de Farming Redo : `.claude/reference/farming_redo_api.txt`.

## Faits essentiels

- Minetest Game seul **n'a pas** de patate. Il faut **Farming Redo** (mod `farming`, `farming.mod == "redo"`), qui remplace le farming de MTG.
- `farming:potato` = patate crue **et** graine. Groupe `food_potato = 1`. La manger crue peut empoisonner (1 chance sur 3, −1 PV).
- Dérivés existants : `farming:baked_potato` (four), `farming:potato_salad`, `farming:potato_omelet`, `farming:spanish_potatoes`, `farming:samosa`. Ils n'ont **pas** de groupe dédié, d'où une liste explicite.
- La patate peut être **désactivée** (`farming_potato = 0`). Le mod doit alors se charger sans erreur et dégrader proprement.

## Règles d'intégration

1. `mod.conf` : `optional_depends = farming` (déjà en place). Farming est ainsi chargé avant cavepatate, et ses items existent au moment où nos fichiers s'exécutent.
2. Détection, déjà faite dans `init.lua` : `cavepatate.farming_redo` (bool). Pour un item précis : `cavepatate.util.item_exists("farming:potato")`.
3. **Jamais** de recette, d'alias ou de liste qui référence un item farming sans vérifier qu'il existe :
   ```lua
   if util.item_exists("farming:baked_potato") then
   	core.register_craft({ ... })
   end
   ```
4. Reconnaître une patate : `core.get_item_group(name, "food_potato") > 0`. Cela couvre les alias et MineClone. Pour les dérivés : table de correspondance construite au chargement à partir de la liste, en ne gardant que les items qui existent.
5. Si Farming Redo est absent ou la patate désactivée : `core.log("warning", "[cavepatate] ...")` une seule fois, puis ne pas enregistrer les contenus qui dépendent de la patate. Pas d'erreur fatale.
6. Ne pas modifier les items de farming. Si c'est vraiment nécessaire : `core.override_item("farming:potato", { ... })` en **fusionnant** les groupes existants (`table.copy(def.groups)`) et en le documentant dans la spec.
7. Nouveaux dérivés créés par cavepatate (`cavepatate:...`) : `groups = { food_potato = ? }` uniquement s'il s'agit vraiment d'une patate crue, sinon d'autres mods la traiteraient comme une graine ou un ingrédient. Pour un aliment : `on_use = core.item_eat(hp)` et, si Farming Redo est présent, `farming.add_eatable(name, hp)` pour la cohérence avec les autres mods.
8. **Conflits de recettes** : avant d'ajouter une recette qui utilise patates ou dérivés, vérifier qu'aucun motif identique n'existe déjà (`grep -rn "group:food_potato\|farming:baked_potato" <mod farming>`). La cuisson de `group:food_potato` donne déjà `farming:baked_potato` : ne pas définir une autre cuisson de la patate crue.

## Tester avec Farming Redo

Farming Redo doit être installé dans `~/Library/Application Support/minetest/mods/farming`. Ajouter `farming` dans `.claude/test_mods.txt` : le test de chargement et le monde de dev l'activent alors, et il remplace le farming de MTG. Tester aussi **sans** lui (ligne commentée), pour vérifier la dégradation propre.
