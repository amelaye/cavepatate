-- Blocs fonctionnels : friteuse, trancheuse, raffinerie, pile à patates, piédestal et
-- tubercule flottant. (Rien qui attaque les joueurs : pas de mobs ni d'équivalent.)

local S = cavepatate.S
local util = cavepatate.util
local tex = util.tex
local name = util.name

local wood_sounds = default.node_sound_wood_defaults()
local stone_sounds = default.node_sound_stone_defaults()
local metal_sounds = default.node_sound_metal_defaults()

local function can_use(pos, player)
	if not (player and player:is_player()) then
		return false
	end
	local pname = player:get_player_name()
	if core.is_protected(pos, pname) then
		core.record_protection_violation(pos, pname)
		return false
	end
	return true
end

local function give(player, pos, stack)
	local left = player:get_inventory():add_item("main", stack)
	if not left:is_empty() then
		core.add_item(vector.offset(pos, 0, 1, 0), left)
	end
end

local function puff(pos, texture)
	core.add_particlespawner({
		amount = 10, time = 0.6,
		minpos = vector.offset(pos, -0.3, 0.5, -0.3), maxpos = vector.offset(pos, 0.3, 0.6, 0.3),
		minvel = { x = -0.2, y = 0.6, z = -0.2 }, maxvel = { x = 0.2, y = 1.2, z = 0.2 },
		minexptime = 0.6, maxexptime = 1.2, minsize = 1, maxsize = 3,
		texture = texture or "default_item_smoke.png",
	})
end

-- Transforme l'objet tenu (clic droit) selon `recipes` : { [entrée] = { n, sorties... } }.
local function station(recipes, sound)
	return function(pos, node, clicker, itemstack)
		local r = recipes[itemstack:get_name()]
		if not r or itemstack:get_count() < r[1] or not can_use(pos, clicker) then
			return itemstack
		end
		if r.needs and not clicker:get_inventory():contains_item("main", r.needs) then
			return itemstack
		end
		if r.needs then
			clicker:get_inventory():remove_item("main", r.needs)
		end
		itemstack:take_item(r[1])
		for i = 2, #r do
			if util.item_exists(ItemStack(r[i]):get_name()) then
				give(clicker, pos, ItemStack(r[i]))
			end
		end
		puff(pos)
		core.sound_play(sound, { pos = pos, gain = 0.5, max_hear_distance = 12 }, true)
		return itemstack
	end
end

-- Friteuse : bâtonnets -> frites, pelures -> galettes, patate -> patate au four.
core.register_node(name("fryer"), {
	description = S("Fryer"),
	tiles = { tex("fryer_top"), tex("tuber_planks"), tex("fryer_side") },
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = { choppy = 2, oddly_breakable_by_hand = 1 },
	sounds = wood_sounds,
	on_rightclick = station({
		[name("potato_sticks")] = { 1, name("fries") },
		[name("potato_peel")] = { 1, name("hash_brown") },
		["farming:potato"] = { 1, "farming:baked_potato" },
	}, "default_cool_lava"),
})

-- Trancheuse : patate -> 4 bâtonnets + 1 pelure ; patate vénéneuse -> 3 tranches.
core.register_node(name("potato_slicer"), {
	description = S("Potato Slicer"),
	tiles = { tex("slicer_top"), tex("starchstone"), tex("slicer_side") },
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = { cracky = 2 },
	sounds = metal_sounds,
	on_rightclick = station({
		["farming:potato"] = { 1, name("potato_sticks") .. " 4", name("potato_peel") },
		[name("blighted_potato")] = { 1, name("blighted_slice") .. " 3" },
	}, "default_dig_choppy"),
})

-- Raffinerie : 4 patates (+ une bouteille vide si le mod vessels est là) -> huile.
local bottle = util.item_exists("vessels:glass_bottle") and "vessels:glass_bottle" or nil
core.register_node(name("refinery"), {
	description = S("Potato Refinery"),
	tiles = { tex("refinery_top"), tex("starchstone"), tex("refinery_side"),
		tex("refinery_side"), tex("refinery_side"), tex("refinery_front") },
	paramtype2 = "facedir",
	is_ground_content = false,
	groups = { cracky = 2 },
	sounds = metal_sounds,
	on_rightclick = station({
		["farming:potato"] = { 4, name("potato_oil"), needs = bottle },
		[name("blighted_potato")] = { 4, name("toxic_oil"), needs = bottle },
	}, "default_cool_lava"),
})

-- Pile à patates : clic droit pour l'allumer ou l'éteindre ; allumée, elle éclaire
-- et électrise qui se tient dessus.
local battery_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 6 / 16, 0.5 } }
for _, state in ipairs({ "off", "on" }) do
	local on = state == "on"
	core.register_node(name("tuber_battery_" .. state), {
		description = S("Potato Battery"),
		drawtype = "nodebox",
		tiles = { tex("battery_top_" .. state), tex("starchstone"), tex("battery_side") },
		paramtype = "light",
		is_ground_content = false,
		node_box = battery_box,
		light_source = on and 8 or 0,
		damage_per_second = on and 2 or nil,
		drop = name("tuber_battery_off"),
		groups = { cracky = 2, not_in_creative_inventory = on and 1 or nil },
		sounds = metal_sounds,
		on_rightclick = function(pos, node, clicker, itemstack)
			if can_use(pos, clicker) then
				core.swap_node(pos, { name = name("tuber_battery_" .. (on and "off" or "on")) })
				core.sound_play("default_place_node_metal", { pos = pos, gain = 0.4 }, true)
			end
			return itemstack
		end,
	})
