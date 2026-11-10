-- Placement et forme des caves patate : fonctions déterministes partagées par le
-- générateur (mapgen.lua), les structures et la commande /patate.
--
-- Le monde est découpé en cellules carrées de CELL nœuds (grille décalée d'une
-- demi-cellule par rapport à celle de Friandises). Chaque cellule contient au plus
-- une cave : un ellipsoïde géant déformé par un bruit 3D, entouré d'une coque de
-- roche-tubercule qui l'isole de la pierre, des grottes et de la lave, puis d'une
-- zone où la pierre se change peu à peu en roche-tubercule.

local floor, ceil, max, min, abs, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.sqrt

local function setting(key, default)
	return tonumber(core.settings:get("cavepatate_" .. key)) or default
end

local cave = {}
cavepatate.cave = cave

cave.CELL = max(600, floor(setting("cavity_cell_size", 5000)))
cave.OFFSET = floor(cave.CELL / 2)
cave.CHANCE = setting("cavity_chance", 0.625)
cave.YMIN = setting("cavity_ymin", -5000)
cave.YMAX = setting("cavity_ymax", -3000)
cave.FEATURES = setting("cavity_features", 20)
cave.LIGHT = max(0, min(core.LIGHT_MAX, setting("cavity_light", 14)))
cave.AMBIENCE = core.settings:get_bool("cavepatate_cavity_ambience", true)
cave.ALIGN = core.settings:get_bool("cavepatate_cavity_align", true)

cave.RXZ_MIN, cave.RXZ_MAX = 120, 200
cave.RY_MIN, cave.RY_MAX = 68, 82
cave.SHELL = 1.25      -- distance normalisée de la fin de la coque
cave.INFECT = 1.6      -- fin de la zone de contamination de la pierre
cave.WARP = 0.25       -- force de la déformation 3D
cave.LIMIT = cave.INFECT + cave.WARP
cave.EXTENT = sqrt(cave.LIMIT)
cave.HILLS = 7         -- amplitude des collines de chair (nœuds)
cave.FLOOR_RATIO = 0.45 -- sol de base à cy - ry * FLOOR_RATIO
cave.LAKE_DEPTH = 3    -- les cuvettes sous floor_base - LAKE_DEPTH sont noyées
cave.ALIGN_ABOVE = 14  -- sol de base aligné à 14 nœuds au-dessus du bas d'un chunk

-- Sous-biomes
cave.FIELDS, cave.GROVE, cave.BLIGHT, cave.HASH = 1, 2, 3, 4

cave.np_warp = { offset = 0, scale = 1, spread = { x = 40, y = 28, z = 40 },
	seed = 70411, octaves = 3, persistence = 0.5, lacunarity = 2 }
cave.np_vein = { offset = 0, scale = 1, spread = { x = 18, y = 12, z = 18 },
	seed = 18733, octaves = 2, persistence = 0.5, lacunarity = 2 }
local np_hills = { offset = 0, scale = 1, spread = { x = 36, y = 36, z = 36 },
	seed = 61203, octaves = 3, persistence = 0.55, lacunarity = 2 }
local np_blight = { offset = 0, scale = 1, spread = { x = 90, y = 90, z = 90 },
	seed = 30557, octaves = 2, persistence = 0.5, lacunarity = 2 }
local np_grove = { offset = 0, scale = 1, spread = { x = 70, y = 70, z = 70 },
	seed = 99173, octaves = 2, persistence = 0.5, lacunarity = 2 }
local np_hash = { offset = 0, scale = 1, spread = { x = 80, y = 80, z = 80 },
	seed = 52817, octaves = 2, persistence = 0.5, lacunarity = 2 }
local np_path = { offset = 0, scale = 1, spread = { x = 60, y = 60, z = 60 },
	seed = 23651, octaves = 1, persistence = 0.5, lacunarity = 2 }

