-- Coffres des ruines. Le générateur ne peut pas remplir d'inventaire : il pose des
-- marqueurs invisibles (cavepatate:loot, cavepatate:loot_rich) qu'un LBM remplace
-- par un coffre garni dès que le bloc devient actif.
-- run_at_every_load = true : Luanti n'exécute jamais un LBM « une fois » sur un bloc
-- fraîchement généré. Le marqueur disparaissant, le coffre n'est garni qu'une fois.

local util = cavepatate.util

-- { objet, min, max, chance sur 100 }
local COMMON = {
	{ "farming:potato", 2, 8, 90 },
	{ "farming:baked_potato", 1, 4, 60 },
	{ "farming:samosa", 1, 2, 25 },
	{ "farming:potato_omelet", 1, 1, 15 },
	{ "cavepatate:toxic_sap", 1, 4, 40 },
	{ "cavepatate:glow_sprout", 1, 3, 35 },
	{ "cavepatate:potato_block", 1, 2, 25 },
	{ "cavepatate:tuber_planks", 2, 6, 30 },
}

local RICH = {
	{ "farming:potato", 4, 12, 100 },
	{ "farming:baked_potato", 2, 6, 80 },
	{ "farming:spanish_potatoes", 1, 2, 40 },
	{ "farming:potato_salad", 1, 2, 35 },
	{ "farming:samosa", 1, 3, 40 },
	{ "cavepatate:toxic_sap", 3, 8, 70 },
	{ "cavepatate:glow_sprout", 2, 5, 60 },
	{ "default:gold_ingot", 1, 3, 25 },
	{ "default:mese_crystal_fragment", 1, 4, 20 },
}

local function fill(inv, pr, list)
	local size = inv:get_size("main")
	for _, e in ipairs(list) do
		if util.item_exists(e[1]) and pr:next(1, 100) <= e[4] then
			local stack = ItemStack(e[1] .. " " .. pr:next(e[2], e[3]))
			for _ = 1, 8 do -- emplacement libre au hasard
				local slot = pr:next(1, size)
				if inv:get_stack("main", slot):is_empty() then
					inv:set_stack("main", slot, stack)
					stack = nil
					break
				end
			end
			if stack then
				inv:add_item("main", stack)
			end
		end
	end
end

core.register_lbm({
	label = "Cavepatate: fill ruin chests",
	name = "cavepatate:fill_loot",
	nodenames = { "cavepatate:loot", "cavepatate:loot_rich" },
	run_at_every_load = true,
	action = function(pos, node)
		local rich = node.name == "cavepatate:loot_rich"
		core.set_node(pos, { name = "default:chest", param2 = node.param2 % 4 })
		local inv = core.get_meta(pos):get_inventory()
		if inv:get_size("main") == 0 then
			inv:set_size("main", 8 * 4)
		end
		fill(inv, PcgRandom(core.hash_node_position(pos)), rich and RICH or COMMON)
	end,
})
