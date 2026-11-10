-- Blocs construits ou fabriqués : blocs de patate, patate vénéneuse (et ses blocs
-- compressés), purée, tête, pelures (16 couleurs), briques, nuage de fécule.

local S = cavepatate.S
local util = cavepatate.util
local tex = util.tex
local name = util.name

local stone_sounds = default.node_sound_stone_defaults()
local soft_sounds = default.node_sound_dirt_defaults()
local leaves_sounds = default.node_sound_leaves_defaults()

-- Patate ----------------------------------------------------------------------

core.register_node(name("potato_block"), {
	description = S("Block of Potatoes"),
	tiles = { tex("potato_block") },
	is_ground_content = false,
	groups = { choppy = 3, oddly_breakable_by_hand = 2, flammable = 2 },
	sounds = soft_sounds,
})

core.register_node(name("potato_flesh"), {
	description = S("Potato Flesh"),
	tiles = { tex("potato_flesh") },
	is_ground_content = false,
	groups = { crumbly = 2, oddly_breakable_by_hand = 2 },
	sounds = soft_sounds,
})

-- Patate vénéneuse : bloc et quatre niveaux de compression (9 blocs -> 1).
core.register_node(name("blighted_potato_block"), {
	description = S("Blighted Potato Block"),
	tiles = { tex("blighted_potato_block") },
	is_ground_content = false,
	paramtype = "light",
	light_source = 2,
	groups = { choppy = 3, oddly_breakable_by_hand = 2 },
	sounds = soft_sounds,
})

cavepatate.compressed = {
	{ "blighted_potato_block_compressed", S("Compressed Blighted Potato Block"), 50 },
	{ "blighted_potato_block_double", S("Double Compressed Blighted Potato Block"), 95 },
	{ "blighted_potato_block_triple", S("Triple Compressed Blighted Potato Block"), 140 },
	{ "blighted_potato_block_quadruple", S("Quadruple Compressed Blighted Potato Block"), 185 },
}
for i, b in ipairs(cavepatate.compressed) do
	core.register_node(name(b[1]), {
		description = b[2],
		tiles = { tex("blighted_potato_block") .. "^[colorize:#16240c:" .. b[3] .. "^" .. tex("compressed_frame") },
		is_ground_content = false,
		paramtype = "light",
		light_source = 2 + i,
		groups = { choppy = 2, oddly_breakable_by_hand = 1, level = math.min(i, 2) },
		sounds = soft_sounds,
	})
end

