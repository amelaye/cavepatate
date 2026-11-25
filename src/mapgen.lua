-- Générateur des caves patate : creusement au VoxelManip après le mapgen normal,
-- puis habillage, structures, petites décorations et lumière d'ambiance.
--
-- Dans une cave (distance normalisée d < 1, déformée par un bruit 3D) :
--   * le sol suit des collines (cave.floor_at) ; quatre sous-biomes : Champs
--     (tourbe de pelures, fleurs, potagers), Bosquet (arbres-tubercules), Flétrissure
--     (tourbe flétrie, pointes, pelures corrompues) et Râpures (râpure de patate qui
--     s'effondre, cactus de pelures, puits calcinés) ;
--   * les cuvettes sous le niveau du lac sont noyées d'huile de friture ; des sentiers traversent Champs
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
local foreign_liquid = {} -- content ID -> true pour les liquides qui ne sont pas du mod

local function opt_id(node)
	return core.registered_nodes[node] and core.get_content_id(node) or nil
end

local function init_ids()
	local id = core.get_content_id
	local n = function(s) return id("cavepatate:" .. s) end
	c = {
		air = id("air"),
		ignore = id("ignore"),
		oil = n("frying_oil_source"),
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
		-- hameaux
		glass = id("default:glass"),
		fryer = n("fryer"),
		slicer = n("potato_slicer"),
		fence = opt_id("cavepatate:tuber_fence"),
		gate = opt_id("cavepatate:tuber_fence_gate_closed"),
		door = opt_id("cavepatate:tuber_door_a"),
		door_b = opt_id("cavepatate:tuber_door_b"),
		door_top = opt_id("doors:hidden"),
	}
	-- minerais de Minetest Game -> minerais en roche-tubercule
	c.ore_map = {}
	for mtg, ours in pairs(cavepatate.ores) do
		local a = opt_id(mtg)
		if a then
			c.ore_map[a] = id(ours)
		end
	end
	-- liquides des autres mods et du jeu (eau, lave…), à retirer du creux des caves
	for node, def in pairs(core.registered_nodes) do
		if (def.liquidtype or "none") ~= "none" and node:sub(1, 11) ~= "cavepatate:" then
			foreign_liquid[id(node)] = true
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
	local c_air, c_oil, c_potato = c.air, c.oil, c.potato_block
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
								data[vi] = c_oil
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
	if st.is_air(ctx, below) or below == c.oil then
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
			if above == c.oil then
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

	-- 1 bis. hameaux (chacun construit par le seul chunk qui le contient en entier)
	local H = cave.HAMLET_HALF
	for _, h in ipairs(cave.hamlet_sites(cav)) do
		if h.x - H >= minp.x and h.x + H <= maxp.x and h.z - H >= minp.z and h.z + H <= maxp.z
				and h.y - cave.HAMLET_BELOW >= minp.y and h.y + cave.HAMLET_ABOVE <= maxp.y then
			st.hamlet(ctx, h)
		end
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

	-- 4. petites décorations, colonne par colonne (sauf dans les maisons, potagers et
	-- places des hameaux)
	local area = ctx.area
	local irx2, irz2 = 1 / (cav.rx * cav.rx), 1 / (cav.rz * cav.rz)
	local no_decor = ctx.no_decor
	local function decor_ok(x, z)
		for _, r in ipairs(no_decor or {}) do
			if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
				return false
			end
		end
		return true
	end
	for z = z0, z1 do
		local dz2 = (z - cav.z) ^ 2 * irz2
		for x = x0, x1 do
			local ci = ci_of(x, z)
			local f = col_floor[ci]
			if f and (x - cav.x) ^ 2 * irx2 + dz2 < 1 then
				local biome = col_biome[ci]
				local y = floor_y(ctx, cav, x, z, ci)
				if y and node_at(ctx, x, f, z) ~= c.tuber_path and (not no_decor or decor_ok(x, z)) then
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
				-- (dans un bâtiment, le « plafond » trouvé serait son toit)
				if from < maxp.y and ceiling_in_chunk(cav, x, z, maxp) and (not no_decor or decor_ok(x, z)) then
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

-- Écritures des autres mods au-delà des bords du chunk --------------------------------
-- D'autres mods décorent les grottes d'un chunk pendant sa génération, et certains
-- écrivent au-delà de ses bords, jusqu'à 16 nœuds dans les chunks voisins : caverealms
-- (sous Y −1500) pose champignons géants, stalactites et vers luisants sans regarder ce
-- qu'ils remplacent. Quand le voisin est une cave déjà générée, ces morceaux y flottent.
-- Même méthode que paleocave : un premier rappel, placé avant ceux de tous les autres
-- mods, garde une copie de la zone (keep_copy) ; le générateur remet ensuite ce qui a
-- changé autour du chunk, dans la coque et le creux des caves (clean_edges). Ce que ces
-- mods posent dans le chunk lui-même est creusé avec le reste : le générateur passe après
-- eux (caverealms et everness en dépendances optionnelles dans mod.conf). Sinon,
-- caverealms prendrait la roche du chunk voisin pas encore creusé pour un sol ou un
-- plafond, et poserait ses décorations sur les faces du chunk, dans le vide.
-- Limite : depuis Luanti 5.9, Everness travaille dans l'environnement mapgen
-- (register_mapgen_script), donc avant keep_copy ; ses écritures au-delà du chunk ne
-- sont pas remises (seuls ses liquides le sont, comme ceux du moteur, plus bas).

local EDGE = 16 -- portée des écritures d'un chunk au-delà de ses bords
local before, before_of = {}, nil

-- Caves dont l'emprise touche le chunk ou ses bords, ou nil.
local function caves_near(minp, maxp)
	if maxp.y + EDGE < cave.YMIN or minp.y - EDGE > cave.YMAX then
		return nil
	end
	local list = cave.caves_in(
		{ x = minp.x - EDGE, y = minp.y - EDGE, z = minp.z - EDGE },
		{ x = maxp.x + EDGE, y = maxp.y + EDGE, z = maxp.z + EDGE })
	return #list > 0 and list or nil
end

local function keep_copy(minp, maxp)
	before_of = nil
	if caves_near(minp, maxp) then
		local vm = core.get_mapgen_object("voxelmanip")
		vm:get_data(before)
		before_of = { x = minp.x, y = minp.y, z = minp.z }
	end
end

-- Le moteur, lui, passe avant keep_copy : ses grandes grottes inondées, générées dans un
-- chunk voisin, débordent d'eau ou de lave dans l'air d'une cave déjà creusée. Tout
-- liquide étranger trouvé autour du chunk, dans le creux de la cave, est donc retiré.
local get_noise = core.get_value_noise or core.get_perlin
local n_warp
local wpos = { x = 0, y = 0, z = 0 }

-- Vrai si la distance déformée de (x, y, z) est sous `limit` (1 : creux, cave.SHELL :
-- coque comprise) ; d0 : distance normalisée sans déformation. Le bruit n'est lu qu'à
-- proximité de la limite.
local function warped_below(x, y, z, d0, limit)
	local margin = 2 * cave.WARP
	if d0 < limit - margin then
		return true
	elseif d0 >= limit + margin then
		return false
	end
	n_warp = n_warp or get_noise(cave.np_warp)
	wpos.x, wpos.y, wpos.z = x, y, z
	return d0 + cave.WARP * n_warp:get_3d(wpos) < limit
end

-- Vrai si (x, y, z) est dans le creux de la cave (air ou lac), au-dessus du sol.
local function in_hollow(cav, x, y, z, d0)
	return d0 < 1 + 2 * cave.WARP and y > cave.floor_at(cav, x, z) and warped_below(x, y, z, d0, 1)
end

-- Autour du chunk (entre minp..maxp et emin..emax), dans l'emprise de `cav` : remet les
-- cellules de la coque et du creux qu'un autre mod a changées depuis keep_copy (si
-- `copy` ; au-delà, dans la pierre contaminée, ses décorations de grottes sont légitimes),
-- puis retire les liquides étrangers du creux. Les cellules des chunks pas encore générés
-- (« ignore » dans la copie) sont laissées : ces chunks creuseront leur cave eux-mêmes.
-- Limites connues : param2 n'est pas remis (caverealms n'en écrit pas), et un liquide
-- posé par un joueur dans le creux, à moins de 16 nœuds d'un chunk pas encore généré,
-- disparaît à la génération de ce chunk.
local function clean_edges(cav, minp, maxp, emin, emax, area, copy)
	local x0, x1 = max(emin.x, cav.x - cav.ext.x), min(emax.x, cav.x + cav.ext.x)
	local y0, y1 = max(emin.y, cav.y - cav.ext.y), min(emax.y, cav.y + cav.ext.y)
	local z0, z1 = max(emin.z, cav.z - cav.ext.z), min(emax.z, cav.z + cav.ext.z)
	local irx2, iry2, irz2 = 1 / (cav.rx * cav.rx), 1 / (cav.ry * cav.ry), 1 / (cav.rz * cav.rz)
	local LIMIT, SHELL, c_ignore, c_air, c_oil, cx = cave.LIMIT, cave.SHELL, c.ignore, c.air, c.oil, cav.x
	local wl = cav.water_level
	local changed = false
	local function row(y, z, dyz, from, to)
		local vi = area:index(from, y, z)
		for x = from, to do
			local cid = data[vi]
			if copy then
				local old = before[vi]
				if cid ~= old and old ~= c_ignore and warped_below(x, y, z, (x - cx) ^ 2 * irx2 + dyz, SHELL) then
					data[vi], cid = old, old
					changed = true
				end
			end
			if foreign_liquid[cid] and in_hollow(cav, x, y, z, (x - cx) ^ 2 * irx2 + dyz) then
				data[vi] = y <= wl and c_oil or c_air
				changed = true
			end
			vi = vi + 1
		end
	end
	for z = z0, z1 do
		local dz2 = (z - cav.z) ^ 2 * irz2
		local in_z = z >= minp.z and z <= maxp.z
		for y = y0, y1 do
			local dyz = (y - cav.y) ^ 2 * iry2 + dz2
			if dyz < LIMIT then
				if in_z and y >= minp.y and y <= maxp.y then
					-- seulement les parties de la rangée hors du chunk
					row(y, z, dyz, x0, min(x1, minp.x - 1))
					row(y, z, dyz, max(x0, maxp.x + 1), x1)
				else
					row(y, z, dyz, x0, x1)
				end
			end
		end
	end
	return changed
