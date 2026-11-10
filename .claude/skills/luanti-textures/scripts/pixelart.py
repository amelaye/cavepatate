#!/usr/bin/env python3
"""Outil pixel art pour les textures Luanti (Python pur, sans dépendance).

Format source .px (texte) :

    # commentaire
    . = transparent
    a = #3b2a1a
    b = #5c4128
    h = #ffffff80        <- alpha optionnel (RRGGBBAA)

    aaaaaaaaaaaaaaaa
    abbbbbbbbbbbbbba
    ...                  <- une ligne par rangée de pixels, 1 caractère = 1 pixel

Commandes :
    build   SRC.px|DOSSIER...  [--out DIR]        .px -> PNG (défaut : <mod>/textures)
    preview IMAGE.png...       [--scale N] [--tile N] [--out DIR]
                                                  agrandit (et répète en mosaïque N×N pour
                                                  vérifier les raccords) -> PNG lisible par Claude
    extract IMAGE.png          [--out FICHIER.px] PNG -> .px (récupérer une palette MTG)
    palette IMAGE.png                              liste les couleurs et leur fréquence
"""

import argparse
import os
import struct
import sys
import tempfile
import zlib

MOD_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
DEFAULT_TEX_DIR = os.path.join(MOD_DIR, "textures")
DEFAULT_PREVIEW_DIR = os.path.join(tempfile.gettempdir(), "cavepatate_previews")
SYMBOLS = ".abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@$%&*+-=~:;!?<>/|"  # pas de '#' (commentaires)


# --------------------------------------------------------------------------- PNG I/O

