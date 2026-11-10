-- Terrain de la cave patate : roches, minerais, sols, végétation de cave et nœuds
-- techniques du générateur. (Blocs construits : blocks.lua ; bois : wood.lua.)

local S = cavepatate.S
local util = cavepatate.util
local tex = util.tex
local name = util.name

local stone_sounds = default.node_sound_stone_defaults()
local soft_sounds = default.node_sound_dirt_defaults()
local sand_sounds = default.node_sound_sand_defaults()
local leaves_sounds = default.node_sound_leaves_defaults()

-- Tous les nœuds de la cave ont is_ground_content = false : sinon les grottes de
-- Minetest Game creusent la coque aux jointures de chunks.

-- Roches ----------------------------------------------------------------------

core.register_node(name("tuberstone"), {
	description = S("Tuberstone"),
	tiles = { tex("tuberstone") },
	is_ground_content = false,
	groups = { cracky = 3, stone = 1 },
	drop = name("tuberstone_rubble"),
	sounds = stone_sounds,
})

core.register_node(name("tuberstone_rubble"), {
	description = S("Tuberstone Rubble"),
	tiles = { tex("tuberstone_rubble") },
	is_ground_content = false,
	groups = { cracky = 3, stone = 2 },
	sounds = stone_sounds,
})

core.register_node(name("tuberstone_brick"), {
	description = S("Tuberstone Bricks"),
	tiles = { tex("tuberstone_brick") },
	is_ground_content = false,
	groups = { cracky = 2, stone = 1 },
	sounds = stone_sounds,
})

core.register_node(name("tuberstone_blighted"), {
	description = S("Blighted Tuberstone"),
	tiles = { tex("tuberstone_blighted") },
	is_ground_content = false,
	groups = { cracky = 3, stone = 1 },
	sounds = stone_sounds,
})

core.register_node(name("starchstone"), {
	description = S("Starchstone"),
	tiles = { tex("starchstone") },
	is_ground_content = false,
	groups = { cracky = 3, stone = 1 },
	sounds = stone_sounds,
})

-- Minerais : ceux de Minetest Game, mais dans la roche-tubercule (le générateur
-- convertit les minerais existants), plus deux minerais propres à la cave.

cavepatate.ores = {} -- nom du minerai MTG -> nom du minerai en roche-tubercule

local MTG_ORES = {
	{ "coal", S("Coal Ore in Tuberstone"), "default:coal_lump", 3 },
	{ "iron", S("Iron Ore in Tuberstone"), "default:iron_lump", 2 },
	{ "copper", S("Copper Ore in Tuberstone"), "default:copper_lump", 2 },
	{ "tin", S("Tin Ore in Tuberstone"), "default:tin_lump", 2 },
	{ "gold", S("Gold Ore in Tuberstone"), "default:gold_lump", 2 },
	{ "mese", S("Mese Ore in Tuberstone"), "default:mese_crystal", 1 },
	{ "diamond", S("Diamond Ore in Tuberstone"), "default:diamond", 1 },
}

for _, o in ipairs(MTG_ORES) do
	if util.item_exists(o[3]) then
		local ore = name("tuberstone_with_" .. o[1])
		core.register_node(ore, {
			description = o[2],
			tiles = { tex("tuberstone") .. "^default_mineral_" .. o[1] .. ".png" },
			is_ground_content = false,
			groups = { cracky = o[4] },
			drop = o[3],
			sounds = stone_sounds,
		})
		cavepatate.ores["default:stone_with_" .. o[1]] = ore
	end
end

core.register_node(name("tuberstone_with_blight"), {
	description = S("Blighted Potato Ore"),
	tiles = { tex("tuberstone") .. "^" .. tex("mineral_blight") },
	is_ground_content = false,
	groups = { cracky = 3 },
	drop = {
		max_items = 1,
		items = {
			{ items = { name("blighted_potato") .. " 3" }, rarity = 4 },
			{ items = { name("blighted_potato") .. " 2" }, rarity = 2 },
			{ items = { name("blighted_potato") } },
		},
	},
	sounds = stone_sounds,
})

core.register_node(name("tuberstone_with_sap"), {
	description = S("Toxic Sap Ore"),
	tiles = { tex("tuberstone") .. "^" .. tex("mineral_sap") },
	is_ground_content = false,
	paramtype = "light",
	light_source = 3,
	groups = { cracky = 2 },
	drop = name("toxic_sap") .. " 2",
	sounds = stone_sounds,
})

-- Sols ------------------------------------------------------------------------

