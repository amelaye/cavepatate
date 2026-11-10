#!/usr/bin/env python3
"""Met à jour les traductions du mod à partir des appels S("...") du code Lua.

- Régénère locale/template.txt (toutes les chaînes, groupées par fichier source).
- Met à jour chaque locale/<mod>.<langue>.tr : conserve les traductions existantes,
  ajoute les nouvelles clés (vides), range les clés obsolètes en fin de fichier.

Usage :
    update_translations.py               # met à jour template + toutes les langues existantes
    update_translations.py --lang fr     # crée/actualise aussi locale/<mod>.fr.tr
    update_translations.py --check       # n'écrit rien ; code 1 si traductions manquantes/obsolètes
"""

import argparse
import os
import re
import sys

MOD_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
LOCALE = os.path.join(MOD_DIR, "locale")
OBSOLETE_HEADER = "##### plus utilisé #####"

CALL_RE = re.compile(r"(?<![\w.:])(P?S)\s*\(\s*")
ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def modname():
    with open(os.path.join(MOD_DIR, "mod.conf"), encoding="utf-8") as f:
        for line in f:
            if line.split("=")[0].strip() == "name":
                return line.split("=", 1)[1].strip()
    return os.path.basename(MOD_DIR).lower()


def read_lua_string(src, i):
    """Lit un littéral Lua à partir de src[i]. Retourne (valeur, fin) ou (None, i)."""
    if src.startswith("[[", i) or re.match(r"\[=+\[", src[i:]):
        m = re.match(r"\[(=*)\[", src[i:])
        close = "]" + m.group(1) + "]"
        start = i + len(m.group(0))
        end = src.find(close, start)
        if end < 0:
            return None, i
        val = src[start:end]
        return (val[1:] if val.startswith("\n") else val), end + len(close)
    if i >= len(src) or src[i] not in "\"'":
        return None, i
    quote, j, out = src[i], i + 1, []
    while j < len(src):
        c = src[j]
        if c == "\\":
            nxt = src[j + 1]
            if nxt in ESCAPES:
                out.append(ESCAPES[nxt])
                j += 2
            elif nxt.isdigit():
                m = re.match(r"\d{1,3}", src[j + 1:])
                out.append(chr(int(m.group(0))))
                j += 1 + len(m.group(0))
            elif nxt == "x":
                out.append(chr(int(src[j + 2:j + 4], 16)))
                j += 4
            else:
                out.append(nxt)
                j += 2
        elif c == quote:
            return "".join(out), j + 1
        elif c == "\n":
            return None, i
        else:
            out.append(c)
            j += 1
    return None, i


def strip_comments(src):
    """Remplace les commentaires Lua par des espaces (en gardant les retours ligne)."""
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                end = src.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            out.append(re.sub(r"[^\n]", " ", src[i:end]))
            i = end
        elif src[i] in "\"'" or src.startswith("[[", i) or re.match(r"\[=+\[", src[i:i + 10]):
            _, end = read_lua_string(src, i)
            end = end if end > i else i + 1
            out.append(src[i:end])
            i = end
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def tr_escape(s):
    return re.sub(r"(?<!@)=", "@=", s).replace("\n", "@n")


def extract():
    """Retourne (liste ordonnée [(fichier, [clés])], avertissements)."""
    files, warnings, seen = [], [], set()
    for root, dirs, names in os.walk(MOD_DIR):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(names):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, MOD_DIR)
            with open(path, encoding="utf-8") as f:
                src = strip_comments(f.read())
            keys = []
            for m in CALL_RE.finditer(src):
                fn = m.group(1)
                line = src.count("\n", 0, m.start()) + 1
                val, end = read_lua_string(src, m.end())
                if val is None:
                    warnings.append(f"{rel}:{line} : {fn}(...) sans littéral (variable/concaténation) — non extrait")
                    continue
                if re.match(r"\s*\.\.", src[end:]):
                    warnings.append(f"{rel}:{line} : concaténation dans {fn}(...) — non extrait, "
                                    "utiliser des arguments @1, @2")
                    continue
                if fn == "PS":
                    warnings.append(f"{rel}:{line} : PS() (pluriels) n'est géré que par les fichiers .po, pas .tr")
                args = [int(a) for a in re.findall(r"(?<!@)@([1-9])", val)]
                if args and args != list(range(1, len(args) + 1)):
                    warnings.append(f"{rel}:{line} : arguments {args} — doivent être @1, @2… dans l'ordre, sans trou")
                key = tr_escape(val)
                if key not in seen:
                    seen.add(key)
                    keys.append(key)
            if keys:
                files.append((rel, keys))
    return files, warnings


def parse_tr(path):
    trans = {}
    if not os.path.exists(path):
        return trans
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            m = re.match(r"^((?:[^=@]|@.)*)=(.*)$", line)
            if m:
                trans[m.group(1)] = m.group(2)
    return trans


def render(mod, files, trans, obsolete):
    out = [f"# textdomain: {mod}"]
    for rel, keys in files:
        out.append("")
        out.append(f"### {rel} ###")
        out += [f"{k}={trans.get(k, '')}" for k in keys]
    if obsolete:
        out += ["", OBSOLETE_HEADER]
        out += [f"{k}={v}" for k, v in obsolete.items()]
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", action="append", default=[], help="langue à créer/actualiser (répétable)")
    ap.add_argument("--check", action="store_true", help="vérifier sans écrire")
    args = ap.parse_args()

    mod = modname()
    files, warnings = extract()
    all_keys = [k for _, keys in files for k in keys]
    os.makedirs(LOCALE, exist_ok=True)

    langs = set(args.lang)
    for name in os.listdir(LOCALE):
        m = re.match(rf"^{re.escape(mod)}\.([\w-]+)\.tr$", name)
        if m:
            langs.add(m.group(1))

    for w in warnings:
        print("ATTENTION", w)

    problems = 0
    template = render(mod, files, {}, {})
    tpath = os.path.join(LOCALE, "template.txt")
    old_template = open(tpath, encoding="utf-8").read() if os.path.exists(tpath) else ""
    if old_template != template:
        if args.check:
            print("template.txt n'est pas à jour")
            problems += 1
        else:
            with open(tpath, "w", encoding="utf-8") as f:
                f.write(template)
    print(f"{len(all_keys)} chaîne(s) traduisible(s) dans {len(files)} fichier(s)")

    for lang in sorted(langs):
        path = os.path.join(LOCALE, f"{mod}.{lang}.tr")
        trans = parse_tr(path)
        obsolete = {k: v for k, v in trans.items() if k not in all_keys and v}
        missing = [k for k in all_keys if not trans.get(k)]
        content = render(mod, files, trans, obsolete)
        old = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        status = f"{lang} : {len(all_keys) - len(missing)}/{len(all_keys)} traduites"
        if obsolete:
            status += f", {len(obsolete)} obsolète(s)"
        print(status)
        for k in missing:
            print(f"    manquante : {k}")
        if args.check:
            problems += len(missing) + len(obsolete) + (old != content)
        elif old != content:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
    return 1 if (args.check and problems) else 0


if __name__ == "__main__":
    sys.exit(main())