def png_write(path, width, height, pixels):
    """pixels : liste de rangées, chaque rangée = liste de tuples (r, g, b, a)."""
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    data += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def png_read(path):
    """Retourne (width, height, pixels RGBA). Gère les types 0/2/3/4/6, profondeurs 1-16, non entrelacé."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} : pas un PNG")
    pos, idat, palette, trns = 8, b"", [], None
    width = height = depth = ctype = interlace = None
    while pos < len(data):
        length, tag = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif tag == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b"tRNS":
            trns = body
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
    if interlace:
        raise ValueError(f"{path} : PNG entrelacé non supporté")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bpp = max(1, channels * depth // 8)
    stride = (width * channels * depth + 7) // 8
    raw = zlib.decompress(idat)
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(height):
        ftype = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ftype == 1:
                line[x] = (line[x] + a) & 0xFF
            elif ftype == 2:
                line[x] = (line[x] + b) & 0xFF
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 0xFF
            elif ftype == 4:
                line[x] = (line[x] + _paeth(a, b, c)) & 0xFF
        rows.append(line)
        prev = line

    def samples(line):
        if depth == 8:
            return list(line)
        if depth == 16:
            return [line[k] for k in range(0, len(line), 2)]  # octet de poids fort
        out, mask = [], (1 << depth) - 1
        for byte in line:
            for shift in range(8 - depth, -1, -depth):
                out.append((byte >> shift) & mask)
        return out

    scale = 255 // ((1 << depth) - 1) if depth < 8 else 1
    pixels = []
    for line in rows:
        s = samples(line)
        row = []
        for x in range(width):
            if ctype == 3:
                idx = s[x]
                r, g, b = palette[idx]
                a = trns[idx] if trns is not None and idx < len(trns) else 255
            elif ctype == 0:
                v = s[x] * scale
                r = g = b = v
                a = 255
                if trns is not None and len(trns) >= 2 and s[x] == struct.unpack(">H", trns[:2])[0]:
                    a = 0
            elif ctype == 4:
                r = g = b = s[2 * x]
                a = s[2 * x + 1]
            elif ctype == 2:
                r, g, b = s[3 * x:3 * x + 3]
                a = 255
            else:
                r, g, b, a = s[4 * x:4 * x + 4]
            row.append((r, g, b, a))
        pixels.append(row)
    return width, height, pixels


# --------------------------------------------------------------------------- format .px

def parse_color(text):
    t = text.strip().lower()
    if t in ("transparent", "none", "clear"):
        return (0, 0, 0, 0)
    if t.startswith("#"):
        t = t[1:]
    if len(t) == 3:
        t = "".join(ch * 2 for ch in t)
    if len(t) == 6:
        t += "ff"
    if len(t) != 8:
        raise ValueError(f"couleur invalide : {text!r}")
    return tuple(int(t[k:k + 2], 16) for k in range(0, 8, 2))


def parse_px(path):
    palette, grid = {}, []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            stripped = line.rstrip("\n").rstrip()
            if not stripped or (stripped.startswith("#") and not grid and " = " not in stripped):
                continue
            if not grid and " = " in stripped:
                key, _, val = stripped.partition(" = ")
                key = key.strip()
                if len(key) != 1:
                    raise ValueError(f"{path}:{n} : la clé de palette doit faire 1 caractère")
                palette[key] = parse_color(val.split()[0])
                continue
            grid.append((n, stripped))
    if not grid:
        raise ValueError(f"{path} : aucune grille de pixels")
    width = len(grid[0][1])
    pixels = []
    for n, row in grid:
        if len(row) != width:
            raise ValueError(f"{path}:{n} : largeur {len(row)} ≠ {width}")
        out = []
        for ch in row:
            if ch not in palette:
                raise ValueError(f"{path}:{n} : caractère {ch!r} absent de la palette")
            out.append(palette[ch])
        pixels.append(out)
    return width, len(pixels), pixels


def hexcol(c):
    r, g, b, a = c
    return "transparent" if a == 0 else (f"#{r:02x}{g:02x}{b:02x}" + ("" if a == 255 else f"{a:02x}"))


# --------------------------------------------------------------------------- commandes

def cmd_build(args):
    sources = []
    for src in args.sources:
        if os.path.isdir(src):
            sources += sorted(os.path.join(src, f) for f in os.listdir(src) if f.endswith(".px"))
        else:
            sources.append(src)
    status = 0
    for src in sources:
        try:
            w, h, px = parse_px(src)
        except ValueError as e:
            print(f"ERREUR {e}")
            status = 1
            continue
        name = os.path.splitext(os.path.basename(src))[0] + ".png"
        out = os.path.join(args.out, name)
        png_write(out, w, h, px)
        note = "" if (w, h) in ((16, 16), (32, 32), (64, 64)) else "  (taille inhabituelle)"
        print(f"{src} -> {out} [{w}x{h}]{note}")
    return status


def cmd_preview(args):
    for src in args.images:
        w, h, px = png_read(src)
        tile, scale = args.tile, args.scale
        big = []
        for ty in range(tile):
            for y in range(h):
                row = []
                for tx in range(tile):
                    for x in range(w):
                        r, g, b, a = px[y][x]
                        if a < 255:  # damier pour visualiser la transparence
                            chk = 200 if ((x + y) % 2) else 150
                            k = a / 255
                            r, g, b = (int(r * k + chk * (1 - k)), int(g * k + chk * (1 - k)), int(b * k + chk * (1 - k)))
                        row += [(r, g, b, 255)] * scale
                for _ in range(scale):
                    big.append(row)
        base = os.path.splitext(os.path.basename(src))[0]
        out = os.path.join(args.out, f"{base}_x{scale}" + (f"_tile{tile}" if tile > 1 else "") + ".png")
        png_write(out, w * scale * tile, h * scale * tile, big)
        print(out)
    return 0


def cmd_extract(args):
    w, h, px = png_read(args.image)
    colors = []
    for row in px:
        for c in row:
            c = (0, 0, 0, 0) if c[3] == 0 else c
            if c not in colors:
                colors.append(c)
    if len(colors) > len(SYMBOLS):
        print(f"ERREUR : {len(colors)} couleurs (> {len(SYMBOLS)}), trop pour le format .px")
        return 1
    order = sorted(colors, key=lambda c: (c[3] != 0, sum(c[:3])))
    sym = {c: SYMBOLS[i] for i, c in enumerate(order)}
    lines = [f"# extrait de {os.path.basename(args.image)} ({w}x{h}, {len(colors)} couleurs)"]
    lines += [f"{sym[c]} = {hexcol(c)}" for c in order]
    lines.append("")
    for row in px:
        lines.append("".join(sym[(0, 0, 0, 0) if c[3] == 0 else c] for c in row))
    text = "\n".join(lines) + "\n"
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"-> {args.out}")
    else:
        sys.stdout.write(text)
    return 0


def cmd_palette(args):
    w, h, px = png_read(args.image)
    counts = {}
    for row in px:
        for c in row:
            counts[c] = counts.get(c, 0) + 1
    print(f"{args.image} : {w}x{h}, {len(counts)} couleurs")
    for c, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        r, g, b, a = c
        lum = round(0.2126 * r + 0.7152 * g + 0.0722 * b)
        print(f"  {hexcol(c):<12} x{n:<4} luminance {lum}")
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("sources", nargs="+")
    b.add_argument("--out", default=DEFAULT_TEX_DIR)
    v = sub.add_parser("preview")
    v.add_argument("images", nargs="+")
    v.add_argument("--scale", type=int, default=16)
    v.add_argument("--tile", type=int, default=1)
    v.add_argument("--out", default=DEFAULT_PREVIEW_DIR)
    e = sub.add_parser("extract")
    e.add_argument("image")
    e.add_argument("--out")
    c = sub.add_parser("palette")
    c.add_argument("image")
    args = p.parse_args()
    return {"build": cmd_build, "preview": cmd_preview, "extract": cmd_extract, "palette": cmd_palette}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
