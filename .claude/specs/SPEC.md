# SPEC : Cavepatate (v1 implémentée · v2 « hameaux et églises » à implémenter)

## Vision

De rares et **immenses caves** souterraines envahies par la pomme de terre, générées dans le monde normal entre **Y −5000 et −3000**. On y trouve de la roche-tubercule, des collines de chair de patate, des patates géantes, des arbres-tubercules, une flétrissure verdâtre et des ruines. L'esprit s'inspire de la *Poisonous Potato Update* de Minecraft, mais tout le contenu est original.
**Hors périmètre** : dimension, portail, mobs, contenu non-patate.
L'architecture de génération est calquée sur celle du mod Friandises du même auteur (`~/Documents/Friandises`).

## Génération (src/cave.lua, src/mapgen.lua)

- **Placement** (révisé le 2026-11-25 : « mon monde fait 10 000 blocs de chaque côté, 4 caves doivent s'y générer ») : une cave par cellule de 10 000 nœuds (chance 1), grille alignée sur 0. La carte de −10 000 à 10 000 en X et en Z contient donc **exactement 4 caves, une par quart**. Une cave qui chevaucherait une caverne de Friandises est déplacée dans sa cellule (16 essais) au lieu d'être supprimée. Vérifié sur deux graines (12345 et celle du monde de l'utilisateur), avec Friandises chargé : 4 caves entièrement dans la carte, la plus proche caverne de Friandises à plus de 1 600 nœuds. Au-delà de ±10 000 (le monde va jusqu'à ±31 007), les autres cellules ont aussi leur cave. Le tirage est déterministe : `PcgRandom(graine du monde, cx, cz)`.
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
- **Compatibilité caverealms** : caverealms décore aussi les chunks voisins déjà générés (champignons géants, vers luisants, stalactites), et ces décorations flottaient dans la cave. Le générateur passe désormais après caverealms et everness (dépendances optionnelles). Il garde une copie de la zone avant les autres mods, puis remet autour du chunk ce qu'ils y ont changé dans l'emprise des caves (méthode de paleocave). Vérifié par une génération headless (graine 12345, mapgen v7) : 175 nœuds caverealms et 338 de pierre flottaient avant la correction, aucun après.

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

**Structures** : colisée → arène ; village → hameaux de chaumières avec église (v2), potagers, silos, autels ; ruined portatol → arche effondrée sans portail ; mineshaft → galerie ; geode → géode ; hash well → puits calciné.

**Biomes** : Fields → Champs, Arboretum → Bosquet, Corruption/Wasteland → Flétrissure, Hash → Râpures.

**More Blocks** : `stairsplus:register_all` pour roche-tubercule, briques de tubercule, roche d'amidon, les 3 briques de patate et les planches. Sans More Blocks, ce sont les escaliers et dalles de MTG.

## v2 : hameaux et églises (choix de l'utilisateur, 2026-11-25)

Des **hameaux** de chaumières en briques de patate, chacun avec son **église**, intacts, meublés et déserts (pas de mobs). Les formes de **More Blocks** (pentes, escaliers, dalles, panneaux, micro-blocs) donnent les toits, les meubles et les détails. Plans et architecture originaux : aucun plan de village ou d'église de Minecraft n'est repris.

Décisions de l'utilisateur : des hameaux (pas de grand village), des églises, des chaumières en briques (pas de patates creusées), intactes et meublées. Le reste est tranché par les valeurs par défaut notées *(défaut)*.

### Placement

- **Toute cave a des hameaux** (précision de l'utilisateur : « une cave contient forcément des hameaux ») : 2 ou 3 par cave, tirage déterministe, maximum réglable de 1 à 3. Pas de maison isolée hors des hameaux. Vérifié sur les 122 caves d'une carte (graine 12345) : 65 en ont 2, 57 en ont 3.
- Chaque hameau tient **entier dans un chunk** et n'est construit que par ce chunk, comme l'arène. Son site est le centre d'un chunk, calculé par une fonction pure `cave.hamlet_sites(cav)` (bruits du sol seulement, mis en cache dans `cav`). Le hameau se construit donc à l'identique, quel que soit l'ordre de génération.
- Conditions du site *(défaut, assouplies à l'implémentation : avec un écart ≤ 8 et « tout au sec », aucune des 4 caves de la graine de test n'avait de site)* :
  - centre et au moins 3 coins sur 4 (à ±26) en Champs ou en Bosquet, ces points à moins de 0,7 en distance normalisée horizontale ;
  - place au moins 3 nœuds au-dessus du lac (les fondations comblent les mares) ;
  - écart de hauteur ≤ 16 sur l'emprise (chaque bâtiment est nivelé, à ±3 de la place) ;
  - tout le hameau dans le chunk en hauteur ;
  - pas dans le chunk de l'arène, ni dans un chunk voisin d'un autre hameau.

  Parmi les sites valides, on garde les plus plats, puis on les tire au sort.
- Emprise ≤ 64×64, centrée dans le chunk (8 nœuds de marge). Le sol de la cave est aligné à 14 nœuds au-dessus du bas d'un chunk, ce qui laisse la hauteur nécessaire au clocher.
- Le hameau est construit juste après l'arène et **réserve** son emprise : les grandes structures du sol l'évitent.

### Composition d'un hameau

```
        ┌───┐   ┌─────┐
        │ M │   │  M  │          M = chaumière (porte vers la place)
        └─┬─┘   └──┬──┘          É = église (clocher côté place)
   ┌──┐   ·········          ⌂ = puits      ¤ = lampadaire
   │M ├···· ¤ ⌂ ¤ ·····┌─────────┐   · = chemin     # = potager clos
   └──┘   ·········  É  ║ (nef)    │
     ###      │       └─────────┘
     ###    ┌─┴─┐
            │ M │
            └───┘
```

- **1 église et 3 chaumières**, une par côté d'une petite place, plus une quatrième chaumière dans un coin une fois sur deux. Au centre, un **bassin d'huile de friture** bordé de briques calcinées, autour d'une **patate monumentale** (5 de haut) coiffée d'un germe lumineux. Il remplace le puits à toit sur poteaux, que la revue jugeait trop proche du puits des villages de Minecraft. Autour, 4 **lampadaires** (poteau de barrière de tubercule surmonté d'un fruit de tubercule lumineux).
- **Chemins** de `tuber_path` de chaque porte jusqu'à la place, sur le relief.
- 1 ou 2 **potagers clos** (terre labourée humide, plants de patates si Farming Redo, barrière de tubercule et portillon) entre les maisons *(défaut)*.
- Les bâtiments des côtés ont leur plancher **au niveau de la place** : leur seuil touche son bord, sans marche. La revue avait relevé des portes perchées ou enterrées de 3 nœuds. Ceux des coins et les potagers suivent le sol naturel, à un nœud au plus de la place. Chacun repose sur une **fondation** : la roche d'amidon comble jusqu'au solide, et l'air est dégagé au-dessus, comme pour l'arène.
- La terre labourée humide des potagers sèche avec le temps, car l'huile n'est pas de l'eau pour Farming Redo. C'est assumé : les plants posés sont déjà mûrs.
- Les portes regardent vers la place. Les dispositions (nombre, places, orientations, variantes) sont tirées par un `PcgRandom` propre au site.

### Chaumière (3 à 4 par hameau)

- Plan rectangulaire, extérieur de 9 ou 11 (façade) sur 7 ou 9, un niveau sous un toit à deux pans dont le faîte court le long de la façade *(défaut)*.
- **Murs** : soubassement de roche d'amidon, murs en briques de patate cuite, poteaux d'angle et sablières en tige de tubercule. Variantes : murs en briques de patate rassise ou en planches de tubercule.
- **Toit** : pentes More Blocks (`slope`) avec un débord d'un nœud, faîtage (bloc plein + dalle), pignons en planches, cheminée en briques calcinées dans le mur du fond, entrait en tige couchée. Matériau tiré parmi briques calcinées, planches de tubercule et briques rassises.
- **Ouvertures** : porte de tubercule (mod `doors`), fenêtres en `default:glass` en façade, au fond et sur les pignons.
- **Meubles** : table (dalle retournée), 2 chaises (escaliers), tapis de pelures 3×3, friteuse (ou trancheuse, 1 fois sur 3) devant l'âtre, garde-manger (bloc de patates et bloc de pelures), fruit de tubercule pendu à l'entrait, **un coffre** (butin commun, marqueur `cavepatate:loot`). Écart : pas de `default:bookshelf`, car posée au VoxelManip, elle n'aurait ni inventaire ni formulaire.
- L'intérieur est éclairé par la lumière invisible de la cave, posée après les structures dans l'air resté libre. Il n'est jamais sombre.

### Église (1 par hameau)

- **Nef** : extérieur 10×15 (intérieur 8×13) en briques de roche-tubercule, 4 contreforts de chaque côté coiffés d'une pente, toit à deux pans en pentes de briques calcinées, vitrail dans le pignon du chevet.
- **Clocher** carré de 6×6 du côté de l'entrée, corniche à 14 à 16 nœuds et flèche au-dessus (environ 20 nœuds au total). Il a une chambre des cloches ouverte sur les 4 faces (arcs en escaliers retournés) et une **patate vigoureuse pendue à une racine** en guise de cloche. La flèche pyramidale alterne anneaux de pentes (angles en `slope_outer`) et assises pleines. Écart : la tour fait 6 de large pour centrer la porte double, donc la flèche se termine par 4 pentes d'angle et n'a pas de germe au sommet.
- **Intérieur** : allée centrale en tapis de pelures, 4 rangées de **bancs** en escaliers de planches de part et d'autre, chœur surélevé d'une marche (escaliers puis briques rassises), **autel** (2 piédestaux surmontés de germes lumineux), 2 germes aux angles du chœur. Fenêtres hautes et étroites en verre, avec appui et linteau en briques calcinées. Double porte de tubercule (battants `_a` et `_b`).
- **Un coffre riche** derrière l'autel (marqueur `cavepatate:loot_rich`).

### Formes et compatibilité

- Une fonction `shape(forme, matériau, orientation)` choisit le nœud : avec **More Blocks**, `cavepatate:<slope|stair|slab|panel|micro>_<matériau>[_variante]`, orienté en facedir. Sans More Blocks, les escaliers et dalles MTG déjà enregistrés par `shapes.lua` (`stairs:stair_cavepatate_<matériau>`), les pentes devenant des escaliers. Sans `stairs`, des blocs pleins (toit en gradins). Les hameaux se génèrent dans tous les cas.
- Sans le mod `doors` : une ouverture de 1×2 à la place de la porte (portillon de potager omis). Sans Farming Redo : potagers sans plants.
- Matériaux de More Blocks utilisés : `tuberstone_brick`, `starchstone`, `baked_brick`, `charred_brick`, `stale_brick`, `tuber_planks` (tous déjà enregistrés par `shapes.lua`).
- **Aucun nouveau bloc** ni texture.
- Code dans un nouveau fichier `src/hamlets.lua`, chargé après `structures.lua`. Il réutilise ses outils (`fits`, `put`, `put_air`, `reserve`, exposés sur `st`). `structures.lua` fait déjà près de 800 lignes.

### Réglage

- `cavepatate_cavity_hamlets` (Hamlets per potato cave) int 3, de 1 à 3 : nombre maximal de hameaux par cave (au moins un).

### Commande

- La commande s'appelle **`/cavepatate`** (et non plus `/patate`), sans paramètre : coordonnées du centre de la cave la plus proche, privilège `teleport`. Pas de sous-commande pour les hameaux : chaque cave en contient (décision de l'utilisateur).

### Critères d'acceptation

1. `lint.sh` et `load_test.sh` passent, avec et sans More Blocks, et sans `doors`. `update_translations.py --check` passe.
2. Dans un nouveau monde, chaque cave contient 2 ou 3 hameaux, avec chacun 1 église et 3 ou 4 chaumières.
3. Aucun bâtiment n'est coupé à une jointure de chunk, ne flotte ou n'est enterré. Aucune autre structure (arbre, patate géante, stalagmite) ne chevauche un hameau.
4. Les portes s'ouvrent, les coffres sont garnis à la première visite et les toits sont continus (pentes bien orientées, coins compris). À l'intérieur, la lumière est d'au moins 12.
5. Sans More Blocks, le hameau se génère avec des escaliers MTG, sans erreur.
6. La génération d'un chunk de hameau coûte au plus 100 ms de plus qu'un chunk de cave ordinaire.

### Résultats (2026-11-25, Luanti 5.14 Windows, mapgen v7, graine 12345)

- Génération headless de la cave (545, −4706, −3211), avec le placement à 4 caves : **2 hameaux** complets. Chacun a son église (clocher, flèche, cloche, bancs, autel, coffre riche) et 4 chaumières meublées (la quatrième dans un coin). On compte aussi les potagers, la place avec son bassin et sa patate monumentale, les 4 lampadaires et les chemins. Vérifié en vue de dessus et en coupes ASCII ; les portes des côtés sont au niveau de la place.
- Sans More Blocks : mêmes hameaux en escaliers et dalles MTG, sans erreur.
- Chunks de hameau : 152 à 184 ms ; moyenne des chunks de cave : 108 ms. Le critère 6 est tenu (au plus +76 ms).
- Deux générations du même monde donnent les mêmes nombres de nœuds (déterminisme).
- `/cavepatate` testée avec un faux joueur, réponse traduite en français.
- `update_translations.py --check` passe (Python 3.10 est disponible sous `python`). `load_test.sh` passe, avec et sans More Blocks.
- **Non vérifié** :
  - lint (ni luacheck ni LuaJIT sur la machine) ; l'agent de revue a contrôlé l'équilibre des blocs et l'absence de globales ;
  - cas « sans `doors` » (mod du jeu, non désactivable ici ; le code retombe sur une ouverture) ;
  - critère 4 en jeu (portes, coffres garnis, lumière ≥ 12, aspect des toits) : à vérifier dans un nouveau monde.

## v2 bis : huile de friture à la place de l'eau (demande de l'utilisateur, 2026-11-25)

- Nouveau liquide `cavepatate:frying_oil_source` / `_flowing` (« Source d'huile de friture », « Huile de friture qui coule »), dans `src/nodes.lua`.
- Textures : eau de Minetest Game teintée dorée (`^[colorize:#e8b032:185`), voile `post_effect_color` doré. Pas de nouvelle texture, faute de Python pour `pixelart.py`.
- Propriétés *(défaut)* : froide (aucun dégât), épaisse (`liquid_viscosity` 4, portée 4), on peut s'y noyer, non renouvelable, `is_ground_content = false`. Elle ne fait pas partie du groupe `water` : elle ne mouille pas les terres labourées et n'éteint rien.
- Seau d'huile de friture (`cavepatate:bucket_frying_oil`) si le mod `bucket` est là (dépendance optionnelle ajoutée).
- Tout ce qui était de l'eau dans les caves devient de l'huile : les lacs (cuvettes sous `water_level`), les rigoles des potagers, les puits calcinés et le puits des hameaux. Dans le code, `c.water` devient `c.oil`.
- **Liquides étrangers** : les grandes grottes inondées du moteur, générées dans un chunk voisin, débordaient d'eau ou de lave dans une cave déjà creusée. On l'a constaté avec 21 nœuds d'eau qui coulaient à une jointure de chunks. Désormais, autour du chunk, tout liquide étranger trouvé dans le creux de la cave devient de l'air, ou de l'huile sous le niveau du lac (`clean_edges` + `in_hollow` dans `mapgen.lua`). Vérifié : plus aucun nœud étranger dans l'air de la cave.

## Mesures (Luanti 5.18, mapgen v7, graine de test)

Une cave complète se génère sans erreur. Coût de 100 à 420 ms par chunk de cave (moyenne 170 ms), environ 40 chunks par cave, dans le thread principal.

## Pistes pour la suite

- Passer en environnement mapgen (5.9+) pour ne plus bloquer le serveur pendant la génération.
- Un liquide « jus de patate vénéneuse » dans la Flétrissure.
- Des recettes et usages supplémentaires pour la chair de patate.
