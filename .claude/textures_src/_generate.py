#!/usr/bin/env python3
"""Génère les sources .px (16×16) des textures originales de cavepatate.

Les .px produits sont ensuite retouchables à la main, puis compilés par :
    python3 .claude/skills/luanti-textures/scripts/pixelart.py build .claude/textures_src
Relancer ce script ÉCRASE les .px : ne le faire que pour repartir de zéro.
"""

import math
import os
import random

W = 16
OUT = os.path.dirname(os.path.abspath(__file__))


# ----------------------------------------------------------------- outils

def value_noise(seed, cells):
    """Bruit de valeur raccordable (tileable) 16×16, cellules `cells`×`cells`."""
    r = random.Random(seed)
    g = [[r.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * W for _ in range(W)]
    for y in range(W):
        for x in range(W):
            fx, fy = x * cells / W, y * cells / W
            x0, y0 = int(fx), int(fy)
            tx, ty = fx - x0, fy - y0
            sx, sy = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            a = g[y0 % cells][x0 % cells]
            b = g[y0 % cells][(x0 + 1) % cells]
            c = g[(y0 + 1) % cells][x0 % cells]
            d = g[(y0 + 1) % cells][(x0 + 1) % cells]
            out[y][x] = (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy
    return out


def fbm(seed, weights=((2, 0.45), (4, 0.35), (8, 0.2))):
    layers = [(value_noise(seed + i * 101, c), w) for i, (c, w) in enumerate(weights)]
    return [[sum(l[y][x] * w for l, w in layers) for x in range(W)] for y in range(W)]


def quantize(n, thresholds, symbols):
    """thresholds croissants ; len(symbols) = len(thresholds) + 1."""
    out = []
    for row in n:
        line = []
        for v in row:
            i = 0
            while i < len(thresholds) and v > thresholds[i]:
                i += 1
            line.append(symbols[i])
        out.append(line)
    return out


def blank(sym="."):
    return [[sym] * W for _ in range(W)]


def setp(g, x, y, s):
    g[y % W][x % W] = s


def save(name, palette, grid):
    lines = [f"# {name} — généré par _generate.py (original, CC BY-SA 3.0)"]
    lines += [f"{k} = {v}" for k, v in palette.items()]
    lines.append("")
    lines += ["".join(row) for row in grid]
    with open(os.path.join(OUT, name + ".px"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("écrit", name + ".px")


def eyes(g, positions, dark, light):
    """Yeux de patate : creux sombre avec un liseré clair en bas à droite."""
    for x, y in positions:
        setp(g, x, y, dark)
        setp(g, x + 1, y, dark)
        setp(g, x, y + 1, light)
        setp(g, x + 1, y + 1, light)
        setp(g, x - 1, y, light)


def natural(seed, symbols, shares, weights=((8, 0.55), (16, 0.45)), grain=0.25):
    """Grain fin à la Minetest Game : bruit multi-échelle + grain par pixel, découpé en
    tons selon des proportions (`shares`, une par symbole) pour éviter les grosses taches
    qui font ressortir la grille des blocs."""
    r = random.Random(seed * 7 + 3)
    n = fbm(seed, weights)
    vals = [[n[y][x] + grain * r.random() for x in range(W)] for y in range(W)]
    flat = sorted(v for row in vals for v in row)
    cuts, acc = [], 0.0
    for sh in shares[:-1]:
        acc += sh
        cuts.append(flat[min(len(flat) - 1, int(acc * len(flat)))])
    return quantize(vals, cuts, symbols)


def sprinkle(g, seed, sym, count, only=None):
    """Pixels isolés (jamais côte à côte) : accents discrets répartis sur le bloc."""
    r = random.Random(seed)
    placed, tries = 0, 0
    while placed < count and tries < 500:
        tries += 1
        x, y = r.randrange(W), r.randrange(W)
        if only and g[y][x] not in only:
            continue
        if any(g[(y + dy) % W][(x + dx) % W] == sym for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        g[y][x] = sym
        placed += 1
    return g


# ----------------------------------------------------------------- roches

def stone_like(seed, palette, eye_dark, eye_light, eye_pos):
    g = quantize(fbm(seed), [0.36, 0.47, 0.58, 0.66], "abcde")
    eyes(g, eye_pos, eye_dark, eye_light)
    return g


TUBER = {"a": "#b4820c", "b": "#c4921a", "c": "#d2a226", "d": "#deb034", "e": "#e8be44", "f": "#986a0a"}
g = natural(11, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), weights=((8, 0.6), (16, 0.4)))
sprinkle(g, 12, "f", 5, only="ab")
save("cavepatate_tuberstone", TUBER, g)

BLIGHT = {"a": "#304e1a", "b": "#395c1e", "c": "#426a24", "d": "#4c7829", "e": "#57862f", "f": "#2a4614"}
g = natural(23, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), weights=((8, 0.6), (16, 0.4)))
sprinkle(g, 24, "f", 5, only="ab")
save("cavepatate_tuberstone_blighted", BLIGHT, g)


def rubble(seed, pal_syms="bcd"):
    r = random.Random(seed)
    pts = [(r.uniform(0, W), r.uniform(0, W), r.choice(pal_syms)) for _ in range(7)]

    def nearest(x, y):
        best, bd = 0, 1e9
        for i, (px, py, _) in enumerate(pts):
            dx = min(abs(x - px), W - abs(x - px))
            dy = min(abs(y - py), W - abs(y - py))
            d = dx * dx + dy * dy
            if d < bd:
                best, bd = i, d
        return best

    cell = [[nearest(x + 0.5, y + 0.5) for x in range(W)] for y in range(W)]
    g = blank()
    for y in range(W):
        for x in range(W):
            i = cell[y][x]
            border = cell[(y + 1) % W][x] != i or cell[y][(x + 1) % W] != i
            top_left = cell[(y - 1) % W][x] != i or cell[y][(x - 1) % W] != i
            g[y][x] = "a" if border else ("e" if top_left else pts[i][2])
    return g


save("cavepatate_tuberstone_rubble", TUBER, rubble(37))


def bricks(seed):
    n = fbm(seed)
    g = blank()
    for y in range(W):
        row, ry = y // 4, y % 4
        off = (row % 2) * 4
        for x in range(W):
            bx = (x + off) % 8
            if ry == 3 or bx == 7:
                g[y][x] = "a"
            elif ry == 0 or bx == 0:
                g[y][x] = "e"
            elif ry == 2:
                g[y][x] = "b" if n[y][x] < 0.5 else "c"
            else:
                g[y][x] = "d" if n[y][x] > 0.55 else "c"
    return g


save("cavepatate_tuberstone_brick", TUBER, bricks(41))

# ----------------------------------------------------------------- patates

SKIN = {"a": "#94600c", "b": "#be8a1a", "c": "#ca9824", "d": "#d6a62e", "e": "#e0b43a", "f": "#e8c24a"}
g = natural(53, "bcdef", (0.10, 0.25, 0.30, 0.25, 0.10))
sprinkle(g, 54, "a", 5, only="cd")
save("cavepatate_potato_block", SKIN, g)

FLESH = {"a": "#e0b430", "b": "#eac43e", "c": "#f0d050", "d": "#f6dc66", "e": "#fae680", "f": "#fdf0a4"}
g = natural(61, "bcdef", (0.10, 0.25, 0.30, 0.25, 0.10), grain=0.2)
sprinkle(g, 62, "a", 4, only="cd")
save("cavepatate_potato_flesh", FLESH, g)

ROT = {"a": "#3a6e1c", "b": "#447e22", "c": "#4e8c28", "d": "#58992e", "e": "#62a634", "f": "#6cb23a",
       "g": "#86c64c"}
g = natural(71, "bcdef", (0.10, 0.25, 0.30, 0.25, 0.10))
sprinkle(g, 72, "a", 4, only="bc")
sprinkle(g, 73, "g", 4, only="ef")
save("cavepatate_blighted_potato_block", ROT, g)

# Tapis de pelures : lanières recourbées, fond transparent
PEEL = {".": "transparent", "a": "#9a5c0e", "b": "#b8741a", "c": "#d08e26", "d": "#e2a836", "e": "#f6d26a"}
g = blank()
r = random.Random(81)
for _ in range(15):
    x, y = r.uniform(0, W), r.uniform(0, W)
    ang = r.uniform(0, 2 * math.pi)
    turn = r.uniform(-0.35, 0.35)
    for step in range(r.randint(7, 12)):
        ix, iy = int(x) % W, int(y) % W
        g[iy][ix] = r.choice("bcd")
        nx, ny = int(x + math.cos(ang + 1.57)) % W, int(y + math.sin(ang + 1.57)) % W
        if g[ny][nx] == ".":
            g[ny][nx] = "e" if step % 3 else "a"
        x += math.cos(ang)
        y += math.sin(ang)
        ang += turn
save("cavepatate_peel_carpet", PEEL, g)

# ----------------------------------------------------------------- végétation

ROOT = {".": "transparent", "a": "#9a7420", "b": "#c49c34", "c": "#e0bc52", "d": "#f4da84"}
g = blank()
r = random.Random(101)
for start in (3, 8, 12):
    x = start
    for y in range(W):
        g[y][x % W] = "b"
        if x + 1 < W and g[y][x + 1] == ".":
            g[y][x + 1] = "a"
        if r.random() < 0.15 and 0 < x - 1:
            g[y][x - 1] = "d"
        if r.random() < 0.3:
            x = max(1, min(W - 2, x + r.choice((-1, 1))))
    g[W - 1][x % W] = "c"
save("cavepatate_hanging_root", ROOT, g)

SPROUT = {".": "transparent", "a": "#6b4a2e", "b": "#b8cc8a", "c": "#e2edc0", "e": "#fff6a8", "f": "#e4a8f0"}
g = blank()
for x in range(5, 11):
    g[15][x] = "a"
for x in range(6, 10):
    g[14][x] = "a"
for sx, h, lean in ((7, 9, -0.25), (9, 7, 0.3), (5, 5, -0.4), (11, 6, 0.4)):
    x = float(sx)
    for k in range(h):
        y = 13 - k
        ix = int(round(x))
        if 0 <= ix < W:
            g[y][ix] = "c" if k % 2 else "b"
        x += lean
    tip = int(round(x - lean))
    for dx, dy, s in ((0, 0, "e"), (-1, 0, "f"), (1, 0, "f"), (0, -1, "e")):
        if 0 <= tip + dx < W and 0 <= 13 - h + 1 + dy < W:
            g[13 - h + 1 + dy][tip + dx] = s
save("cavepatate_glow_sprout", SPROUT, g)

STEM = {"a": "#78a636", "b": "#8cba42", "c": "#a2cc50", "d": "#bade66", "e": "#d4ee8c"}
cols = value_noise(111, 8)
g = blank()
r = random.Random(112)
for y in range(W):
    for x in range(W):
        v = cols[0][x] * 0.7 + r.random() * 0.3
        g[y][x] = "b" if v < 0.35 else ("c" if v < 0.6 else "d")
    if x == 0:
        pass
for x in range(W):
    if cols[0][x] > 0.75:
        for y in range(W):
            g[y][x] = "e" if (y + x) % 5 else "d"
    if cols[0][x] < 0.2:
        for y in range(W):
            g[y][x] = "a"
for kx, ky in ((4, 5), (11, 12)):
    setp(g, kx, ky, "a")
    setp(g, kx + 1, ky, "a")
    setp(g, kx, ky - 1, "e")
save("cavepatate_tuber_stem", STEM, g)

g = blank()
for y in range(W):
    for x in range(W):
        d = math.hypot(x - 7.5, y - 7.5)
        if d > 6.6:
            g[y][x] = "a" if (x + y) % 2 else "b"
        elif d > 5.6:
            g[y][x] = "b"
        elif d < 1.2:
            g[y][x] = "e"
        else:
            g[y][x] = "d" if int(d * 1.3) % 2 else "c"
save("cavepatate_tuber_stem_top", STEM, g)

PLANK = {"a": "#b8800c", "b": "#cc9418", "c": "#dca624", "d": "#e8b834", "e": "#f2c84a"}
grain = fbm(121, ((2, 0.3), (8, 0.7)))
g = blank()
for y in range(W):
    for x in range(W):
        if y % 4 == 3:
            g[y][x] = "a"
        elif y % 4 == 0:
            g[y][x] = "e" if grain[y][x] > 0.45 else "d"
        else:
            v = grain[y][(x * 1) % W]
            g[y][x] = "b" if v < 0.4 else ("c" if v < 0.6 else "d")
for y, x in ((1, 5), (6, 12), (9, 2), (13, 9)):
    setp(g, x, y, "a")
save("cavepatate_tuber_planks", PLANK, g)

LEAF = {".": "transparent", "a": "#1e5414", "b": "#2c761c", "c": "#3e9826", "d": "#58b832",
        "e": "#84d448", "f": "#f6dcff", "g": "#ffe040"}
g = quantize(fbm(131), [0.36, 0.46, 0.56, 0.64], "abcde")
r = random.Random(132)
for _ in range(14):
    setp(g, r.randrange(W), r.randrange(W), ".")
for fx, fy in ((4, 4), (12, 10)):          # fleurs de pomme de terre
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        setp(g, fx + dx, fy + dy, "f")
    setp(g, fx, fy, "g")
save("cavepatate_tuber_leaves", LEAF, g)

# =================================================================== contenu étendu
# (blocs de la cave complète : sols, minerais, briques, pelures, machines, objets)


def overlay_clusters(seed, symbols, n=6):
    """Calque transparent avec des amas de minerai (comme les minerais de MTG)."""
    r = random.Random(seed)
    g = blank()
    for _ in range(n):
        cx, cy = r.randrange(1, W - 2), r.randrange(1, W - 2)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (0, -1)):
            if r.random() < 0.8:
                g[(cy + dy) % W][(cx + dx) % W] = symbols[0] if (dx, dy) == (0, 0) else r.choice(symbols)
        setp(g, cx + 1, cy - 1, symbols[-1])
    return g


def strokes(g, seed, n, syms, edge=None, length=(5, 10)):
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.uniform(0, W), r.uniform(0, W)
        ang, turn = r.uniform(0, 2 * math.pi), r.uniform(-0.4, 0.4)
        for step in range(r.randint(*length)):
            g[int(y) % W][int(x) % W] = r.choice(syms)
            if edge:
                setp(g, int(x + math.cos(ang + 1.57)), int(y + math.sin(ang + 1.57)), edge)
            x, y, ang = x + math.cos(ang), y + math.sin(ang), ang + turn
    return g


def side_overlay(top_grid, seed, depth=(2, 5)):
    """Débord de la tourbe sur le côté : rangées du haut, bord inférieur irrégulier."""
    r = random.Random(seed)
    g = blank()
    for x in range(W):
        d = r.randint(*depth)
        for y in range(d):
            g[y][x] = top_grid[y][x]
    return g


STARCH = {"a": "#e6c244", "b": "#ecce56", "c": "#f2d86a", "d": "#f6e280", "e": "#faec9a", "f": "#d8b034"}
g = natural(141, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), grain=0.2)
sprinkle(g, 142, "f", 4, only="ab")
save("cavepatate_starchstone", STARCH, g)

SOIL = {"a": "#ac6412", "b": "#bc741a", "c": "#c88422", "d": "#d4922c", "e": "#e0a23a", "f": "#ecb850"}
g = natural(151, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10))
sprinkle(g, 152, "f", 5, only="de")
save("cavepatate_tuber_soil", SOIL, g)