end

-- Piédestal : décoratif, se trouve dans les ruines.
core.register_node(name("pedestal"), {
	description = S("Pedestal"),
	drawtype = "nodebox",
	tiles = { tex("baked_brick"), tex("starchstone"), tex("starchstone") },
	paramtype = "light",
	is_ground_content = false,
	node_box = { type = "fixed", fixed = {
		{ -0.5, -0.5, -0.5, 0.5, -0.25, 0.5 },
		{ -0.25, -0.25, -0.25, 0.25, 0.25, 0.25 },
		{ -0.4375, 0.25, -0.4375, 0.4375, 0.5, 0.4375 },
	} },
	groups = { cracky = 2 },
	sounds = stone_sounds,
})

-- Tubercule flottant : clic droit, il s'élève (jusqu'à 32 blocs) en emportant la
-- pile de blocs posée dessus (8 au plus, sans inventaire ni métadonnées).
local FLOAT_STEP, FLOAT_MAX, FLOAT_LOAD = 0.4, 32, 8

local function is_free(n)
	return n == "air" or n == name("cave_light")
end

local function has_meta(p)
	local t = core.get_meta(p):to_table()
	return next(t.fields) ~= nil or next(t.inventory) ~= nil
end

local function rise(pos)
	local load = {}
	for i = 1, FLOAT_LOAD + 1 do
		local p = vector.offset(pos, 0, i, 0)
		local n = core.get_node(p)
		if is_free(n.name) then
			break
		end
		if i > FLOAT_LOAD or n.name == "ignore" or has_meta(p) or core.is_protected(p, "") then
			return nil
		end
		load[#load + 1] = n
	end
	local dest = vector.offset(pos, 0, #load + 1, 0)
	if not is_free(core.get_node(dest).name) or core.is_protected(dest, "") then
		return nil
	end
	for i = #load, 1, -1 do
		core.swap_node(vector.offset(pos, 0, i + 1, 0), load[i])
	end
	local up = vector.offset(pos, 0, 1, 0)
	core.swap_node(up, { name = name("floatater") })
	core.set_node(pos, { name = "air" })
	return up
end

core.register_node(name("floatater"), {
	description = S("Floating Tuber"),
	tiles = { tex("floatater_top"), tex("floatater_top"), tex("floatater_side") },
	paramtype = "light",
	light_source = 3,
	is_ground_content = false,
	groups = { choppy = 2, oddly_breakable_by_hand = 2 },
	sounds = default.node_sound_dirt_defaults(),
	on_rightclick = function(pos, node, clicker, itemstack)
		if can_use(pos, clicker) then
			core.get_meta(pos):set_int("travel", 0)
			core.get_node_timer(pos):start(FLOAT_STEP)
		end
		return itemstack
	end,
	on_timer = function(pos)
		local travel = core.get_meta(pos):get_int("travel")
		local up = rise(pos)
		if up and travel + 1 < FLOAT_MAX then
			core.get_meta(up):set_int("travel", travel + 1)
			core.get_node_timer(up):start(FLOAT_STEP)
		end
		return false
	end,
})
