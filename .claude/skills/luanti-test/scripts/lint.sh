#!/usr/bin/env bash
# Lint du mod cavepatate.
#  - luacheck s'il est installé (brew install luacheck) avec la config du skill ;
#  - sinon : vérification syntaxique + détection des globales via le bytecode LuaJIT.
# Usage : .claude/skills/luanti-test/scripts/lint.sh [fichiers.lua...]
set -uo pipefail
MOD_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
CFG="$MOD_DIR/.claude/skills/luanti-test/luacheckrc"
cd "$MOD_DIR"

if [ "$#" -gt 0 ]; then FILES=("$@"); else
	FILES=(); while IFS= read -r f; do FILES+=("$f"); done < <(find . -name '*.lua' -not -path './.claude/*' | sort)
fi
[ "${#FILES[@]}" -eq 0 ] && { echo "Aucun fichier Lua."; exit 0; }

if command -v luacheck >/dev/null 2>&1; then
	luacheck --config "$CFG" --no-color "${FILES[@]}"
	exit $?
fi

command -v luajit >/dev/null 2>&1 || { echo "Ni luacheck ni luajit disponibles."; exit 2; }
echo "(luacheck absent : fallback LuaJIT — 'brew install luacheck' pour une analyse complète)"

WRITE_OK=" cavepatate "
READ_OK=" core minetest vector ItemStack VoxelArea VoxelManip PseudoRandom PcgRandom SecureRandom
 PerlinNoise PerlinNoiseMap ValueNoise ValueNoiseMap Settings AreaStore Raycast dump dump2 DIR_DELIM INIT PLATFORM
 assert error pcall xpcall select next type tostring tonumber pairs ipairs print unpack rawget rawset rawequal rawlen
 setmetatable getmetatable dofile loadstring load _G _VERSION table string math os io debug bit jit coroutine
 collectgarbage require
 default farming stairs doors screwdriver sfinv creative dye bucket xpanes walls beds fire tnt player_api dungeon_loot
 hopper pipeworks mesecon unified_inventory i3 mcl_formspec cavepatate "

status=0
for f in "${FILES[@]}"; do
	if ! out="$(luajit -bl "$f" 2>&1)"; then
		echo "$f: ERREUR DE SYNTAXE"; echo "$out" | head -5 | sed 's/^/    /'; status=1; continue
	fi
	for g in $(echo "$out" | sed -n 's/.*GSET.*; "\(.*\)"$/\1/p' | sort -u); do
		case "$WRITE_OK" in *" $g "*) ;; *) echo "$f: globale ÉCRITE non autorisée : $g (oubli de 'local' ?)"; status=1 ;; esac
	done
	for g in $(echo "$out" | sed -n 's/.*GGET.*; "\(.*\)"$/\1/p' | sort -u); do
		case "$READ_OK" in *" $g "*) ;; *) echo "$f: globale lue inconnue : $g (faute de frappe ? dépendance manquante ?)"; status=1 ;; esac
	done
done
[ "$status" = 0 ] && echo "OK : ${#FILES[@]} fichier(s), syntaxe valide, aucune globale suspecte."
exit $status