TURF = {"a": "#d08a14", "b": "#da981c", "c": "#e4a626", "d": "#ecb432", "e": "#f4c240", "f": "#fcd462"}
turf = natural(161, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), grain=0.35)
sprinkle(turf, 162, "f", 6, only="de")
save("cavepatate_peel_turf_top", TURF, turf)
save("cavepatate_peel_turf_side", dict(TURF, **{".": "transparent"}), side_overlay(turf, 163))

BTURF = {"a": "#407620", "b": "#488424", "c": "#509028", "d": "#589c2e", "e": "#62a834", "f": "#70b63e",
         }
bturf = natural(171, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), grain=0.35)
sprinkle(bturf, 172, "f", 5, only="de")
save("cavepatate_blighted_peel_turf_top", BTURF, bturf)
save("cavepatate_blighted_peel_turf_side", dict(BTURF, **{".": "transparent"}), side_overlay(bturf, 173))

g = quantize(fbm(181), [0.45, 0.6], "bcd")
for y in range(W):
    for x in range(W):
        if y % 4 == 0:
            g[y][x] = "a"
        elif y % 4 == 1 and g[y][x] == "d":
            g[y][x] = "e"
save("cavepatate_tuber_farmland", SOIL, g)

PATH = {"a": "#b8862a", "b": "#c89430", "c": "#d2a03a", "d": "#dcac46", "e": "#e4b852", "f": "#ecc460"}
g = natural(191, "bcdef", (0.10, 0.25, 0.30, 0.25, 0.10))
sprinkle(g, 192, "a", 5, only="bc")
save("cavepatate_tuber_path", PATH, g)