-- Labourable à la houe (Minetest Game et Farming Redo lisent le champ `soil`).
local SOIL = { base = name("tuber_soil"), dry = name("tuber_farmland"), wet = name("tuber_farmland_wet") }

core.register_node(name("tuber_soil"), {
	description = S("Tuber Soil"),
	tiles = { tex("tuber_soil") },
	is_ground_content = false,
	groups = { crumbly = 3, soil = 1 },
	soil = SOIL,
	sounds = soft_sounds,
})

core.register_node(name("peel_turf"), {
	description = S("Peel Turf"),
	tiles = { tex("peel_turf_top"), tex("tuber_soil"),
		{ name = tex("tuber_soil") .. "^" .. tex("peel_turf_side"), tileable_vertical = false } },
	is_ground_content = false,
	groups = { crumbly = 3, soil = 1 },
	soil = { base = name("peel_turf"), dry = SOIL.dry, wet = SOIL.wet },
	drop = name("tuber_soil"),
	sounds = soft_sounds,
})

core.register_node(name("blighted_peel_turf"), {
	description = S("Blighted Peel Turf"),
	tiles = { tex("blighted_peel_turf_top"), tex("tuber_soil"),
		{ name = tex("tuber_soil") .. "^" .. tex("blighted_peel_turf_side"), tileable_vertical = false } },
	is_ground_content = false,
	groups = { crumbly = 3, soil = 1 },
	soil = { base = name("blighted_peel_turf"), dry = SOIL.dry, wet = SOIL.wet },
	drop = name("tuber_soil"),
	sounds = soft_sounds,
})

core.register_node(name("tuber_farmland"), {
	description = S("Tuber Farmland"),
	tiles = { tex("tuber_farmland"), tex("tuber_soil") },
	is_ground_content = false,
	drop = name("tuber_soil"),
	groups = { crumbly = 3, not_in_creative_inventory = 1, soil = 2, grassland = 1, field = 1 },
	soil = SOIL,
	sounds = soft_sounds,
})

core.register_node(name("tuber_farmland_wet"), {
	description = S("Wet Tuber Farmland"),
	tiles = { tex("tuber_farmland") .. "^[colorize:#1e140a:90", tex("tuber_soil") .. "^[colorize:#1e140a:60" },
	is_ground_content = false,
	drop = name("tuber_soil"),
	groups = { crumbly = 3, not_in_creative_inventory = 1, soil = 3, wet = 1, grassland = 1, field = 1 },
	soil = SOIL,
	sounds = soft_sounds,
})

core.register_node(name("tuber_path"), {
	description = S("Tuber Path"),
	drawtype = "nodebox",
	tiles = { tex("tuber_path"), tex("tuber_soil"), tex("tuber_soil") },
	paramtype = "light",
	is_ground_content = false,
	node_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.4375, 0.5 } },
	drop = name("tuber_soil"),
	groups = { crumbly = 3 },
	sounds = soft_sounds,
})

core.register_node(name("potato_gratings"), {
	description = S("Potato Gratings"),
	tiles = { tex("potato_gratings") },
	is_ground_content = false,
	groups = { crumbly = 3, falling_node = 1, sand = 1 },
	sounds = sand_sounds,
})

-- Végétation de cave ------------------------------------------------------------

core.register_node(name("peel_carpet"), {
	description = S("Peel Carpet"),
	drawtype = "nodebox",
	tiles = { tex("peel_carpet") },
	inventory_image = tex("peel_carpet"),
	wield_image = tex("peel_carpet"),
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	floodable = true,
	node_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, -0.4375, 0.5 } },
	groups = { snappy = 3, oddly_breakable_by_hand = 3, flammable = 3, attached_node = 1 },
	sounds = leaves_sounds,
})

-- Pointe de tubercule : pousse en épis au sol et au plafond, blesse qui s'y tient.
core.register_node(name("tuber_spike"), {
	description = S("Tuber Spike"),
	drawtype = "plantlike",
	tiles = { tex("tuber_spike") },
	inventory_image = tex("tuber_spike"),
	wield_image = tex("tuber_spike"),
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	damage_per_second = 1,
	selection_box = {
		type = "wallmounted",
		wall_bottom = { -0.25, -0.5, -0.25, 0.25, 0.4, 0.25 },
		wall_top = { -0.25, -0.4, -0.25, 0.25, 0.5, 0.25 },
		wall_side = { -0.5, -0.25, -0.25, 0.4, 0.25, 0.25 },
	},
	groups = { cracky = 3, oddly_breakable_by_hand = 2, attached_node = 1 },
	sounds = stone_sounds,
})

