-- Utilitaires partagés (sans effet de bord à l'exécution du fichier).

local util = {}
cavepatate.util = util

--- Préfixe un nom local avec le nom du mod : util.name("cave") -> "cavepatate:cave".
function util.name(localname)
	return cavepatate.modname .. ":" .. localname
end

--- Nom de texture du mod : util.tex("cave_top") -> "cavepatate_cave_top.png".
function util.tex(localname)
	return cavepatate.modname .. "_" .. localname .. ".png"
end

--- Vrai si l'item/node est enregistré (utile pour l'intégration farming).
function util.item_exists(name)
	return core.registered_items[name] ~= nil
end

--- Retourne le premier item existant parmi une liste de candidats, ou nil.
function util.first_existing(...)
	for _, name in ipairs({...}) do
		if core.registered_items[name] then
			return name
		end
	end
end
