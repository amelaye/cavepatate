-- Cavepatate : point d'entrée du mod.
-- Ce fichier ne contient que l'initialisation du namespace et le chargement
-- ordonné des modules de src/. La logique vit dans src/.

local modname = core.get_current_modname()
local modpath = core.get_modpath(modname)
local S = core.get_translator(modname)

cavepatate = {
	modname = modname,
	modpath = modpath,
	S = S,
	farming_redo = rawget(_G, "farming") ~= nil and farming.mod == "redo",
}

local function load(file)
	dofile(modpath .. "/src/" .. file .. ".lua")
end

-- Ordre : utilitaires -> objets -> blocs -> formes dérivées -> recettes -> placement
-- des caves -> structures -> générateur -> butin -> commandes.
load("util")
load("items")
load("nodes")
load("blocks")
load("wood")
load("machines")
load("shapes")
load("crafts")
load("cave")
load("structures")
load("mapgen")
load("loot")
load("commands")

if not cavepatate.farming_redo then
	core.log("action", "[" .. modname .. "] Farming Redo not detected: potato recipes, drops and loot are disabled")
end