core.register_node(name("tuber_flower"), {
	description = S("Tuber Flower"),
	drawtype = "plantlike",
	tiles = { tex("tuber_flower") },
	inventory_image = tex("tuber_flower"),
	wield_image = tex("tuber_flower"),
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	floodable = true,
	waving = 1,
	selection_box = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0.3, 0.25 } },
	-- flower + color_violet : Minetest Game en tire de la teinture violette
	groups = { snappy = 3, flower = 1, flora = 1, attached_node = 1, color_violet = 1, flammable = 1 },
	sounds = leaves_sounds,
})

core.register_node(name("glow_sprout"), {
	description = S("Glowing Sprout"),
	drawtype = "plantlike",
	tiles = { tex("glow_sprout") },
	inventory_image = tex("glow_sprout"),
	wield_image = tex("glow_sprout"),
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	buildable_to = true,
	floodable = true,
	waving = 1,
	light_source = 9,
	selection_box = { type = "fixed", fixed = { -0.3, -0.5, -0.3, 0.3, 0.1, 0.3 } },
	groups = { snappy = 3, oddly_breakable_by_hand = 3, attached_node = 1, flammable = 1 },
	sounds = leaves_sounds,
})

-- Racines : faibles (pendantes, la chaîne tombe d'un coup) et robustes.
local function drop_chain_below(pos, digger, node_name)
	local p = vector.offset(pos, 0, -1, 0)
	while core.get_node(p).name == node_name do
		if digger and digger:is_player() and core.is_protected(p, digger:get_player_name()) then
			return
		end
		core.remove_node(p)
		core.add_item(p, node_name)
		p.y = p.y - 1
	end
end

core.register_node(name("hanging_root"), {
	description = S("Weak Root"),
	drawtype = "plantlike",
	tiles = { tex("hanging_root") },
	inventory_image = tex("hanging_root"),
	wield_image = tex("hanging_root"),
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	climbable = true,
	selection_box = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0.5, 0.25 } },
	groups = { snappy = 3, oddly_breakable_by_hand = 3, flammable = 2 },
	sounds = leaves_sounds,
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		drop_chain_below(pos, digger, name("hanging_root"))
	end,
})

core.register_node(name("strong_root"), {
	description = S("Strong Root"),
	drawtype = "nodebox",
	tiles = { tex("strong_root_top"), tex("strong_root_top"), tex("strong_root") },
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	climbable = true,
	node_box = { type = "fixed", fixed = { -3 / 16, -0.5, -3 / 16, 3 / 16, 0.5, 3 / 16 } },
	groups = { choppy = 3, oddly_breakable_by_hand = 2 },
	sounds = default.node_sound_wood_defaults(),
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		drop_chain_below(pos, digger, name("strong_root"))
	end,
})

-- Patate vigoureuse : posée par un joueur, elle fait pousser des racines robustes
-- vers le bas (jusqu'à 8), une toutes les 1 à 2 minutes.
core.register_node(name("mighty_potato"), {
	description = S("Mighty Potato"),
	tiles = { tex("mighty_potato") },
	paramtype = "light",
	is_ground_content = false,
	light_source = 4,
	groups = { choppy = 2, oddly_breakable_by_hand = 1 },
	sounds = soft_sounds,
	after_place_node = function(pos)
		core.get_node_timer(pos):start(math.random(60, 120))
	end,
	on_timer = function(pos)
		local p = vector.offset(pos, 0, -1, 0)
		for _ = 1, 8 do
			local n = core.get_node(p).name
			if n == "air" or n == name("cave_light") then
				core.set_node(p, { name = name("strong_root") })
				return true
			elseif n ~= name("strong_root") then
				return false
			end
			p.y = p.y - 1
		end
		return false
	end,
})

-- Nœuds techniques (générateur) -------------------------------------------------

-- Lumière invisible qui rend la cave naturellement lumineuse.
core.register_node(name("cave_light"), {
	description = S("Cave Light"),
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	light_source = math.max(0, math.min(core.LIGHT_MAX,
		tonumber(core.settings:get("cavepatate_cavity_light")) or 13)),
	drop = "",
	on_blast = function() end,
	groups = { not_in_creative_inventory = 1 },
})

-- Emplacements de coffres : le générateur ne peut pas remplir d'inventaire,
-- il pose ces marqueurs qu'un LBM (loot.lua) remplace par un coffre garni.
for _, kind in ipairs({ "loot", "loot_rich" }) do
	core.register_node(name(kind), {
		description = S("Loot Marker"),
		drawtype = "airlike",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		walkable = false,
		pointable = false,
		diggable = false,
		drop = "",
		groups = { not_in_creative_inventory = 1 },
	})
end