GRATE = {"a": "#e4b42e", "b": "#ecc03c", "c": "#f2ca4a", "d": "#f6d45c", "e": "#fadf72", "f": "#d8a428"}
g = natural(201, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), grain=0.3)
r = random.Random(202)
for _ in range(10):                      # fines lamelles de râpure en diagonale
    x, y = r.randrange(W), r.randrange(W)
    sym = r.choice("ef")
    for k in range(2):
        setp(g, x + k, y + k, sym)
save("cavepatate_potato_gratings", GRATE, g)

save("cavepatate_mineral_blight", {".": "transparent", "a": "#2e6a14", "b": "#6cc22e", "c": "#b8f458"},
     overlay_clusters(211, "bca"))
save("cavepatate_mineral_sap", {".": "transparent", "a": "#6a1680", "b": "#b434d8", "c": "#f496ff"},
     overlay_clusters(221, "bca"))

g = blank()
for i in range(W):
    for j in (0, W - 1):
        g[j][i] = "a"
        g[i][j] = "a"
for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
    setp(g, x, y, "b")
for i in range(3, 13):
    setp(g, i, i, "c")
    setp(g, i, W - 1 - i, "c")
save("cavepatate_compressed_frame", {".": "transparent", "a": "#101a08", "b": "#d8f478", "c": "#1e2e1080"}, g)

