-- Recettes. Celles qui utilisent des objets d'autres mods (Farming Redo, teintures,
-- lingots de Minetest Game, bouteilles) ne sont enregistrées que si ces objets existent.

local util = cavepatate.util
local name = util.name
local has = util.item_exists

local function craft(def)
	-- ignore la recette si un ingrédient (hors groupes) n'existe pas
	local items = {}
	if type(def.recipe) == "string" then
		items = { def.recipe }
	else
		for _, row in ipairs(def.recipe) do
			for _, it in ipairs(type(row) == "table" and row or { row }) do
				items[#items + 1] = it
			end
		end
	end
	for _, it in ipairs(items) do
		if it ~= "" and not it:find("^group:") and not has(it) then
			return
		end
	end
	core.register_craft(def)
end

local POTATO, BAKED = "farming:potato", "farming:baked_potato"
local BLIGHTED = name("blighted_potato")
local STEEL, COPPER = "default:steel_ingot", "default:copper_ingot"
local planks, starch = name("tuber_planks"), name("starchstone")

-- Roches
craft({ type = "cooking", output = name("tuberstone"), recipe = name("tuberstone_rubble") })
craft({ output = name("tuberstone_brick") .. " 4",
	recipe = { { name("tuberstone"), name("tuberstone") }, { name("tuberstone"), name("tuberstone") } } })
craft({ output = starch, recipe = {
	{ name("potato_gratings"), name("potato_gratings") }, { name("potato_gratings"), name("potato_gratings") } } })
craft({ type = "shapeless", output = name("potato_gratings") .. " 4", recipe = { starch } })

-- Briques de patate
craft({ output = name("baked_brick"), recipe = { { BAKED, BAKED }, { BAKED, BAKED } } })
craft({ type = "cooking", output = name("baked_brick"), recipe = name("tuber_soil") })
craft({ type = "cooking", output = name("charred_brick"), recipe = name("baked_brick") })
craft({ type = "shapeless", output = name("stale_brick"), recipe = { BLIGHTED, BLIGHTED, BAKED, BAKED } })

-- Bois
craft({ output = planks .. " 4", recipe = { { name("tuber_stem") } } })
craft({ output = name("tuber_pedicel") .. " 4", recipe = { { name("tuber_stem") }, { name("tuber_stem") } } })

-- Patates
craft({ output = name("potato_block"), recipe = {
	{ POTATO, POTATO, POTATO }, { POTATO, POTATO, POTATO }, { POTATO, POTATO, POTATO } } })
craft({ output = POTATO .. " 9", recipe = { { name("potato_block") } } })
craft({ output = name("potato_flesh"), recipe = { { POTATO, POTATO }, { POTATO, POTATO } } })
craft({ type = "shapeless", output = name("glow_sprout") .. " 2", recipe = { POTATO, name("toxic_sap") } })
craft({ type = "shapeless", output = name("mighty_potato"), recipe = { name("potato_block"), name("toxic_sap") } })

-- Pelures
local PEEL = name("potato_peel")
craft({ output = name("peel_carpet") .. " 6", recipe = { { PEEL, PEEL, PEEL } } })
craft({ output = name("peel_block"), recipe = { { PEEL, PEEL, PEEL }, { PEEL, PEEL, PEEL }, { PEEL, PEEL, PEEL } } })
craft({ output = PEEL .. " 9", recipe = { { name("peel_block") } } })
for _, col in ipairs(cavepatate.peel_colors) do
	craft({ type = "shapeless", output = name("peel_block_" .. col[1]), recipe = { "group:peel_block", "dye:" .. col[1] } })
end
craft({ type = "shapeless", output = name("blighted_peel_block"), recipe = { "group:peel_block", BLIGHTED, BLIGHTED } })
craft({ type = "cooking", output = name("hash_brown"), recipe = PEEL })
craft({ type = "cooking", output = name("fries"), recipe = name("potato_sticks") })

-- Patate vénéneuse et ses blocs compressés (9 -> 1, et retour)
local chain = { BLIGHTED, name("blighted_potato_block") }
for _, b in ipairs(cavepatate.compressed) do
	chain[#chain + 1] = name(b[1])
end
for i = 1, #chain - 1 do
	local a, b = chain[i], chain[i + 1]
	craft({ output = b, recipe = { { a, a, a }, { a, a, a }, { a, a, a } } })
	craft({ output = a .. " 9", recipe = { { b } } })
end
craft({ type = "shapeless", output = name("blighted_mash") .. " 2", recipe = { BLIGHTED, BLIGHTED, BLIGHTED } })
craft({ type = "shapeless", output = name("blighted_head"),
	recipe = { name("blighted_potato_block"), name("toxic_sap"), name("toxic_sap") } })
craft({ type = "shapeless", output = name("floatater"),
	recipe = { name("potato_flesh"), name("potato_flesh"), name("potato_block"), name("toxic_sap") } })

-- Machines et blocs fonctionnels
craft({ output = name("fryer"), recipe = {
	{ STEEL, "", STEEL }, { STEEL, name("potato_oil"), STEEL }, { planks, planks, planks } } })
craft({ output = name("potato_slicer"), recipe = {
	{ STEEL, STEEL, STEEL }, { "", STEEL, "" }, { starch, starch, starch } } })
craft({ output = name("refinery"), recipe = {
	{ COPPER, "default:glass", COPPER }, { COPPER, "", COPPER }, { starch, starch, starch } } })
craft({ output = name("tuber_battery_off"), recipe = {
	{ COPPER, name("toxic_oil"), COPPER }, { name("potato_block"), name("potato_block"), name("potato_block") } } })
craft({ output = name("pedestal"), recipe = {
	{ name("baked_brick"), name("baked_brick"), name("baked_brick") }, { "", starch, "" }, { starch, starch, starch } } })

-- Combustibles
craft({ type = "fuel", recipe = name("potato_oil"), burntime = 40,
	replacements = has("vessels:glass_bottle") and { { name("potato_oil"), "vessels:glass_bottle" } } or nil })
craft({ type = "fuel", recipe = name("toxic_sap"), burntime = 20 })
