-- Famille du bois de tubercule (ininflammable) : tige, planches, feuillage, pousse,
-- fruit lumineux, pédicelle, porte, trappe, barrière, rambarde, portillon.

local S = cavepatate.S
local util = cavepatate.util
local tex = util.tex
local name = util.name

local wood_sounds = default.node_sound_wood_defaults()
local leaves_sounds = default.node_sound_leaves_defaults()
local WOOD_TINT = "^[multiply:#a8b070" -- teinte appliquée aux portes/trappes de Minetest Game

core.register_node(name("tuber_stem"), {
	description = S("Tuber Stem"),
	tiles = { tex("tuber_stem_top"), tex("tuber_stem_top"), tex("tuber_stem") },
	paramtype2 = "facedir",
	is_ground_content = false,
	on_place = core.rotate_node,
	groups = { tree = 1, choppy = 2, oddly_breakable_by_hand = 1 },
	sounds = wood_sounds,
})

core.register_node(name("tuber_planks"), {
	description = S("Tuber Planks"),
	tiles = { tex("tuber_planks") },
	is_ground_content = false,
	groups = { choppy = 2, oddly_breakable_by_hand = 2, wood = 1 },
	sounds = wood_sounds,
})

local leaves_drop = {
	max_items = 1,
	items = {
		{ items = { name("tuber_sprout") }, rarity = 20 },
		{ items = { name("tuber_leaves") } },
	},
}
if util.item_exists("farming:potato") then
	table.insert(leaves_drop.items, 1, { items = { "farming:potato" }, rarity = 12 })
end

core.register_node(name("tuber_leaves"), {
	description = S("Tuber Leaves"),
	drawtype = "allfaces_optional",
	waving = 2,
	tiles = { tex("tuber_leaves") },
	special_tiles = { tex("tuber_leaves") },
	use_texture_alpha = "clip",
	paramtype = "light",
	is_ground_content = false,
	groups = { snappy = 3, leafdecay = 3, leaves = 1 },
	drop = leaves_drop,
	sounds = leaves_sounds,
	after_place_node = default.after_place_leaves,
})

-- Fruit de tubercule : pend sous les feuillages, éclaire, se mange (avec un risque).
core.register_node(name("tuber_fruit"), {
	description = S("Tuber Fruit"),
	drawtype = "plantlike",
	tiles = { tex("tuber_fruit") },
	inventory_image = tex("tuber_fruit"),
	wield_image = tex("tuber_fruit"),
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	light_source = 12,
	selection_box = { type = "fixed", fixed = { -0.25, -0.25, -0.25, 0.25, 0.5, 0.25 } },
	groups = { snappy = 3, oddly_breakable_by_hand = 3, leafdecay = 3, leafdecay_drop = 1 },
	sounds = leaves_sounds,
	on_use = cavepatate.eat_risky(3, -2, 3),
	after_place_node = function(pos)
		core.set_node(pos, { name = name("tuber_fruit"), param2 = 1 }) -- posé à la main : ne pourrit pas
	end,
})

if default.register_leafdecay then
	default.register_leafdecay({
		trunks = { name("tuber_stem") },
		leaves = { name("tuber_leaves"), name("tuber_fruit") },
		radius = 6,
	})
end

-- Pousse : devient un arbre-tubercule après 5 à 15 minutes, s'il y a la place.
local function grow_tree(pos)
	local st = cavepatate.structures
	local vm = core.get_voxel_manip()
	local p1, p2 = vector.offset(pos, -7, 0, -7), vector.offset(pos, 7, 20, 7)
	local e1, e2 = vm:read_from_map(p1, p2)
	local ctx = {
		data = vm:get_data(), p2 = vm:get_param2_data(),
		area = VoxelArea:new({ MinEdge = e1, MaxEdge = e2 }), minp = p1, maxp = p2,
		pr = PcgRandom(core.hash_node_position(pos) + core.get_us_time() % 100000),
		c = cavepatate.content_ids(), reserved = {},
	}
	ctx.data[ctx.area:indexp(pos)] = ctx.c.air
	if not st.tuber_tree(ctx, pos.x, pos.y, pos.z) then
		return false
	end
	vm:set_data(ctx.data)
	vm:set_param2_data(ctx.p2)
	vm:write_to_map()
	return true