end

-- keep_copy en tête des rappels. Avec le profileur, le rappel enregistré est une
-- enveloppe : on déplace donc le dernier élément ajouté, quel qu'il soit.
do
	local callbacks = core.registered_on_generateds
	local n = type(callbacks) == "table" and #callbacks
	core.register_on_generated(keep_copy)
	if n and #callbacks == n + 1 then
		table.insert(callbacks, 1, table.remove(callbacks))
	end
end

-- Branchement ------------------------------------------------------------------------

local function touches(cav, minp, maxp)
	return maxp.x >= cav.x - cav.ext.x and minp.x <= cav.x + cav.ext.x
		and maxp.y >= cav.y - cav.ext.y and minp.y <= cav.y + cav.ext.y
		and maxp.z >= cav.z - cav.ext.z and minp.z <= cav.z + cav.ext.z
end

core.register_on_generated(function(minp, maxp, blockseed)
	local near = caves_near(minp, maxp)
	if not near then
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
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local changed = false

	-- 1. ce que les autres mods et le moteur ont écrit dans les caves voisines
	local copy = before_of and before_of.x == minp.x and before_of.y == minp.y and before_of.z == minp.z
	for _, cav in ipairs(near) do
		if clean_edges(cav, minp, maxp, emin, emax, area, copy) then
			changed = true
		end
	end

	-- 2. les caves du chunk lui-même
	local caves = {}
	for _, cav in ipairs(near) do
		if touches(cav, minp, maxp) then
			caves[#caves + 1] = cav
		end
	end
	local carved = false
	if #caves > 0 then
		vm:get_param2_data(p2data)
		local sx, sy, sz = maxp.x - minp.x + 1, maxp.y - minp.y + 1, maxp.z - minp.z + 1
		noise_maps(sx, sy, sz)
		warp_map:get_3d_map_flat(minp, warp_buf)
		vein_map:get_3d_map_flat(minp, vein_buf)

		local ctx = {
			data = data, p2 = p2data, minp = minp, maxp = maxp, sx = sx, sy = sy,
			area = area, pr = PcgRandom(blockseed), c = c, reserved = {},
		}
		nspots = 0
		for _, cav in ipairs(caves) do
			ctx.cav = cav
			for i = 1, sx * sz do
				col_floor[i] = nil
			end
			if carve(ctx, cav) then
				carved = true
				decorate(ctx, cav)
			end
		end
		if carved then
			-- lumière là où les structures ont laissé de l'air
			local c_air, c_light = c.air, c.cave_light
			for i = 1, nspots do
				local vi = spots[i]
				if data[vi] == c_air then
					data[vi] = c_light
				end
			end
		end
	end
	if not (changed or carved) then
		return
	end
	vm:set_data(data)
	if carved then
		vm:set_param2_data(p2data)
	end
	vm:calc_lighting()
	vm:write_to_map()
	vm:update_liquids()
	cavepatate.last_gen_us = core.get_us_time() - t0
end)