MASH = {"a": "#5a9230", "b": "#66a036", "c": "#70ac3c", "d": "#7ab842", "e": "#86c44a", "f": "#a2d862"}
g = natural(231, "abcde", (0.10, 0.25, 0.30, 0.25, 0.10), grain=0.2)
sprinkle(g, 232, "f", 3, only="de")
save("cavepatate_blighted_mash", MASH, g)

PEELG = {"a": "#8c8c8c", "b": "#a8a8a8", "c": "#c4c4c4", "d": "#dedede", "e": "#f4f4f4"}
g = quantize(fbm(241), [0.45, 0.58], "bcd")
strokes(g, 242, 16, "de", edge="a")
save("cavepatate_peel_block", PEELG, g)

# Pelures corrompues : texture animée 16×64 (4 images), étincelles qui se déplacent
CPEEL = {"a": "#26103a", "b": "#44185e", "c": "#62287e", "d": "#6e5a24", "e": "#94802a",
         "f": "#ff6cff", "g": "#ffffff"}
base = quantize(fbm(251), [0.42, 0.55], "bcd")
strokes(base, 252, 12, "de", edge="a")
frames = []
r = random.Random(253)
for k in range(4):
    fr = [row[:] for row in base]
    for _ in range(5):
        x, y = r.randrange(W), r.randrange(W)
        fr[y][x] = "g"
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            setp(fr, x + dx, y + dy, "f")
    frames += fr
