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
- Blocs de terrain (roches, sols, tourbes, purée) : **grain fin à faible contraste**, à la manière de MTG (helper `natural()` de `_generate.py`), sans motif isolé reconnaissable (coulures, « yeux » contrastés, glyphes, points colorés) : répété tous les 16 nœuds, il fait ressortir la grille et paraît artificiel (rejeté par l'utilisateur). Vérifier en mosaïque 6×6. Les motifs marqués sont réservés aux blocs posés à la main (briques, machines, objets).
- Les blocs pleins doivent **raccorder** sur les 4 bords (vérifier en mosaïque).
- Palette du thème : **vive, chaude et saturée**, dans l'esprit de l'update (l'utilisateur a rejeté des textures
  ternes et grisâtres). Pas de gris ni de beige délavé pour les blocs de la cave. Palettes de référence dans
  `.claude/textures_src/_generate.py` :
  - roche-tubercule : ocres dorés (`#6e4c1c` … `#e8c76c`), petits « yeux » de patate plus sombres
  - roche d'amidon / chair de patate : crème et jaune (`#c4a464` … `#fff6d2`)
  - pelures, tourbe, briques cuites : orangés et dorés (`#8a5418` … `#fde29a`)
  - empoisonné / flétri : verts vénéneux saturés (`#264a12` … `#b6ea58`), touches violettes franches (`#7a2a8c`)
  - corrompu : violets profonds et étincelles roses (`#26103a` … `#ff6cff`)
  - bois et feuilles : vert-jaune et vert vif (`#3c4a12` … `#b4d04c`, `#1e5414` … `#84d448`)
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
