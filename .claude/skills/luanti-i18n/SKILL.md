---
name: luanti-i18n
description: Traduction du mod cavepatate (chaînes S("..."), fichiers locale/*.tr, français) et outil update_translations.py qui extrait les chaînes et met à jour template.txt et cavepatate.fr.tr. À utiliser dès qu'on ajoute ou modifie un texte visible par le joueur (description d'item, infotext, formspec, message de chat) ou avant de terminer une tâche.
---

# Traductions

## Règles

- Toute chaîne visible : `S("...")` avec `local S = cavepatate.S` en tête de fichier.
- Texte source **en anglais**, traduction **française** dans `locale/cavepatate.fr.tr`.
- Paramètres : `S("Depth: @1", y)`. Les arguments doivent être `@1`, `@2`… dans l'ordre, sans trou. **Jamais** de concaténation (`S("a") .. x`) ni de variable (`S(name)`) : l'extracteur ne les voit pas, et l'ordre des mots change selon la langue.
- Dans un formspec : `core.formspec_escape(S("..."))`.
- Pluriels : `PS()` n'est géré que par les fichiers `.po`. Avec `.tr`, reformuler (`"Items: @1"`).
- Format `.tr` : `source=traduction`. Dans le fichier, `=` s'écrit `@=` et un saut de ligne `@n`. Le script gère ces échappements.

## Outil

```bash
python3 .claude/skills/luanti-i18n/scripts/update_translations.py           # met à jour template.txt + cavepatate.fr.tr
python3 .claude/skills/luanti-i18n/scripts/update_translations.py --check   # n'écrit rien ; code 1 s'il manque des traductions
```

Le script conserve les traductions existantes, ajoute les nouvelles clés (vides) et range les clés obsolètes sous `##### plus utilisé #####`. Il signale les concaténations, les variables et les arguments mal ordonnés.

## Après chaque modification de texte

1. Lancer le script.
2. Remplir les lignes `source=` vides de `locale/cavepatate.fr.tr` en bon français, avec un ton cohérent avec MTG : majuscule initiale, pas de point final dans les noms d'objets.
3. Supprimer les entrées obsolètes une fois confirmées.
4. `--check` doit renvoyer 0.
