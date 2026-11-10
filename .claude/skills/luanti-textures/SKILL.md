---
name: luanti-textures
description: Création de textures pixel art 16×16 originales au style Minetest Game pour les blocs et items du mod cavepatate (roche-patate, blocs de patate, patate empoisonnée, racines, germes…), avec l'outil pixelart.py (sources .px texte → PNG, aperçu agrandi et en mosaïque, extraction de palette). À utiliser dès qu'un node ou un item a besoin d'une texture, ou pour retoucher/vérifier une texture.
---

# Textures

## Outil

```bash
PA=".claude/skills/luanti-textures/scripts/pixelart.py"
python3 $PA build .claude/textures_src/                        # toutes les sources .px -> textures/*.png
python3 $PA build .claude/textures_src/cavepatate_x.px          # une seule
python3 $PA preview textures/cavepatate_x.png --tile 3          # aperçu x16, en mosaïque 3×3 -> chemin affiché
python3 $PA palette "<chemin>/default_stone.png"                # couleurs et luminance d'une texture
python3 $PA extract "<chemin>/default_stone.png" --out /tmp/stone.px   # partir d'une palette MTG
```

Toujours **regarder l'aperçu** (outil Read sur le PNG produit) avant de valider. La mosaïque 3×3 révèle les raccords visibles et les motifs trop répétitifs.

Sources (`.px`) : `.claude/textures_src/<nom_de_la_texture>.px`. Le nom du fichier = le nom du PNG produit dans `textures/`. Format :

```
. = transparent
a = #6b5a3c
b = #8a7550
c = #a89060

aaaabbbbccccbbba        <- 16 lignes de 16 caractères
...
```

Les commentaires `#` ne doivent pas contenir ` = `.

## Direction artistique

- **Originalité obligatoire** : aucune texture copiée ou décalquée de Minecraft ni d'un autre jeu. On peut partir d'une palette MTG (licence CC BY-SA 3.0) mais le dessin est le nôtre.
- 16×16, sans anti-aliasing, 4 à 8 couleurs par texture, ombrage du haut-gauche vers le bas-droit comme dans MTG.
- Lisible à distance : un motif principal fort plus 2 ou 3 détails. Pas de bruit aléatoire pixel par pixel.
- Les blocs pleins doivent **raccorder** sur les 4 bords (vérifier en mosaïque).
- Palette du thème (à affiner dans la spec) :
  - roche-patate : ocres et beiges terreux (`#5e4a2e` … `#b39a6b`), petits « yeux » de patate plus sombres
  - chair de patate / pelée : crème et jaune pâle (`#d9c58f` … `#f2e4b5`)
  - pelures : bruns (`#6b4a2a` … `#9c7344`)
  - empoisonné / corrompu : verts maladifs et olive (`#4f6b2a` … `#a3c14a`), touches violacées discrètes
  - racines et tiges : bruns rougeâtres et verts sombres
- Plantes et cristaux (`plantlike`) : fond transparent, silhouette centrée, base touchant le bas de l'image.

## Nommage et faces

- `cavepatate_<bloc>.png` pour un bloc uniforme. Sinon `cavepatate_<bloc>_top.png`, `_side.png`, `_bottom.png`, `_front.png`.
- Ordre des `tiles` d'un node : +Y (dessus), −Y (dessous), +X, −X, +Z, −Z. Avec `facedir`, l'avant est la 6e.
- Items : `cavepatate_<item>.png` en `inventory_image`.
- Les textures de Farming Redo existantes peuvent être réutilisées telles quelles (ex. `farming_potato.png`) si le mod est présent. Ne pas les dupliquer dans `textures/`.

## Checklist avant de terminer

1. `build` sans erreur, et chaque PNG référencé dans le code existe dans `textures/` :
   `grep -rhoE 'cavepatate_[a-z0-9_]+\.png' init.lua src | sort -u | while read t; do [ -f textures/$t ] || echo "MANQUANTE $t"; done`
   Les noms produits par `util.tex("x")` ne contiennent pas « .png » littéral : vérifier aussi les appels `util.tex(`.
2. Aperçu en mosaïque regardé : pas de raccord visible, contraste suffisant.
3. Cohérence avec les textures voisines du thème (même palette, même lumière).