-- Bruits ponctuels 2D, créés à la première utilisation (la graine du monde n'est
-- connue qu'après le chargement des mods). Renommé en 5.12 : on garde l'ancien nom.
local get_noise = core.get_value_noise or core.get_perlin
local n_hills, n_blight, n_grove, n_hash, n_path
local p2 = { x = 0, y = 0 }

local function noises()
	n_hills = get_noise(np_hills)
	n_blight = get_noise(np_blight)
	n_grove = get_noise(np_grove)
	n_hash = get_noise(np_hash)
	n_path = get_noise(np_path)
end

--- Hauteur du sol (dernier nœud solide) de la cave `cav` en (x, z).
function cave.floor_at(cav, x, z)
	if not n_hills then noises() end
	p2.x, p2.y = x, z
	return cav.floor_base + floor(n_hills:get_2d(p2) * cave.HILLS + 0.5)
end

--- Sous-biome en (x, z) : cave.FIELDS, cave.GROVE, cave.BLIGHT ou cave.HASH.
function cave.biome_at(x, z)
	if not n_hills then noises() end
	p2.x, p2.y = x, z
	if n_blight:get_2d(p2) < -0.45 then
		return cave.BLIGHT
	elseif n_hash:get_2d(p2) > 0.5 then
		return cave.HASH
	elseif n_grove:get_2d(p2) > 0.2 then
		return cave.GROVE
	end
	return cave.FIELDS
end

--- Vrai si un sentier passe en (x, z) (Champs et Bosquet).
function cave.path_at(x, z)
	if not n_hills then noises() end
	p2.x, p2.y = x, z
	return math.abs(n_path:get_2d(p2)) < 0.035
end

-- Géométrie des chunks (chunksize peut être un vecteur depuis 5.15)
local chunk, chunk_offset

function cave.chunk_geometry()
	if not chunk then
		local raw = core.get_mapgen_setting("chunksize") or "5"
		local nums = {}
		for n in raw:gmatch("%-?%d+") do
			nums[#nums + 1] = tonumber(n)
		end
		local size = nums[2] or nums[1] or 5
		chunk, chunk_offset = 16 * size, -16 * floor(size / 2)
	end
	return chunk, chunk_offset
end

-- Décale le centre en Y pour que le sol de base soit ALIGN_ABOVE nœuds au-dessus
-- du bas d'un chunk : les grandes structures tiennent alors dans un seul chunk.
local function align_on_chunks(y, ry, ylo, yhi)
	local size, offset = cave.chunk_geometry()
	local up = (offset + cave.ALIGN_ABOVE - floor(y - ry * cave.FLOOR_RATIO)) % size
	local down = up - size
	for _, shift in ipairs(up <= -down and { up, down } or { down, up }) do
		if y + shift >= ylo and y + shift <= yhi then
			return y + shift
		end
	end
	return y
end

-- Évite de chevaucher une caverne à bonbons du mod Friandises.
local function overlaps_friandises(cav)
	local f = rawget(_G, "friandises")
	if not (f and f.find_nearest_cavity) then
		return false
	end
	local other = f.find_nearest_cavity({ x = cav.x, y = cav.y, z = cav.z }, 1)
	if not (other and other.ext) then
		return false
	end
	local m = 24
	return abs(other.x - cav.x) < other.ext.x + cav.ext.x + m
		and abs(other.y - cav.y) < other.ext.y + cav.ext.y + m
		and abs(other.z - cav.z) < other.ext.z + cav.ext.z + m
end

local cache = {}
local world_seed

--- Cave de la cellule (cx, cz), ou nil.
function cave.get(cx, cz)
	local key = cx .. "," .. cz
	local cav = cache[key]
	if cav ~= nil then
		return cav or nil
	end
	world_seed = world_seed or (tonumber(core.get_mapgen_setting("seed")) or 0) % 2147483647
	local pr = PcgRandom(world_seed + cx * 49157 + cz * 2750159 + 7919)
	cav = false
	if pr:next(0, 999) < cave.CHANCE * 1000 then
		local rx, rz = pr:next(cave.RXZ_MIN, cave.RXZ_MAX), pr:next(cave.RXZ_MIN, cave.RXZ_MAX)
		local ry = pr:next(cave.RY_MIN, cave.RY_MAX)
		local ext = { x = ceil(rx * cave.EXTENT), y = ceil(ry * cave.EXTENT), z = ceil(rz * cave.EXTENT) }
		local margin = max(ext.x, ext.z) + 2
		local ylo, yhi = cave.YMIN + ext.y, cave.YMAX - ext.y
		if ylo <= yhi and cave.CELL > 2 * margin then
			local x = cave.OFFSET + cx * cave.CELL + pr:next(margin, cave.CELL - margin)
			local z = cave.OFFSET + cz * cave.CELL + pr:next(margin, cave.CELL - margin)
			local y = pr:next(ylo, yhi)
			if cave.ALIGN then
				y = align_on_chunks(y, ry, ylo, yhi)
			end
			cav = {
				x = x, y = y, z = z, rx = rx, ry = ry, rz = rz, ext = ext,
				floor_base = floor(y - ry * cave.FLOOR_RATIO),
			}
			cav.water_level = cav.floor_base - cave.LAKE_DEPTH
			if overlaps_friandises(cav) then
				cav = false
			end
		end
	end
	cache[key] = cav
	return cav or nil
end

function cave.cell_of(x, z)
	return floor((x - cave.OFFSET) / cave.CELL), floor((z - cave.OFFSET) / cave.CELL)
end

--- Caves dont la boîte englobante touche la zone [minp, maxp].
function cave.caves_in(minp, maxp)
	local list = {}
	local reach = ceil(cave.RXZ_MAX * cave.EXTENT)
	local cx0, cz0 = cave.cell_of(minp.x - reach, minp.z - reach)
	local cx1, cz1 = cave.cell_of(maxp.x + reach, maxp.z + reach)
	for cx = cx0, cx1 do
		for cz = cz0, cz1 do
			local cav = cave.get(cx, cz)
			if cav and maxp.x >= cav.x - cav.ext.x and minp.x <= cav.x + cav.ext.x
					and maxp.y >= cav.y - cav.ext.y and minp.y <= cav.y + cav.ext.y
					and maxp.z >= cav.z - cav.ext.z and minp.z <= cav.z + cav.ext.z then
				list[#list + 1] = cav
			end
		end
	end
	return list
end

--- Cave la plus proche de `pos`, en cherchant `radius` cellules autour. Les caves
--- dont le centre est hors des limites de la carte (mapgen_limit) sont ignorées.
function cave.find_nearest(pos, radius)
	local limit = tonumber(core.get_mapgen_setting("mapgen_limit")) or 31007
	local pcx, pcz = cave.cell_of(pos.x, pos.z)
	local best, best_d
	for cx = pcx - radius, pcx + radius do
		for cz = pcz - radius, pcz + radius do
			local cav = cave.get(cx, cz)
			if cav and math.abs(cav.x) <= limit and math.abs(cav.z) <= limit then
				local d = vector.distance(pos, cav)
				if not best_d or d < best_d then
					best, best_d = cav, d
				end
			end
		end
	end
	return best, best_d
end

--- Distance normalisée (sans déformation) de `pos` au centre de `cav` (< 1 : dedans).
function cave.norm_dist(cav, pos)
	local dx, dy, dz = (pos.x - cav.x) / cav.rx, (pos.y - cav.y) / cav.ry, (pos.z - cav.z) / cav.rz
	return dx * dx + dy * dy + dz * dz
end

-- Site de l'arène (une par cave) : le centre de chunk le plus plat et au sec,
-- proche du milieu de la cave. Calculé une fois, uniquement avec les bruits du
-- sol, donc identique quel que soit le chunk qui le demande.
function cave.arena_site(cav)
	if cav.arena ~= nil then
		return cav.arena or nil
	end
	local size, offset = cave.chunk_geometry()
	local half = floor(size / 2)
	local best, best_score
	local kx0 = ceil((cav.x - cav.rx * 0.5 - offset - half) / size)
	local kx1 = floor((cav.x + cav.rx * 0.5 - offset - half) / size)
	local kz0 = ceil((cav.z - cav.rz * 0.5 - offset - half) / size)
	local kz1 = floor((cav.z + cav.rz * 0.5 - offset - half) / size)
	for kx = kx0, kx1 do
		for kz = kz0, kz1 do
			local x, z = offset + kx * size + half, offset + kz * size + half
			local lo, hi = math.huge, -math.huge
			for i = -15, 15, 5 do
				for j = -15, 15, 5 do
					local f = cave.floor_at(cav, x + i, z + j)
					lo, hi = min(lo, f), max(hi, f)
				end
			end
			-- l'arène nivelle elle-même le terrain (fondations, déblaiement) : on
			-- refuse seulement un sol trop accidenté
			if hi - lo <= 10 then
				local d = cave.norm_dist(cav, { x = x, y = cav.floor_base, z = z })
				local score = (hi - lo) + d * 4
				if not best_score or score < best_score then
					best, best_score = { x = x, z = z, y = max(hi, cav.water_level) + 1 }, score
				end
			end
		end
	end
	cav.arena = best or false
	return best
end
