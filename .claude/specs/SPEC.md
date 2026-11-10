# SPEC : Cavepatate (v1 implémentée)

## Vision

De rares et **immenses caves** souterraines envahies par la pomme de terre, générées dans le monde normal entre **Y −5000 et −3000**. On y trouve de la roche-tubercule, des collines de chair de patate, des patates géantes, des arbres-tubercules, une flétrissure verdâtre et des ruines. L'esprit s'inspire de la *Poisonous Potato Update* de Minecraft, mais tout le contenu est original.
**Hors périmètre** : dimension, portail, mobs, contenu non-patate.
L'architecture de génération est calquée sur celle du mod Friandises du même auteur (`~/Documents/Friandises`).

## Génération (src/cave.lua, src/mapgen.lua)

- **Placement** : une cave au plus par cellule de 5000 nœuds (62,5 %). La grille est décalée d'une demi-cellule par rapport à Friandises, et toute cave qui chevaucherait une caverne de Friandises est supprimée. Le tirage est déterministe : `PcgRandom(graine du monde, cx, cz)`.
- **Forme** : ellipsoïde rx/rz de 120 à 200, ry de 68 à 82 (hauteur libre d'environ 100 à 120 nœuds, relevée de 50 à la demande de l'utilisateur), déformé par un bruit 3D (WARP 0,25). Coque `1 ≤ d < 1,25` (roche-tubercule veinée de patate et de chair), contamination progressive de la pierre jusqu'à `d < 1,6`.
- **Alignement** : le sol de base est placé 14 nœuds au-dessus du bas d'un chunk, pour que les grandes structures tiennent dans un seul chunk.
- **Sol** : `floor_base + bruit × 10` ; cuvettes noyées sous `floor_base − 3`. Pas de piliers naturels (retirés à la demande de l'utilisateur).
- **Sous-biomes** (bruits 2D) : Flétrissure (< −0,45), Râpures (bruit dédié > 0,5), Bosquet (> 0,2), Champs (le reste). Sentiers (|bruit| < 0,035) dans Champs et Bosquet.
- **Structures** (src/structures.lua) : elles n'écrivent jamais hors du chunk et réservent leur zone. Patates géantes, arbres-tubercules, stalagmites et stalactites, patates suspendues, rideaux de racines, silos effondrés (coffre), autels des germes, arène (une par cave : site le plus plat près du centre, construite par le seul chunk qui la contient, 2 coffres riches).
- **Petites décorations** : germes, plants `farming:potato_4`, tapis de pelures, racines et pointes au plafond.
- **Lumière** : cave **naturellement lumineuse**, sans bloc lumineux visible. Lumière invisible `cavepatate:cave_light` (niveau 14 par défaut) en grille serrée : une colonne sur deux en x et en z, un point à 2 nœuds au-dessus du sol (ou de l'eau) puis tous les 4 nœuds, décalé de 2 d'une colonne à l'autre ; la plupart des cases d'air sont au niveau 12 ou 13 (l'ancienne grille en quinconce tous les 8 nœuds donnait 9 à 11, jugé trop sombre). Posée après les structures, là où l'air est resté libre. Pas d'ambre (retiré à la demande de l'utilisateur).
- **Ambiance** (src/ambience.lua, réglage `cavepatate_cavity_ambience`) : dans une cave, ciel uni et brouillard jaune pâle `#e9d89a` commençant à 75 % de la distance de vue, saturation 1,1 ; tout est rendu à la sortie. L'utilisateur a trouvé une brume plus jaune et plus dense trop présente.
- **Butin** : marqueurs `cavepatate:loot` / `loot_rich` remplacés par un `default:chest` garni par un LBM (`run_at_every_load = true`).
- Les nœuds de la cave ont `is_ground_content = false`. Sinon les grottes de MTG creusent la coque à la jointure des chunks : un artefact constaté puis corrigé.

## Blocs : équivalents originaux de la Poisonous Potato Update

L'utilisateur tient à avoir **tous** les blocs de la dimension. Chacun a un équivalent original : nom, texture et forme sont les nôtres, avec le même rôle.

| Update (référence) | Cavepatate | Fichier |
|---|---|---|
| Potone (+ dalle, escalier, muret) | `tuberstone` (+ moellon, briques, formes) | nodes.lua, shapes.lua |
| Taterstone (+ formes) | `starchstone` (roche d'amidon) | nodes.lua, shapes.lua |
| Minerais de potone | `tuberstone_with_{coal,iron,copper,tin,gold,mese,diamond}` (les minerais MTG de la coque sont convertis) | nodes.lua |
| Minerai de patate empoisonnée (+ deepslate) | `tuberstone_with_blight` → `blighted_potato` | nodes.lua |
| Minerai de résine | `tuberstone_with_sap` → `toxic_sap` | nodes.lua |
| Peelgrass / corrompu | `peel_turf` / `blighted_peel_turf` | nodes.lua |
| Terre de pomme | `tuber_soil` | nodes.lua |
| Poison farmland (+ humide) | `tuber_farmland` / `_wet` (labourable, cultivable) | nodes.lua |
| Poison path | `tuber_path` | nodes.lua |
| Gravtater | `potato_gratings` (tombe, groupe sand) | nodes.lua |
| Potato bud | `tuber_spike` (wallmounted, blesse) | nodes.lua |
| Potato flower | `tuber_flower` (teinture violette) | nodes.lua |
| Weak / strong roots | `hanging_root` (« racine faible ») / `strong_root` | nodes.lua |
| Powerful potato | `mighty_potato` (fait pousser des racines robustes) | nodes.lua |
| Vicious potato | **non repris** : il attaque les joueurs, donc assimilé à un mob (refus de l'utilisateur) | — |
| Potato fruit (lumineux, empoisonne) | `tuber_fruit` | wood.lua |
| Floatato (nuage, posable dans le vide) | **retiré à la demande de l'utilisateur** (pas de nuages) | — |
| Floatater (vole quand activé) | `floatater` (s'élève au clic droit avec sa charge) | machines.lua |
| Ambre (bloc, cristaux, éclats) | **retiré à la demande de l'utilisateur** | — |
| Bloc de pelures corrompues | `blighted_peel_block` (animé, lumineux ; ne fait apparaître aucun mob) | blocks.lua |
| Blocs de pelures (16 couleurs) | `peel_block` + 15 teintes MTG | blocks.lua |
| Bloc de patate empoisonnée (+ 4 compressions) | `blighted_potato_block` + `_compressed/_double/_triple/_quadruple` | blocks.lua |
| Poisonous mashed potato (couches) | `blighted_mash` (leveled, pas de dégâts de chute, pas de saut) | blocks.lua |
| Poisonous potato head | `blighted_head` | blocks.lua |
| Baked / charred / expired potato bricks (+ formes) | `baked_brick` / `charred_brick` / `stale_brick` | blocks.lua, shapes.lua |
| Frying table | `fryer` | machines.lua |
| Poisonous potato cutter | `potato_slicer` | machines.lua |
| Potato refinery | `refinery` | machines.lua |
| Potato battery | `tuber_battery_off/on` | machines.lua |
| Pedestal | `pedestal` (décoratif) | machines.lua |
| Potato wood family (sprouts, stem, planks, leaves, pedicule, door, trapdoor, fence, gate, stairs, slab) | `tuber_sprout`, `tuber_stem`, `tuber_planks`, `tuber_leaves`, `tuber_pedicel`, porte, trappe, barrière, rambarde, portillon, formes | wood.lua |
| Objets : poisonous potato, slices, peels, sticks, hash browns, oils, toxic resin | `blighted_potato`, `blighted_slice`, `potato_peel`, `potato_sticks`, `fries`, `hash_brown`, `potato_oil`, `toxic_oil`, `toxic_sap` | items.lua |

**Non repris, avec la raison :**
- portail : exclu par l'utilisateur ;
- big brain : l'expérience n'existe pas dans MTG ;
- panneaux, boutons, plaques de pression : il n'y a pas d'API MTG pour les panneaux, et les autres demandent mesecons ;
- variante « inversée » de la pile : elle n'a de sens qu'avec un signal redstone/mesecons ;
- affichage d'un objet sur le piédestal ;
- mobs.

**Structures** : colisée → arène ; village → potagers, silos, autels ; ruined portatol → arche effondrée sans portail ; mineshaft → galerie ; geode → géode ; hash well → puits calciné.

**Biomes** : Fields → Champs, Arboretum → Bosquet, Corruption/Wasteland → Flétrissure, Hash → Râpures.

**More Blocks** : `stairsplus:register_all` pour roche-tubercule, briques de tubercule, roche d'amidon, les 3 briques de patate et les planches. Sans More Blocks, ce sont les escaliers et dalles de MTG.

## Mesures (Luanti 5.18, mapgen v7, graine de test)

Une cave complète se génère sans erreur. Coût de 100 à 420 ms par chunk de cave (moyenne 170 ms), environ 40 chunks par cave, dans le thread principal.

## Pistes pour la suite

- Passer en environnement mapgen (5.9+) pour ne plus bloquer le serveur pendant la génération.
- Un liquide « jus de patate vénéneuse » dans la Flétrissure.
- Des recettes et usages supplémentaires pour la chair de patate.
