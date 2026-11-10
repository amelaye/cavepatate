---
name: luanti-test
description: Vérification du mod cavepatate — lint (luacheck ou fallback LuaJIT qui détecte syntaxe et globales), test de chargement headless dans le vrai moteur Luanti 5.18 (monde temporaire hors projet, analyse du log), diagnostic des erreurs. À utiliser après toute modification de code Lua, avant de déclarer une tâche terminée, ou pour diagnostiquer une erreur de chargement.
---

# Tests

Aucun mod de test annexe : on teste **cavepatate seul**, dans le moteur réel.

## 1. Lint

```bash
.claude/skills/luanti-test/scripts/lint.sh            # tout le mod
.claude/skills/luanti-test/scripts/lint.sh src/x.lua  # un fichier
```

- Avec luacheck (`brew install luacheck`) : config `.claude/skills/luanti-test/luacheckrc`.
- Sans luacheck : LuaJIT vérifie la syntaxe et repère dans le bytecode les globales **écrites** (oubli de `local`) et **lues** inconnues (faute de frappe, dépendance non déclarée). Si une globale lue est légitime (nouvelle dépendance), l'ajouter à `READ_OK` dans `lint.sh` **et** dans `luacheckrc`.

## 2. Test de chargement headless

```bash
.claude/skills/luanti-test/scripts/load_test.sh       # 5 s après démarrage
.claude/skills/luanti-test/scripts/load_test.sh 15    # laisser tourner plus longtemps (timers, after)
```

Démarre `luanti --server` avec Minetest Game et le mod (lien dans `worldmods/` d'un monde temporaire `$TMPDIR/cavepatate_loadtest`), plus les mods de `.claude/test_mods.txt`. Mapgen `singlenode`, aucun terrain généré. Signale :
- crash au chargement (`ModError`, stack traceback), serveur qui ne démarre pas ;
- `ERROR[...]` quel qu'il soit ;
- `WARNING[...]` qui mentionne le mod, une API dépréciée (`deprecated_lua_api_handling = log`), un item inconnu ou une globale non déclarée.

Code 0 = OK, 1 = problème, 2 = impossible de lancer Luanti. Le chemin du log complet est affiché. Le lire en cas de doute.

**Tester deux configurations** dès que le code touche aux patates : avec Farming Redo (`farming` dans `test_mods.txt`, ou sans l'installer : `EXTRA_WORLDMODS=<chemin d'un clone de Farming Redo> load_test.sh`) et sans. Le mod doit se charger proprement dans les deux cas. Le remplacement du farming de MTG (« Mod name conflict ») est attendu et filtré.

## 3. Ce que ces tests ne couvrent pas

- La **génération de terrain** : aucun chunk n'est généré en headless sans joueur. Elle se teste dans le monde de dev (skill `luanti-play`, commande `/cavepatate goto`, toujours dans un **nouveau** monde après une modification du générateur), puis en lisant `~/Library/Application Support/minetest/debug.txt`.
- Le rendu des textures et les formspecs : vérification visuelle en jeu.

## 4. Diagnostiquer

- `attempt to index a nil value (global 'x')` : dépendance manquante dans `mod.conf`, ou ordre de `load()` dans `init.lua`.
- `Unknown node`/`unknown item` : nom mal orthographié, ou item d'un mod optionnel absent (garder avec `util.item_exists`).
- Erreur dans `on_generated` : stack traceback dans `debug.txt` du monde de dev. Elle survient à la génération, pas au chargement.
- `Mod name conflict` : deux mods du même nom (normal pour Farming Redo qui remplace le farming de MTG : simple avertissement de remplacement).
