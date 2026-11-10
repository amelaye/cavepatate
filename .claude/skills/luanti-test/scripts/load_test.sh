#!/usr/bin/env bash
# Test de chargement : démarre un serveur Luanti headless avec le mod cavepatate
# (+ les mods listés dans .claude/test_mods.txt) dans un monde TEMPORAIRE hors
# du projet, laisse tourner quelques secondes, arrête, puis analyse le log.
#
# Usage : .claude/skills/luanti-test/scripts/load_test.sh [secondes_après_démarrage]
# Codes : 0 = OK, 1 = erreurs/avertissements du mod, 2 = impossible de lancer.

set -uo pipefail

MOD_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
CLAUDE_DIR="$MOD_DIR/.claude"
MODNAME="$(sed -n 's/^name *= *//p' "$MOD_DIR/mod.conf" | tr -d '[:space:]')"
GAMEID="${GAMEID:-minetest}"
RUN_AFTER_START="${1:-5}"
START_TIMEOUT="${START_TIMEOUT:-60}"

# --- Binaire Luanti ---------------------------------------------------------
find_luanti() {
	if [ -n "${LUANTI_BIN:-}" ] && [ -x "$LUANTI_BIN" ]; then echo "$LUANTI_BIN"; return; fi
	for c in "$(command -v luanti 2>/dev/null)" \
		"/Applications/Luanti.app/Contents/MacOS/luanti" \
		"/Applications/luanti.app/Contents/MacOS/luanti" \
		"$HOME/Downloads/luanti.app/Contents/MacOS/luanti"; do
		[ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return; }
	done
}
LUANTI="$(find_luanti)"
[ -z "$LUANTI" ] && { echo "ERREUR : binaire Luanti introuvable (définir LUANTI_BIN)."; exit 2; }

# --- Monde temporaire --------------------------------------------------------
WORK="${TMPDIR:-/tmp}/${MODNAME}_loadtest"
WORLD="$WORK/world"
LOG="$WORK/debug.txt"
CONF="$WORK/test.conf"
rm -rf "$WORK"
mkdir -p "$WORLD/worldmods"
ln -s "$MOD_DIR" "$WORLD/worldmods/$MODNAME"
# EXTRA_WORLDMODS="chemin1:chemin2" : mods supplémentaires pris par chemin (ex. un clone de Farming Redo)
IFS=':' read -r -a EXTRA <<< "${EXTRA_WORLDMODS:-}"
for p in "${EXTRA[@]}"; do
	[ -d "$p" ] && ln -s "$p" "$WORLD/worldmods/$(basename "$p")"
done

{
	echo "gameid = $GAMEID"
	echo "backend = sqlite3"
	echo "auth_backend = sqlite3"
	echo "player_backend = sqlite3"
	echo "mod_storage_backend = sqlite3"
	echo "creative_mode = false"
	echo "enable_damage = true"
	# Mods supplémentaires (déjà installés dans le dossier mods/ de Luanti)
	if [ -f "$CLAUDE_DIR/test_mods.txt" ]; then
		sed -e 's/#.*//' -e 's/[[:space:]]//g' "$CLAUDE_DIR/test_mods.txt" | while read -r m; do
			[ -n "$m" ] && echo "load_mod_$m = true"
		done
	fi
} > "$WORLD/world.mt"

cat > "$CONF" <<CONF
mg_name = singlenode
server_announce = false
enable_rollback_recording = false
deprecated_lua_api_handling = log
debug_log_level = action
CONF

PORT=$((30100 + RANDOM % 800))
echo "Luanti : $("$LUANTI" --version 2>/dev/null | head -1)  |  jeu : $GAMEID  |  mod : $MODNAME"
[ -f "$CLAUDE_DIR/test_mods.txt" ] && echo "Mods additionnels : $(grep -v '^[[:space:]]*#' "$CLAUDE_DIR/test_mods.txt" | tr -s '\n' ' ')"

"$LUANTI" --server --world "$WORLD" --gameid "$GAMEID" --config "$CONF" \
	--port "$PORT" --logfile "$LOG" --log-timestamp none >"$WORK/console.txt" 2>&1 &
PID=$!

# --- Attente du démarrage puis arrêt ----------------------------------------
started=0; t=0
while kill -0 "$PID" 2>/dev/null; do
	if grep -q "listening on" "$LOG" 2>/dev/null; then started=1; break; fi
	[ "$t" -ge "$START_TIMEOUT" ] && break
	sleep 1; t=$((t + 1))
done
if [ "$started" = 1 ]; then
	sleep "$RUN_AFTER_START"   # laisse tourner core.after / timers / ABM
	kill "$PID" 2>/dev/null
	for _ in 1 2 3 4 5; do kill -0 "$PID" 2>/dev/null || break; sleep 1; done
	kill -9 "$PID" 2>/dev/null
fi
wait "$PID" 2>/dev/null

# --- Analyse -----------------------------------------------------------------
echo "------------------------------------------------------------------"
errors="$(grep -E "ERROR\[|ModError|Runtime error|stack traceback" "$LOG" 2>/dev/null)"
# (le remplacement d'un mod du jeu par un mod du même nom, ex. Farming Redo, est attendu)
warnings="$(grep -E "WARNING\[" "$LOG" 2>/dev/null \
	| grep -v -E "Mod name conflict detected|Will not load: |Overridden by: " \
	| grep -i -E "$MODNAME|deprecated|unknown|undeclared|global" )"
own="$(grep -E "\[$MODNAME\]" "$LOG" 2>/dev/null)"

[ -n "$own" ] && { echo "Messages du mod :"; echo "$own" | sed 's/^/  /'; }

status=0
if [ "$started" != 1 ]; then
	echo "ÉCHEC : le serveur n'a pas démarré (crash au chargement ou timeout ${START_TIMEOUT}s)."
	status=1
fi
if [ -n "$errors" ]; then
	echo "ERREURS :"; echo "$errors" | sed 's/^/  /' | head -60
	status=1
fi
if [ -n "$warnings" ]; then
	echo "AVERTISSEMENTS (mod / API dépréciée / inconnu) :"; echo "$warnings" | sed 's/^/  /' | head -60
	status=1
fi
[ "$status" = 0 ] && echo "OK : '$MODNAME' se charge sans erreur ni avertissement."
echo "Log complet : $LOG"
exit $status