-- Purée vénéneuse : couches empilables (comme la neige), amortit les chutes et
-- colle aux pieds (impossible d'y sauter).
local MASH_STEP = 8 -- 1/8 de bloc par couche (param2 en 1/64)
core.register_node(name("blighted_mash"), {
	description = S("Blighted Mashed Potato"),
	drawtype = "nodebox",
	tiles = { tex("blighted_mash") },
	paramtype = "light",
	paramtype2 = "leveled",
	place_param2 = MASH_STEP,
	leveled_max = 64,
	is_ground_content = false,
	node_box = { type = "leveled", fixed = { -0.5, -0.5, -0.5, 0.5, -0.5 + 2 / 16, 0.5 } },
	groups = { crumbly = 3, oddly_breakable_by_hand = 3, fall_damage_add_percent = -100, disable_jump = 1 },
	sounds = soft_sounds,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" then
			local under = pointed_thing.under
			local node = core.get_node(under)
			if node.name == name("blighted_mash") and node.param2 < 64 then
				local pname = placer and placer:get_player_name() or ""
				if core.is_protected(under, pname) then
					core.record_protection_violation(under, pname)
					return itemstack
				end
				core.swap_node(under, { name = node.name, param2 = math.min(64, node.param2 + MASH_STEP) })
				if not core.is_creative_enabled(pname) then
					itemstack:take_item()
				end
				return itemstack
			end
		end
		return core.item_place(itemstack, placer, pointed_thing)
	end,
	drop = name("blighted_mash"),
})

core.register_node(name("blighted_head"), {
	description = S("Blighted Potato Head"),
	drawtype = "nodebox",
	tiles = { tex("blighted_potato_block"), tex("blighted_potato_block"), tex("blighted_potato_block"),
		tex("blighted_potato_block"), tex("blighted_potato_block"), tex("blighted_head_face") },
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	node_box = { type = "fixed", fixed = { -5 / 16, -0.5, -5 / 16, 5 / 16, 3 / 16, 5 / 16 } },
	groups = { choppy = 3, oddly_breakable_by_hand = 2 },
	sounds = soft_sounds,
})

-- Pelures : bloc naturel et 15 couleurs (teintures de Minetest Game).
cavepatate.peel_colors = {
	{ "white", S("White Peel Block"), "#f2efe6" }, { "grey", S("Grey Peel Block"), "#9c9a94" },
	{ "dark_grey", S("Dark Grey Peel Block"), "#55534e" }, { "black", S("Black Peel Block"), "#2b2a28" },
	{ "violet", S("Violet Peel Block"), "#8a4cc4" }, { "blue", S("Blue Peel Block"), "#3a5ccc" },
	{ "cyan", S("Cyan Peel Block"), "#2fa8b8" }, { "dark_green", S("Dark Green Peel Block"), "#356b25" },
	{ "green", S("Green Peel Block"), "#79c43a" }, { "yellow", S("Yellow Peel Block"), "#e8d038" },
	{ "brown", S("Brown Peel Block"), "#7a4c26" }, { "orange", S("Orange Peel Block"), "#e27a26" },
	{ "red", S("Red Peel Block"), "#c42a24" }, { "magenta", S("Magenta Peel Block"), "#c43aa6" },
	{ "pink", S("Pink Peel Block"), "#f29ab8" },
}

core.register_node(name("peel_block"), {
	description = S("Peel Block"),
	tiles = { tex("peel_block") .. "^[multiply:#b0804c" },
	is_ground_content = false,
	groups = { snappy = 2, oddly_breakable_by_hand = 2, flammable = 3, peel_block = 1 },
	sounds = leaves_sounds,
})

for _, col in ipairs(cavepatate.peel_colors) do
	core.register_node(name("peel_block_" .. col[1]), {
		description = col[2],
		tiles = { tex("peel_block") .. "^[multiply:" .. col[3] },
		is_ground_content = false,
		groups = { snappy = 2, oddly_breakable_by_hand = 2, flammable = 3, peel_block = 1 },
		sounds = leaves_sounds,
	})
end

-- Pelures corrompues : scintillent (texture animée) et luisent faiblement.
core.register_node(name("blighted_peel_block"), {
	description = S("Corrupted Peel Block"),
	tiles = { {
		name = tex("blighted_peel_block"),
		animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.4 },
	} },
	paramtype = "light",
	light_source = 4,
	is_ground_content = false,
	groups = { snappy = 2, oddly_breakable_by_hand = 2 },
	sounds = leaves_sounds,
})

-- Briques de patate cuite, calcinées et rassies.
for _, b in ipairs({
	{ "baked_brick", S("Baked Potato Bricks") },
	{ "charred_brick", S("Charred Potato Bricks") },
	{ "stale_brick", S("Stale Potato Bricks") },
}) do
	core.register_node(name(b[1]), {
		description = b[2],
		tiles = { tex(b[1]) },
		is_ground_content = false,
		groups = { cracky = 2, stone = 1 },
		sounds = stone_sounds,
	})
end

-- Nuage de fécule : flotte dans la cave ; peut se poser dans le vide, à deux
-- blocs devant soi (clic droit sans viser de bloc).
local function place_in_air(itemstack, user)
	if not (user and user:is_player()) then
		return itemstack
	end
	local pname = user:get_player_name()
	local eye = vector.offset(user:get_pos(), 0, user:get_properties().eye_height or 1.5, 0)
	local pos = vector.round(vector.add(eye, vector.multiply(user:get_look_dir(), 2)))
	local def = core.registered_nodes[core.get_node(pos).name]
	if not (def and def.buildable_to) then
		return itemstack
	end
	if core.is_protected(pos, pname) then
		core.record_protection_violation(pos, pname)
		return itemstack
	end
	core.set_node(pos, { name = name("starch_cloud") })
	if not core.is_creative_enabled(pname) then
		itemstack:take_item()
	end
	return itemstack
end

core.register_node(name("starch_cloud"), {
	description = S("Starch Cloud"),
	tiles = { tex("starch_cloud") },
	is_ground_content = false,
	groups = { snappy = 3, oddly_breakable_by_hand = 3 },
	sounds = leaves_sounds,
	on_secondary_use = place_in_air,
})
