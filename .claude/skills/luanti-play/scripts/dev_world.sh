#!/usr/bin/env bash
# Prépare le test en jeu du mod :
#   1. lien symbolique <user>/mods/<mod> -> ce dossier (le code est lu en direct, pas de copie) ;
#   2. monde dédié <user>/worlds/<mod>_dev (créatif) avec le mod + les mods de .claude/test_mods.txt ;
#   3. avec --launch : ouvre Luanti directement dans ce monde.
# Options : --new    supprime puis recrée le monde de dev (indispensable après une modif du générateur :
#                    les chunks déjà générés ne sont jamais regénérés)
#           --launch lance Luanti dans le monde de dev
# Ne modifie JAMAIS les autres mondes. Refuse d'écraser un vrai dossier <user>/mods/<mod>.
set -euo pipefail
MOD_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
CLAUDE_DIR="$MOD_DIR/.claude"
MODNAME="$(sed -n 's/^name *= *//p' "$MOD_DIR/mod.conf" | tr -d '[:space:]')"
GAMEID="${GAMEID:-minetest}"

if [ -n "${LUANTI_USER_DIR:-}" ]; then USER_DIR="$LUANTI_USER_DIR"
elif [ -d "$HOME/Library/Application Support/luanti" ]; then USER_DIR="$HOME/Library/Application Support/luanti"
else USER_DIR="$HOME/Library/Application Support/minetest"; fi

LINK="$USER_DIR/mods/$MODNAME"
WORLD="$USER_DIR/worlds/${MODNAME}_dev"
mkdir -p "$USER_DIR/mods" "$USER_DIR/worlds"

# 1. Lien du mod
if [ -L "$LINK" ]; then
	[ "$(readlink "$LINK")" != "$MOD_DIR" ] && ln -sfn "$MOD_DIR" "$LINK"
	echo "Lien OK      : $LINK -> $MOD_DIR"
elif [ -e "$LINK" ]; then
	echo "ERREUR : $LINK existe déjà et n'est pas un lien. Déplace-le puis relance."; exit 1
else
	ln -s "$MOD_DIR" "$LINK"; echo "Lien créé    : $LINK -> $MOD_DIR"
fi

# 2. Monde de dev
NEW=0; LAUNCH=0
for a in "$@"; do case "$a" in --new) NEW=1 ;; --launch) LAUNCH=1 ;; *) echo "Option inconnue : $a"; exit 1 ;; esac; done
if [ "$NEW" = 1 ] && [ -d "$WORLD" ]; then
	case "$WORLD" in *"/worlds/${MODNAME}_dev") rm -rf "$WORLD"; echo "Monde supprimé : $WORLD" ;; esac
fi
WANTED=("$MODNAME")
if [ -f "$CLAUDE_DIR/test_mods.txt" ]; then
	while IFS= read -r m; do [ -n "$m" ] && WANTED+=("$m"); done \
		< <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$CLAUDE_DIR/test_mods.txt")
fi
if [ ! -f "$WORLD/world.mt" ]; then
	mkdir -p "$WORLD"
	cat > "$WORLD/world.mt" <<MT
gameid = $GAMEID
world_name = ${MODNAME}_dev
backend = sqlite3
auth_backend = sqlite3
player_backend = sqlite3
mod_storage_backend = sqlite3
creative_mode = true
enable_damage = false
MT
	echo "Monde créé   : $WORLD"
else
	echo "Monde OK     : $WORLD"
fi
for m in "${WANTED[@]}"; do
	if [ "$m" != "$MODNAME" ] && [ ! -d "$USER_DIR/mods/$m" ] \
		&& ! grep -qsE "^name *= *$m *$" "$USER_DIR"/mods/*/mod.conf "$USER_DIR"/mods/*/*/mod.conf; then
		echo "ATTENTION    : mod '$m' introuvable dans $USER_DIR/mods (à installer)"
	fi
	if grep -q "^load_mod_$m *=" "$WORLD/world.mt"; then
		sed -i '' "s/^load_mod_$m *=.*/load_mod_$m = true/" "$WORLD/world.mt"
	else
		echo "load_mod_$m = true" >> "$WORLD/world.mt"
	fi
done
echo "Mods activés : ${WANTED[*]}"

# 3. Lancement
if [ "$LAUNCH" = 1 ]; then
	BIN="${LUANTI_BIN:-}"
	for c in "$BIN" "$(command -v luanti 2>/dev/null || true)" "/Applications/Luanti.app/Contents/MacOS/luanti" \
		"/Applications/luanti.app/Contents/MacOS/luanti" "$HOME/Downloads/luanti.app/Contents/MacOS/luanti"; do
		[ -n "$c" ] && [ -x "$c" ] && { BIN="$c"; break; }
	done
	[ -x "$BIN" ] || { echo "ERREUR : binaire Luanti introuvable (définir LUANTI_BIN)."; exit 1; }
	nohup "$BIN" --go --world "$WORLD" --name dev >/dev/null 2>&1 &
	echo "Luanti lancé dans le monde ${MODNAME}_dev (log : $USER_DIR/debug.txt)"
fi