end

core.register_node(name("tuber_sprout"), {
	description = S("Tuber Sprout"),
	drawtype = "plantlike",
	tiles = { tex("tuber_sprout") },
	inventory_image = tex("tuber_sprout"),
	wield_image = tex("tuber_sprout"),
	use_texture_alpha = "clip",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	selection_box = { type = "fixed", fixed = { -0.3, -0.5, -0.3, 0.3, 0.35, 0.3 } },
	groups = { snappy = 2, dig_immediate = 3, attached_node = 1, sapling = 1 },
	sounds = leaves_sounds,
	on_construct = function(pos)
		core.get_node_timer(pos):start(math.random(300, 900))
	end,
	on_timer = function(pos)
		if not grow_tree(pos) then
			core.get_node_timer(pos):start(math.random(120, 300))
		end
	end,
})

-- Pédicelle : fin poteau de tubercule (étais des galeries).
core.register_node(name("tuber_pedicel"), {
	description = S("Tuber Pedicel"),
	drawtype = "nodebox",
	tiles = { tex("tuber_stem_top"), tex("tuber_stem_top"), tex("tuber_stem") },
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	on_place = core.rotate_node,
	node_box = { type = "fixed", fixed = { -2 / 16, -0.5, -2 / 16, 2 / 16, 0.5, 2 / 16 } },
	groups = { choppy = 2, oddly_breakable_by_hand = 2 },
	sounds = wood_sounds,
})

-- Porte, trappe, barrière, rambarde et portillon (API de Minetest Game).
local planks = name("tuber_planks")

if rawget(_G, "doors") then
	doors.register(name("tuber_door"), {
		description = S("Tuber Door"),
		tiles = { { name = "doors_door_wood.png" .. WOOD_TINT, backface_culling = true } },
		inventory_image = "doors_item_wood.png" .. WOOD_TINT,
		groups = { node = 1, choppy = 2, oddly_breakable_by_hand = 2 },
		recipe = { { planks, planks }, { planks, planks }, { planks, planks } },
	})
	doors.register_trapdoor(name("tuber_trapdoor"), {
		description = S("Tuber Trapdoor"),
		inventory_image = "doors_trapdoor.png" .. WOOD_TINT,
		wield_image = "doors_trapdoor.png" .. WOOD_TINT,
		tile_front = "doors_trapdoor.png" .. WOOD_TINT,
		tile_side = "doors_trapdoor_side.png" .. WOOD_TINT,
		groups = { choppy = 2, oddly_breakable_by_hand = 2, door = 1 },
		sounds = wood_sounds,
	})
	core.register_craft({
		output = name("tuber_trapdoor") .. " 2",
		recipe = { { planks, planks, planks }, { planks, planks, planks } },
	})
	if doors.register_fencegate then
		doors.register_fencegate(name("tuber_fence_gate"), {
			description = S("Tuber Fence Gate"),
			texture = tex("tuber_planks"),
			material = planks,
			groups = { choppy = 2, oddly_breakable_by_hand = 2 },
			sounds = wood_sounds,
		})
	end
end

if default.register_fence then
	default.register_fence(name("tuber_fence"), {
		description = S("Tuber Fence"),
		texture = tex("tuber_planks"),
		material = planks,
		groups = { choppy = 2, oddly_breakable_by_hand = 2 },
		sounds = wood_sounds,
	})
end
if default.register_fence_rail then
	default.register_fence_rail(name("tuber_fence_rail"), {
		description = S("Tuber Fence Rail"),
		texture = tex("tuber_planks"),
		material = planks,
		groups = { choppy = 2, oddly_breakable_by_hand = 2 },
		sounds = wood_sounds,
	})
end