save("cavepatate_blighted_peel_block", CPEEL, frames)

BAKED = {"a": "#a8560a", "b": "#c86e12", "c": "#dc861c", "d": "#eca02c", "e": "#f8bc44"}
save("cavepatate_baked_brick", BAKED, bricks(261))
CHAR = {"a": "#1a0f08", "b": "#3c2614", "c": "#52361c", "d": "#6c4826", "e": "#8a6034"}
save("cavepatate_charred_brick", CHAR, bricks(262))
STALE = {"a": "#4e4a14", "b": "#80781e", "c": "#a29a2a", "d": "#c0b63a", "e": "#dad254", "f": "#52a424"}
g = bricks(263)
r = random.Random(264)
for _ in range(9):
    x, y = r.randrange(W), r.randrange(W)
    setp(g, x, y, "f")
    setp(g, x + 1, y, "f")
save("cavepatate_stale_brick", STALE, g)

ROOTW = {"a": "#a0701a", "b": "#bc8a26", "c": "#d2a234", "d": "#e4b848", "e": "#f2d064"}
cols = value_noise(281, 8)
g = [["b" if cols[0][x] < 0.4 else ("c" if cols[0][x] < 0.65 else "d") for x in range(W)] for _ in range(W)]
r = random.Random(282)
for _ in range(10):
    setp(g, r.randrange(W), r.randrange(W), r.choice("ae"))
save("cavepatate_strong_root", ROOTW, g)
g = blank()
for y in range(W):
    for x in range(W):
        d = math.hypot(x - 7.5, y - 7.5)
        g[y][x] = "a" if d > 6.5 else ("e" if d < 1.5 else ("c" if int(d) % 2 else "d"))
save("cavepatate_strong_root_top", ROOTW, g)

MIGHTY = dict(SKIN, f="#ffd84a", g="#fff2a0")
g = quantize(fbm(291), [0.38, 0.5, 0.62], "bcde")
eyes(g, [(3, 3), (11, 6), (6, 12)], "a", "e")
x, y = 1.0, 8.0
for k in range(W):                        # veines lumineuses
    setp(g, int(x), int(y), "f")
    if k % 3 == 0:
        setp(g, int(x), int(y) - 1, "g")
    x, y = x + 1, y + math.sin(k * 0.9) * 0.9
save("cavepatate_mighty_potato", MIGHTY, g)

# --------------------------------------------------------- sprites dessinés à la main


def sprite(name, palette, rows):
    rows = [r for r in rows.strip("\n").split("\n")]
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), (name, [len(r) for r in rows])
    save(name, dict({".": "transparent"}, **palette), [list(r) for r in rows])


sprite("cavepatate_blighted_potato", {"a": "#2a5a12", "b": "#3e8018", "c": "#58a424", "d": "#7cc634", "e": "#b6ea58",
                                      "f": "#3a2a3e"}, """
................
................
................
.....aaaaa......
....abdddbaa....
...abdeedddba...
..abddefddcdba..
..abdcdddddcba..
..abcddddfdcba..
..abccdcdddcba..
...abcccdccba...
....abbcccbaa...
.....aaabbaa....
........aa......
................
................""")

sprite("cavepatate_blighted_slice", {"a": "#2a3e16", "b": "#6a8c33", "c": "#b8d063", "d": "#dcec9a"}, """
................
................
................
..aaaa..........
.abccba.........
.acddca..aaaa...
.acddca.abccba..
.abccba.acddca..
..aaaa..acddca..
........abccba..
....aaaa.aaaa...
...abccba.......
...acddca.......
...abccba.......
....aaaa........
................""")

