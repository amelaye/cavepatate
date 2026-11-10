-- Générateur des caves patate : creusement au VoxelManip après le mapgen normal,
-- puis habillage, structures, petites décorations et lumière d'ambiance.
--
-- Dans une cave (distance normalisée d < 1, déformée par un bruit 3D) :
--   * le sol suit des collines (cave.floor_at) ; quatre sous-biomes : Champs
--     (tourbe de pelures, fleurs, potagers), Bosquet (arbres-tubercules), Flétrissure
--     (tourbe flétrie, pointes, pelures corrompues) et Râpures (râpure de patate qui
--     s'effondre, cactus de pelures, puits calcinés) ;
--   * les cuvettes sous le niveau d'eau sont noyées ; des sentiers traversent Champs
--     et Bosquet ;
--   * une coque (1 <= d < SHELL) de roche-tubercule veinée de roche d'amidon, de
--     patate et de minerais isole la cave ; au-delà, la pierre se contamine
--     progressivement. Les minerais de Minetest Game y deviennent des minerais de
--     roche-tubercule ;
--   * une lumière invisible, posée en grille serrée, rend la cave naturellement lumineuse.

local max, min, floor = math.max, math.min, math.floor
local cave = cavepatate.cave
local st = cavepatate.structures
local FIELDS, GROVE, BLIGHT, HASH = cave.FIELDS, cave.GROVE, cave.BLIGHT, cave.HASH

local c -- content IDs, initialisés au premier usage (tous les mods sont chargés)

local function opt_id(node)
	return core.registered_nodes[node] and core.get_content_id(node) or nil
end

local function init_ids()
	local id = core.get_content_id
	local n = function(s) return id("cavepatate:" .. s) end
	c = {
		air = id("air"),
		water = id("default:water_source"),
		stone = id("default:stone"),
		desert_stone = id("default:desert_stone"),
		tuberstone = n("tuberstone"),
		tuberstone_rubble = n("tuberstone_rubble"),
		tuberstone_brick = n("tuberstone_brick"),
		tuberstone_blighted = n("tuberstone_blighted"),
		starchstone = n("starchstone"),
		blight_ore = n("tuberstone_with_blight"),
		sap_ore = n("tuberstone_with_sap"),
		tuber_soil = n("tuber_soil"),
		peel_turf = n("peel_turf"),
		blighted_peel_turf = n("blighted_peel_turf"),
		tuber_path = n("tuber_path"),
		farmland_wet = n("tuber_farmland_wet"),
		gratings = n("potato_gratings"),
		potato_block = n("potato_block"),
		potato_flesh = n("potato_flesh"),
		blighted = n("blighted_potato_block"),
		compressed = n("blighted_potato_block_compressed"),
		mash = n("blighted_mash"),
		head = n("blighted_head"),
		peel_block = n("peel_block"),
		peel_grey = n("peel_block_grey"),
		peel_green = n("peel_block_green"),
		blighted_peel_block = n("blighted_peel_block"),
		baked_brick = n("baked_brick"),
		charred_brick = n("charred_brick"),
		stale_brick = n("stale_brick"),
		peel_carpet = n("peel_carpet"),
		tuber_spike = n("tuber_spike"),
		tuber_flower = n("tuber_flower"),
		hanging_root = n("hanging_root"),
		strong_root = n("strong_root"),
		mighty_potato = n("mighty_potato"),
		glow_sprout = n("glow_sprout"),
		tuber_stem = n("tuber_stem"),
		tuber_planks = n("tuber_planks"),
		tuber_leaves = n("tuber_leaves"),
		tuber_fruit = n("tuber_fruit"),
		tuber_pedicel = n("tuber_pedicel"),
		pedestal = n("pedestal"),
		cave_light = n("cave_light"),
		loot = n("loot"),
		loot_rich = n("loot_rich"),
		crop = opt_id("farming:potato_4"),
		crop3 = opt_id("farming:potato_3"),
		dry_shrub = opt_id("default:dry_shrub"),
		ladder = opt_id("default:ladder_wood"),
		rail = opt_id("carts:rail"),
	}
	-- minerais de Minetest Game -> minerais en roche-tubercule
	c.ore_map = {}
	for mtg, ours in pairs(cavepatate.ores) do
		local a = opt_id(mtg)
		if a then
			c.ore_map[a] = id(ours)
		end
	end
end

--- Content IDs partagés (structures hors générateur : pousse d'arbre…).
function cavepatate.content_ids()
	if not c then
		init_ids()
	end
	return c
end

-- Buffers réutilisés d'un chunk à l'autre
local data, p2data, warp_buf, vein_buf = {}, {}, {}, {}
-- Emplacements de lumière d'ambiance repérés au creusement, posés après les structures
local spots, nspots = {}, 0
local col_floor, col_biome = {}, {}
local warp_map, vein_map, map_sx, map_sy, map_sz
local get_noise_map = core.get_value_noise_map or core.get_perlin_map

local function noise_maps(sx, sy, sz)
	if map_sx ~= sx or map_sy ~= sy or map_sz ~= sz then
		local size = { x = sx, y = sy, z = sz }
		warp_map = get_noise_map(cave.np_warp, size)
		vein_map = get_noise_map(cave.np_vein, size)
		map_sx, map_sy, map_sz = sx, sy, sz
	end
end

-- Matériaux par sous-biome : { roche, surface, sous-sol (3 nœuds), surface de sentier }
local MATERIALS

local function materials()
	MATERIALS = {
		[FIELDS] = { c.tuberstone, c.peel_turf, c.tuber_soil, c.tuber_path },
		[GROVE] = { c.tuberstone, c.tuber_soil, c.tuber_soil, c.tuber_path },
		[BLIGHT] = { c.tuberstone_blighted, c.blighted_peel_turf, c.tuberstone_blighted, nil },
		[HASH] = { c.starchstone, c.gratings, c.gratings, nil },
	}
end

-- Creusement ------------------------------------------------------------------------

local function carve(ctx, cav)
	local minp, maxp, area = ctx.minp, ctx.maxp, ctx.area
	local x0, x1 = max(minp.x, cav.x - cav.ext.x), min(maxp.x, cav.x + cav.ext.x)
	local y0, y1 = max(minp.y, cav.y - cav.ext.y), min(maxp.y, cav.y + cav.ext.y)
	local z0, z1 = max(minp.z, cav.z - cav.ext.z), min(maxp.z, cav.z + cav.ext.z)
	if x0 > x1 or y0 > y1 or z0 > z1 then
		return false
	end
	local irx2, iry2, irz2 = 1 / (cav.rx * cav.rx), 1 / (cav.ry * cav.ry), 1 / (cav.rz * cav.rz)
	local sx, sy = ctx.sx, ctx.sy
	local ystride = area.ystride
	local LIMIT, SHELL, INFECT, WARP = cave.LIMIT, cave.SHELL, cave.INFECT, cave.WARP
	local wl = cav.water_level
	local c_air, c_water, c_potato = c.air, c.water, c.potato_block
	local c_stone, c_desert, c_starch = c.stone, c.desert_stone, c.starchstone
	local c_blight_ore, c_sap_ore, c_bpeel = c.blight_ore, c.sap_ore, c.blighted_peel_block
	local ore_map = c.ore_map
	local light = cave.LIGHT > 0
	local touched = false

	for z = z0, z1 do
		local dz = z - cav.z
		local dz2 = dz * dz * irz2
		for x = x0, x1 do
			local dx = x - cav.x
			local dxz = dx * dx * irx2 + dz2
			if dxz < LIMIT then
				local ci = (z - minp.z) * sx + (x - minp.x) + 1
				local f = cave.floor_at(cav, x, z)
				local biome = cave.biome_at(x, z)
				col_floor[ci], col_biome[ci] = f, biome
				local mat = MATERIALS[biome]
				local rock, surface, under = mat[1], mat[2], mat[3]
				if mat[4] and f > wl and cave.path_at(x, z) then
					surface = mat[4]
				end
				local gravel_depth = biome == HASH and 2 or 3
				-- lumière invisible : une colonne sur deux en x et en z, un point à 2 nœuds
				-- au-dessus du sol puis tous les 4 nœuds, décalé de 2 d'une colonne à l'autre
				-- (la plupart des cases d'air sont au niveau 12 ou 13)
				local phase = light and x % 2 == 0 and z % 2 == 0
					and ((floor(x / 2) + floor(z / 2)) % 2 == 0 and 2 or 4) or nil
				local ground = max(f, wl)
				local vi = area:index(x, y0, z)
				local ni = (z - minp.z) * sy * sx + (y0 - minp.y) * sx + (x - minp.x) + 1
				for y = y0, y1 do
					local dy = y - cav.y
					local d = dxz + dy * dy * iry2
					if d < LIMIT then
						d = d + WARP * warp_buf[ni]
						if d < 1 then
							touched = true
							if y <= f then
								local t = f - y
								if t == 0 then
									if f <= wl then
										data[vi] = rock
									elseif biome == FIELDS and vein_buf[ni] > 0.62 then
										data[vi] = c_potato
									elseif biome == BLIGHT and vein_buf[ni] > 0.6 then
										data[vi] = c_bpeel
									else
										data[vi] = surface
									end
								elseif t <= gravel_depth then
									data[vi] = under
								else
									data[vi] = ore_map[data[vi]] or rock
								end
							elseif y <= wl then
								data[vi] = c_water
							else
								data[vi] = c_air
								if phase then
									local k = y - ground
									if k == 2 or (k > 0 and (k - phase) % 4 == 0) then
										nspots = nspots + 1
										spots[nspots] = vi
									end
								end
							end
						elseif d < SHELL then
							touched = true
							local v = vein_buf[ni]
							if v > 0.7 then
								data[vi] = c_starch
							elseif v < -0.75 then
								data[vi] = c_potato
							elseif v > 0.445 and v < 0.455 then
								data[vi] = c_blight_ore
							elseif v < -0.445 and v > -0.455 then
								data[vi] = c_sap_ore
							else
								data[vi] = ore_map[data[vi]] or rock
							end
						elseif d < INFECT then
							local cid = data[vi]
							if (d - SHELL) / (INFECT - SHELL) < 0.5 + 0.5 * vein_buf[ni] then
								if cid == c_stone or cid == c_desert then
									data[vi] = rock
									touched = true
								elseif ore_map[cid] then
									data[vi] = ore_map[cid]
									touched = true
								end
							end
						end
					end
					vi = vi + ystride
					ni = ni + sx
				end
			end
		end
	end
	return touched
end

-- Décoration --------------------------------------------------------------------------

local FLOOR_FEATURES = {
	[FIELDS] = { { "giant_potato", 26 }, { "stalagmite", 10 }, { "silo", 3 },
		{ "shrine", 3 }, { "farm_plot", 6 }, { "peel_mound", 7 }, { "ruined_arch", 2 }, { "mineshaft", 2 },
		{ "potato_geode", 3 } },
	[GROVE] = { { "tuber_tree", 70 }, { "giant_potato", 6 }, { "shrine", 2 }, { "mineshaft", 2 },
		{ "peel_mound", 3 } },
	[BLIGHT] = { { "spike_cluster", 28 }, { "stalagmite", 12 }, { "giant_potato", 18 },
		{ "corrupted_patch", 10 }, { "silo", 2 }, { "potato_geode", 4 }, { "mash_pool", 5 } },
	[HASH] = { { "peel_cactus", 24 }, { "hash_well", 4 }, { "stalagmite", 8 },
		{ "ruined_arch", 3 }, { "giant_potato", 4 } },
}
local CEILING_FEATURES = {
	[FIELDS] = { { "stalactite", 28 }, { "hanging_potato", 20 }, { "root_curtain", 15 },
		{ "mighty_potato", 14 } },
	[GROVE] = { { "root_curtain", 40 }, { "hanging_potato", 15 }, { "mighty_potato", 15 }, { "stalactite", 15 } },
	[BLIGHT] = { { "stalactite", 35 }, { "spike_cluster_ceiling", 35 } },
	[HASH] = { { "stalactite", 40 }, { "mighty_potato", 8 }, { "hanging_potato", 6 } },
}

local function pick(pr, list)
	local total = 0
	for _, e in ipairs(list) do
		total = total + e[2]
	end
	local r = pr:next(1, total)
	for _, e in ipairs(list) do
		r = r - e[2]
		if r <= 0 then
			return e[1]
		end
	end
end

local function node_at(ctx, x, y, z)
	return data[ctx.area:index(x, y, z)]
end

-- Premier nœud d'air au-dessus d'un sol sec, dans le chunk, ou nil.
local function floor_y(ctx, cav, x, z, ci)
	local f = col_floor[ci]
	local y = f + 1
	if f <= cav.water_level or f < ctx.minp.y or y > ctx.maxp.y then
		return nil
	end
	if not st.is_air(ctx, node_at(ctx, x, y, z)) then
		return nil
	end
	local below = node_at(ctx, x, f, z)
	if st.is_air(ctx, below) or below == c.water then
		return nil
	end
	return y
end

-- Dernier nœud d'air sous le plafond de la colonne, en partant de `from`, ou nil.
local function ceiling_y(ctx, x, z, from)
	local area, maxy = ctx.area, ctx.maxp.y
	local ystride, c_air, c_light = area.ystride, c.air, c.cave_light
	local vi = area:index(x, from, z)
	local cid = data[vi]
	if cid ~= c_air and cid ~= c_light then
		return nil
	end
	for y = from, maxy - 1 do
		local above = data[vi + ystride]
		if above ~= c_air and above ~= c_light then
			if above == c.water then
				return nil
			end
			return y
		end
		vi = vi + ystride
	end
	return nil
end

-- Vrai si le plafond de la colonne peut se trouver dans ce chunk : le plafond le
-- plus bas possible (déformation maximale) est cav.y + ry * sqrt(1 - 0.44 - dxz).
local function ceiling_in_chunk(cav, x, z, maxp)
	local dxz = ((x - cav.x) / cav.rx) ^ 2 + ((z - cav.z) / cav.rz) ^ 2
	return cav.y + cav.ry * math.sqrt(max(0, 1 - 1.75 * cave.WARP - dxz)) <= maxp.y + 1
end

-- Petites décorations du sol : { seuil sur 1000, content ID, param2 }
local FLOOR_DECOR

local function floor_decor()
	FLOOR_DECOR = {
		[FIELDS] = { { 20, c.glow_sprout }, { 50, c.crop }, { 80, c.tuber_flower }, { 130, c.peel_carpet } },
		[GROVE] = { { 12, c.glow_sprout }, { 35, c.tuber_flower }, { 230, c.peel_carpet } },
		[BLIGHT] = { { 8, c.glow_sprout }, { 50, c.tuber_spike, 1 } },
		[HASH] = { { 6, c.dry_shrub } },
	}
end

local function decorate(ctx, cav)
	local minp, maxp, pr = ctx.minp, ctx.maxp, ctx.pr
	local x0, x1 = max(minp.x, cav.x - cav.rx), min(maxp.x, cav.x + cav.rx)
	local z0, z1 = max(minp.z, cav.z - cav.rz), min(maxp.z, cav.z + cav.rz)
	if x0 > x1 or z0 > z1 then
		return
	end
	local sx = ctx.sx
	local function ci_of(x, z)
		return (z - minp.z) * sx + (x - minp.x) + 1
	end

	-- 1. arène (une par cave, construite par le seul chunk qui la contient)
	local site = cave.arena_site(cav)
	if site and site.x >= minp.x and site.x <= maxp.x and site.z >= minp.z and site.z <= maxp.z
			and site.y - st.ARENA_BELOW >= minp.y and site.y + st.ARENA_ABOVE <= maxp.y then
		st.arena(ctx, site)
	end

	-- 2. grandes structures du sol
	for _ = 1, cave.FEATURES do
		local x, z = pr:next(x0, x1), pr:next(z0, z1)
		local ci = ci_of(x, z)
		if col_floor[ci] then
			local y = floor_y(ctx, cav, x, z, ci)
			if y then
				local biome = col_biome[ci]
				st[pick(pr, FLOOR_FEATURES[biome])](ctx, x, y, z, biome == BLIGHT)
			end
		end
	end

	-- 3. grandes structures du plafond
	for _ = 1, cave.FEATURES do
		local x, z = pr:next(x0, x1), pr:next(z0, z1)
		local ci = ci_of(x, z)
		local f = col_floor[ci]
		if f and ceiling_in_chunk(cav, x, z, maxp) then
			local from = max(minp.y, f + 2)
			if from < maxp.y then
				local yc = ceiling_y(ctx, x, z, from)
				if yc and yc - f > 10 then
					local biome = col_biome[ci]
					st[pick(pr, CEILING_FEATURES[biome])](ctx, x, yc, z, biome == BLIGHT)
				end
			end
		end
	end

	-- 4. petites décorations, colonne par colonne
	local area = ctx.area
	local irx2, irz2 = 1 / (cav.rx * cav.rx), 1 / (cav.rz * cav.rz)
	for z = z0, z1 do
		local dz2 = (z - cav.z) ^ 2 * irz2
		for x = x0, x1 do
			local ci = ci_of(x, z)
			local f = col_floor[ci]
			if f and (x - cav.x) ^ 2 * irx2 + dz2 < 1 then
				local biome = col_biome[ci]
				local y = floor_y(ctx, cav, x, z, ci)
				if y and node_at(ctx, x, f, z) ~= c.tuber_path then
					local r = pr:next(1, 1000)
					for _, e in ipairs(FLOOR_DECOR[biome]) do
						if r <= e[1] then
							if e[2] then
								local vi = area:index(x, y, z)
								data[vi] = e[2]
								p2data[vi] = e[3] or 0
							end
							break
						end
					end
				end
				local from = max(minp.y, f + 2)
				if from < maxp.y and ceiling_in_chunk(cav, x, z, maxp) then
					local yc = ceiling_y(ctx, x, z, from)
					if yc then
						local r = pr:next(1, 1000)
						if (biome == FIELDS or biome == GROVE) and r <= 45 then
							local len = pr:next(1, 5)
							for i = 0, len - 1 do
								local vj = area:index(x, yc - i, z)
								if yc - i < minp.y or not st.is_air(ctx, data[vj]) then
									break
								end
								data[vj] = c.hanging_root
							end
						elseif biome == BLIGHT and r <= 40 then
							local vj = area:index(x, yc, z)
							data[vj] = c.tuber_spike
							p2data[vj] = 0
						end
					end
				end
			end
		end
	end
end

-- Branchement ------------------------------------------------------------------------

core.register_on_generated(function(minp, maxp, blockseed)
	if maxp.y < cave.YMIN or minp.y > cave.YMAX then
		return
	end
	local caves = cave.caves_in(minp, maxp)
	if #caves == 0 then
		return
	end
	if not c then
		init_ids()
	end
	if not MATERIALS then
		materials()
		floor_decor()
	end
	local t0 = core.get_us_time()
	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	vm:get_data(data)
	vm:get_param2_data(p2data)
	local sx, sy, sz = maxp.x - minp.x + 1, maxp.y - minp.y + 1, maxp.z - minp.z + 1
	noise_maps(sx, sy, sz)
	warp_map:get_3d_map_flat(minp, warp_buf)
	vein_map:get_3d_map_flat(minp, vein_buf)

	local ctx = {
		data = data, p2 = p2data, minp = minp, maxp = maxp, sx = sx, sy = sy,
		area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax }),
		pr = PcgRandom(blockseed), c = c, reserved = {},
	}
	local changed = false
	nspots = 0
	for _, cav in ipairs(caves) do
		ctx.cav = cav
		for i = 1, sx * sz do
			col_floor[i] = nil
		end
		if carve(ctx, cav) then
			changed = true
			decorate(ctx, cav)
		end
	end
	if not changed then
		return
	end
	-- lumière là où les structures ont laissé de l'air
	local c_air, c_light = c.air, c.cave_light
	for i = 1, nspots do
		local vi = spots[i]
		if data[vi] == c_air then
			data[vi] = c_light
		end
	end
	vm:set_data(data)
	vm:set_param2_data(p2data)
	vm:calc_lighting()
	vm:write_to_map()
	vm:update_liquids()
	cavepatate.last_gen_us = core.get_us_time() - t0
end)
