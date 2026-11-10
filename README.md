# Cavepatate: potato caves for Luanti

Mod for [Luanti](https://www.luanti.org) / Minetest Game that generates huge underground **potato caves**, in the spirit of Minecraft's *Poisonous Potato Update*. Everything is original: no dimension, no portal, no mobs, and none of that game's names, textures or structure layouts.

## What it generates

Lens-shaped caverns about 240 to 400 nodes wide, with 100 to 120 nodes of open height, entirely between Y = -5000 and Y = -3000. The caves are **naturally bright**: an invisible light fills them evenly. Inside, the distance fades into a light golden haze and colours are slightly more vivid (restored when you leave).

- A **tuberstone shell** veined with starchstone, potato and ores seals each cave. Minetest Game ores found there turn into tuberstone ores, alongside **blighted potato ore** and **toxic sap ore**.
- Four areas:
  - **Fields**: peel turf, flowers, wild potatoes, paths, abandoned farm plots and peel mounds.
  - **Grove**: tuber trees with glowing fruits.
  - **Blight**: blighted peel turf, spike clusters, corrupted peel blocks and blighted mash pools.
  - **Gratings**: shredded potato that falls like sand, green peel "cacti" and charred wells.
- Floor features: lakes, giant half-buried potatoes, stalagmites.
- Ceiling features: stalactites, potatoes hanging by their roots and mighty potatoes.
- Ruins:
  - collapsed silos, sprout shrines and ruined arches;
  - tuber mineshafts dug under the floor;
  - blighted potato geodes;
  - one **buried colosseum** per cave, in baked, stale and charred potato bricks.

  Silos, mineshafts and the colosseum hold chests.

`/patate` (requires the `teleport` privilege) shows the coordinates of the nearest cave's centre.

## Blocks and items

- **Stone**: tuberstone (+ rubble, bricks), blighted tuberstone, starchstone, 7 tuberstone ores, blighted potato ore, toxic sap ore.
- **Ground**: tuber soil, peel turf, blighted peel turf, tuber farmland (hoe it; crops grow on it), tuber path, potato gratings (falls).
- **Potato blocks**: block of potatoes, potato flesh, blighted potato block plus 4 compression tiers, blighted mashed potato (layers that cancel fall damage and stop jumps), blighted potato head.
- **Peels**: peel block in natural colour plus the 15 Minetest Game dye colours, corrupted peel block (sparkles), peel carpet.
- **Bricks**: baked, charred and stale potato bricks.
- **Plants**: weak root, strong root, mighty potato (grows strong roots when placed), tuber spike, tuber flower (violet dye), glowing sprout.
- **Tuber wood** (pale green stems, does not burn): stem, planks, leaves, sprout (grows into a tree), glowing fruit, pedicel, door, trapdoor, fence, fence rail, fence gate.
- **Functional blocks**:
  - **fryer**: potato sticks → fries, peels → hash browns, potato → baked potato;
  - **potato slicer**: potato → 4 sticks + 1 peel, blighted potato → 3 slices;
  - **potato refinery**: 4 potatoes (+ a bottle) → potato oil, 4 blighted potatoes → toxic oil;
  - **potato battery**: right-click toggles it; when on, it glows and shocks whoever stands on it;
  - **pedestal**;
  - **floating tuber**: right-click and it rises up to 32 nodes, carrying up to 8 blocks stacked on it;
- **Items**: blighted potato, blighted slice, potato peel, raw potato sticks, fries, hash brown, potato oil, toxic oil, toxic sap.

Stone, bricks and planks come as stairs and slabs, or with **More Blocks** in every Stairs+ shape and on the circular saw. They also come as walls.

## Settings (`settingtypes.txt`)

| Setting | Default | Effect |
|---|---|---|
| `cavepatate_cavity_chance` | 0.625 | Probability that a cell contains a cave |
| `cavepatate_cavity_cell_size` | 5000 | Cell size in nodes (one cave at most per cell) |
| `cavepatate_cavity_ymin` / `ymax` | -5000 / -3000 | Depth range (the whole cave stays inside) |
| `cavepatate_cavity_align` | true | Aligns each cave floor on map chunks so large structures fit |
| `cavepatate_cavity_features` | 20 | Large feature attempts per map chunk, on the floor and on the ceiling |
| `cavepatate_cavity_light` | 14 | Light level of the invisible light filling the caves (14 = brightest, 0 = only glowing plants and blocks) |
| `cavepatate_cavity_ambience` | true | Light golden haze and slightly more vivid colours inside the caves |

## Dependencies

`default` and `farming` (made for [Farming Redo](https://codeberg.org/tenplus1/farming), which provides potatoes). Optional: `stairs`, `walls`, `doors`, `dye`, `vessels`, `moreblocks`, and `friandises` (potato caves never overlap its candy cavities). Requires Luanti 5.8 or later; tested with Luanti 5.18.