sprite("cavepatate_potato_peel", {"a": "#6a3e14", "b": "#a4641a", "c": "#cf963c", "d": "#f2da88"}, """
................
................
..........aa....
.........abba...
........abcdba..
.......abcd.a...
......abcd......
.....abcd.......
....abcd........
...abcd.........
..abcd..........
..abdd..........
...add..........
....aa..........
................
................""")

sprite("cavepatate_potato_sticks", {"a": "#a88a50", "b": "#e6d6a3", "c": "#f8f0d0"}, """
................
................
................
....a.....a.....
...aba...aba....
...aca..a.ca....
...abaaabaaba...
...abacabacba...
...aba.abacba...
...abaaba.aba...
...abacbaa.ba...
...aba.abaaba...
...aba.aba.a....
....a...a.......
................
................""")

sprite("cavepatate_fries", {"a": "#7a1414", "b": "#c42a24", "c": "#e8524a", "d": "#c4902e", "e": "#f0c040",
                            "f": "#fff0a0"}, """
................
.....e..e.......
....ef.ed.e.....
....ef.ef.fe....
...dfeedfeef....
...dfeedfeefd...
...deedeeedfd...
...abbbbbbbba...
...abccbbccba...
...abcbbbbcba...
...abbbccbbba...
....abbbbbba....
....abbbbbba....
....abbbbbba....
.....aaaaaa.....
................""")

sprite("cavepatate_hash_brown", {"a": "#6a4318", "b": "#a8722e", "c": "#c8923c", "d": "#e0b45a", "e": "#f4d488"}, """
................
................
................
................
...aaaaaaaaaa...
..abcdcdcdccba..
..acdedcdedcda..
..abdcdeccdcba..
..acdcedcdedca..
..abcdcdcedcba..
..acdecdcdcdca..
...aaaaaaaaaa...
................
................
................
................""")

sprite("cavepatate_potato_oil", {"a": "#3a4a52", "b": "#8aa4b0", "c": "#d8e8f0", "d": "#c48a1e", "e": "#f0b030",
                                 "f": "#ffe08a"}, """
................
......aaaa......
......abca......
......abca......
.....aabcaa.....
....ab....ba....
...ab......ba...
...aceeeeeefa...
...adeefeeeea...
...adeeeeefea...
...addeeeeeea...
...addddeeeea...
...adddddddda...
....aaaaaaaa....
................
................""")

sprite("cavepatate_toxic_oil", {"a": "#3a4a52", "b": "#8aa4b0", "c": "#d8e8f0", "d": "#3e6a1c", "e": "#7ab030",
                                "f": "#c8f070"}, """
................
......aaaa......
......abca......
......abca......
.....aabcaa.....
....ab....ba....
...ab......ba...
...aceeeeeefa...
...adeefeeeea...
...adeeeeefea...
...addeeeeeea...
...addddeeeea...
...adddddddda...
....aaaaaaaa....
................
................""")

sprite("cavepatate_toxic_sap", {"a": "#3e1048", "b": "#7a2a90", "c": "#b44ad0", "d": "#e08af0"}, """
................
................
.......a........
......aba.......
......aca.......
.....abcba......
.....acdca......
....abcdcba.....
....acddcca.....
...abcdcccba....
...acccccbba....
...abcccbbba....
....abbbbba.....
.....aaaaa......
................
................""")

sprite("cavepatate_tuber_fruit", {"a": "#2c6a1a", "b": "#3e9826", "c": "#d87a10", "d": "#ffb02c", "e": "#ffdc7a",
                                  "f": "#fff6c8"}, """
.......aa.......
.......ab.......
.......ab.......
......abba......
.......aa.......
.....cccccc.....
....cddddddc....
...cddeeeeddc...
...cdeeffeedc...
...cdeeffeedc...
...cddeeeeddc...
....cddddddc....
.....cddddc.....
......cccc......
................
................""")

sprite("cavepatate_tuber_sprout", {"a": "#1e5414", "b": "#3e9826", "c": "#84d448", "d": "#91591e", "e": "#cf963c"}, """
................
................
................
.......cc.......
......cbbc......
...cc..ba.......
..cbbc.ba..cc...
...cbbcba.cbbc..
....ccaba.cbc...
.......bacc.....
.......ba.......
.......ba.......
......deed......
.....deeeed.....
.....dddddd.....
................""")

sprite("cavepatate_tuber_spike", {"a": "#a86e14", "b": "#cc9424", "c": "#e6b43c", "d": "#fcd872"}, """
.......a........
.......ad.......
.......ab.......
......abc.......
......adb.......
......abca......
.....adbca......
.....abcba......
.....adcbba.....
....abdcbba.....
....adbcbbba....
....abdcbcba....
...adbdcbbbba...
...abdccbcbba...
..abbdcbcbbbba..
..aaaaaaaaaaaa..""")

sprite("cavepatate_tuber_flower", {"a": "#2c6a1a", "b": "#4aa82c", "c": "#f6dcff", "d": "#c07ef0", "e": "#ffd83a"}, """
................
................
.....cc..cc.....
....cddccddc....
....cdcdccdc....
.....cceecc.....
....cdceecdc....
....cddccddc....
.....cc..cc.....
.......a........
.......ab.bb....
..bb...ab.b.....
...bb..aab......
....b..ab.......
.......ab.......
.......ab.......""")

sprite("cavepatate_blighted_head_face", {"a": "#14300a", "b": "#3e8018", "c": "#58a424", "d": "#7cc634",
                                         "e": "#d0f070", "f": "#2a0e14"}, """
cccdcccccccdcccc
ccdddccccccdddcc
cddccccccccccddc
cccaaaaccaaaaccc
ccaeeeaccaeeeacc
ccaefeaccaefeacc
ccaaaaaccaaaaacc
cccccccbbccccccc
ccccccbccbcccccc
cccccccccccccccc
ccaaaaaaaaaaaacc
ccafafafafafaacc
cccaaaaaaaaaaccc
ccccccdccccccccc
cdccccccccccdccc
cccccccccccccccc""")

sprite("cavepatate_fryer_top", {"a": "#2a2a2e", "b": "#5a5a62", "c": "#8a8a94", "d": "#c48a1e", "e": "#f0b030",
                                "f": "#ffe08a"}, """
aaaaaaaaaaaaaaaa
abbbbbbbbbbbbbba
abccccccccccccba
abcdddddddddcbba
abcdeeefeeeedcba
abcdeefffeeedcba
abcdeeefeeeedcba
abcdeeeeeefedcba
abcdeeeeefffdcba
abcdeefeeefedcba
abcdeeeeeeeedcba
abcdeeeeeeeedcba
abcddddddddddcba
abccccccccccccba
abbbbbbbbbbbbbba
aaaaaaaaaaaaaaaa""")

sprite("cavepatate_fryer_side", {"a": "#2a2a2e", "b": "#5a5a62", "c": "#9a9aa6", "d": "#9e782a", "e": "#bf963a",
                                 "f": "#d8b250"}, """
aaaaaaaaaaaaaaaa
bcccccccccccccbb
bbbbbbbbbbbbbbbb
aaaaaaaaaaaaaaaa
eeeeffeeeeeeffee
deeeeeeeefeeeeed
eeffeeeeeeeeeeee
dddddddddddddddd
eeeeeeeffeeeeeee
eeefeeeeeeeeeffe
deeeeeeeeeefeeee
dddddddddddddddd
eeeeffeeeeeeeeee
eeeeeeeeefeeeeee
deeeeeeeeeeeeefe
dddddddddddddddd""")

sprite("cavepatate_slicer_top", {"a": "#4a4a52", "b": "#8a8a94", "c": "#dce0e8", "d": "#d6b978", "e": "#e4cc8e"}, """
dddddddddddddddd
deeeeeeeeeeeeeed
deaaaaaaaaaaaaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deabcbcbcbcbcaed
deaaaaaaaaaaaaed
deeeeeeeeeeeeeed
dddddddddddddddd""")

sprite("cavepatate_slicer_side", {"a": "#3a3a42", "b": "#6a6a74", "c": "#a4a4b0", "d": "#d8dce4", "e": "#d6b978"}, """
aaaaaaaaaaaaaaaa
abbbbbbbbbbbbbba
abccccccccccccba
abcddddddddddcba
abccccccccccccba
abbbbbbbbbbbbbba
aaaaaaaaaaaaaaaa
eeeeeeeeeeeeeeee
eeeeeeaaaaeeeeee
eeeeeeabbaeeeeee
eeeeeeabbaeeeeee
eeeeeeaaaaeeeeee
eeeeeeeeeeeeeeee
eeeeeeeeeeeeeeee
eeeeeeeeeeeeeeee
eeeeeeeeeeeeeeee""")

sprite("cavepatate_refinery_top", {"a": "#4a3018", "b": "#8a5a2a", "c": "#b87a3a", "d": "#d89a52", "e": "#3a3a42"}, """
aaaaaaaaaaaaaaaa
abbbbbbbbbbbbbba
abccccccccccccba
abccccceecccccba
abcccceaaeccccba
abccceaddaecccba
abccceaddaecccba
abcccceaaeccccba
abccccceecccccba
abccccccccccccba
abcdccccccccdcba
abccccccccccccba
abccccccccccccba
abccccccccccccba
abbbbbbbbbbbbbba
aaaaaaaaaaaaaaaa""")

sprite("cavepatate_refinery_side", {"a": "#4a3018", "b": "#8a5a2a", "c": "#b87a3a", "d": "#d89a52", "e": "#3a3a42"}, """
aaaaaaaaaaaaaaaa
abbbbbbbbbbbbbba
abccccccccccccba
abcdccccccccdcba
abccccccccccccba
abbbbbbbbbbbbbba
aaaaaaaaaaaaaaaa
abccccccccccccba
abccccccccccccba
abcdccccccccdcba
abccccccccccccba
aaaaaaaaaaaaaaaa
abbbbbbbbbbbbbba
abccccccccccccba
abbbbbbbbbbbbbba
aaaaaaaaaaaaaaaa""")

sprite("cavepatate_refinery_front", {"a": "#4a3018", "b": "#8a5a2a", "c": "#b87a3a", "d": "#2a2a2e", "e": "#f0b030",
                                     "f": "#ffe08a", "g": "#c48a1e"}, """
aaaaaaaaaaaaaaaa
abbbbbbbbbbbbbba
abccccccccccccba
abcddddddddddcba
abcdffeeeeeedcba
abcdfeeeeeeedcba
abcdeeeeeeeedcba
abcdeeeeeeeedcba
abcdggggggggdcba
abcdggggggggdcba
abcddddddddddcba
abccccccccccccba
abccccaaaaccccba
abccccaddaccccba
abbbbbbbbbbbbbba
aaaaaaaaaaaaaaaa""")


def battery_top(on):
    pal = {"a": "#6a3e14", "b": "#b4762a", "c": "#cf963c", "d": "#5a5a62", "e": "#e6b65a", "f": "#d8dce4",
           "g": "#fff070", "h": "#ffffff"}
    rows = """
bbbbbbbbbbbbbbbb
bccccbcccccbcccb
bcddddccccddddcb
bcdeedccccdffdcb
bcdeedccccdffdcb
bcddddccccddddcb
bccccccccccccccb
bcccbcccccccbccb
bccccccccccccccb
bccbccccccbccccb
bccccccbcccccccb
bcccccccccccbccb
bcbcccccccccccbb
bccccccbccccbccb
bccccccccccccccb
bbbbbbbbbbbbbbbb"""
    if on:
        rows = rows.replace("bccccccccccccccb\nbcccbcccccccbccb", "bccccgcgcgcccccb\nbcccbcghgcccbccb", 1)
        rows = rows.replace("bccccccccccccccb\nbccbccccccbccccb", "bccccgcgcgcccccb\nbccbccccccbccccb", 1)
    return pal, rows


for state in ("off", "on"):
    pal, rows = battery_top(state == "on")
    sprite("cavepatate_battery_top_" + state, pal, rows)

sprite("cavepatate_battery_side", {"a": "#6a3e14", "b": "#91591e", "c": "#b4762a", "d": "#cf963c",
                                   "e": "#e6b65a", "f": "#f8d686"}, """
bbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbb
cccdccccccdccccc
ccdddccccdddcccc
cccccccccccccccc
eeeeeeeeeeeeeeee
ffffffffffffffff
eeeeeeeeeeeeeeee
cccccccccccccccc
ccccccdccccccccc
cccccdddcccccdcc
cccccccccccccccc
ccdccccccccccccc
cccccccccdcccccc
cccccccccccccccc""")

sprite("cavepatate_floatater_top", {"a": "#c4a464", "b": "#e9ca6e", "c": "#f9e9aa", "d": "#fff6d2", "e": "#91591e",
                                    "f": "#cf963c"}, """
bbbbbbbbbbbbbbbb
bccccccccccccccb
bccccccdcccccccb
bcccccdddccccccb
bccccdddddcccccb
bcccdddddddccccb
bccccccdcccccccb
bccccccdcccccccb
bccccccdcccccccb
bccccccdcccccccb
bccccccdcccccccb
bccccccccccccccb
bccbccccccccbccb
bccccccccccccccb
bccccccccccccccb
bbbbbbbbbbbbbbbb""")

sprite("cavepatate_floatater_side", {"a": "#6a3e14", "b": "#91591e", "c": "#b4762a", "d": "#cf963c",
                                     "e": "#f9e9aa", "f": "#e9ca6e"}, """
eeeeeffeeeeffeee
feeeeeeeeeeeeeef
cccccccccccccccc
cccdccccccccdccc
ccdddccccccdddcc
cccccccccccccccc
ccccccccdccccccc
cccccccdddcccccc
cccccccccccccccc
cccccccccccccccc
ccdccccccccccdcc
cccccccccccccccc
cccccccccccccccc
fffeeeeeeeeeefff
eeeeefeeeeefeeee
eeeeeeeeeeeeeeee""")
