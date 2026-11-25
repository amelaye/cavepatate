-- Placement et forme des caves patate : fonctions déterministes partagées par le
-- générateur (mapgen.lua), les structures et la commande /cavepatate.
--
-- Le monde est découpé en cellules carrées de CELL nœuds, alignées sur 0. Par défaut
-- (10000, chance 1), la carte de -10000 à 10000 en X et en Z contient exactement 4 caves,
-- une par quart. Chaque cellule contient au plus une cave ; une cave qui chevaucherait
-- une caverne de Friandises est déplacée dans sa cellule. Une cave est un ellipsoïde
-- géant déformé par un bruit 3D, entouré d'une coque de roche-tubercule qui l'isole de
-- la pierre, des grottes et de la lave, puis d'une zone où la pierre se change peu à peu
-- en roche-tubercule.

local floor, ceil, max, min, abs, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.sqrt

local function setting(key, default)
	return tonumber(core.settings:get("cavepatate_" .. key)) or default
end

local cave = {}
cavepatate.cave = cave

cave.CELL = max(600, floor(setting("cavity_cell_size", 10000)))
cave.OFFSET = 0
cave.CHANCE = setting("cavity_chance", 1)
cave.YMIN = setting("cavity_ymin", -5000)
cave.YMAX = setting("cavity_ymax", -3000)
cave.FEATURES = setting("cavity_features", 20)
cave.LIGHT = max(0, min(core.LIGHT_MAX, setting("cavity_light", 14)))
cave.AMBIENCE = core.settings:get_bool("cavepatate_cavity_ambience", true)
cave.ALIGN = core.settings:get_bool("cavepatate_cavity_align", true)
cave.HAMLETS = max(1, min(3, floor(setting("cavity_hamlets", 3))))

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
		-- jusqu'à 16 emplacements dans la cellule, le premier qui évite les cavernes de
		-- Friandises est retenu
		for _ = 1, ylo <= yhi and cave.CELL > 2 * margin and 16 or 0 do
			local x = cave.OFFSET + cx * cave.CELL + pr:next(margin, cave.CELL - margin)
			local z = cave.OFFSET + cz * cave.CELL + pr:next(margin, cave.CELL - margin)
			local y = pr:next(ylo, yhi)
			if cave.ALIGN then
				y = align_on_chunks(y, ry, ylo, yhi)
			end
			local c = {
				x = x, y = y, z = z, rx = rx, ry = ry, rz = rz, ext = ext,
				floor_base = floor(y - ry * cave.FLOOR_RATIO),
			}
			c.water_level = c.floor_base - cave.LAKE_DEPTH
			if not overlaps_friandises(c) then
				cav = c
				break
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

-- Hameaux --------------------------------------------------------------------------

cave.HAMLET_HALF = 32   -- demi-côté de l'emprise d'un hameau (64×64, centrée dans un chunk)
cave.HAMLET_BELOW = 6   -- profondeur sous la place (puits, potagers, fondations)
cave.HAMLET_ABOVE = 32  -- hauteur au-dessus de la place (clocher compris)

-- Sites des hameaux : toute cave en a 2 ou 3 (au plus cave.HAMLETS). Un site est le centre
-- d'un chunk, hors de celui de l'arène, dont le hameau entier tient dans le chunk en hauteur
-- (sol aligné sur les chunks) et dont les bâtiments ne touchent pas les parois. Le reste
-- ne fait que classer les sites : terrain plat, Champs ou Bosquet, bâtiments loin des
-- parois, place hors de l'huile (sinon elle est surélevée au-dessus du lac). Les hameaux
-- évitent les chunks voisins l'un de l'autre tant qu'il reste assez de sites. Calculés une
-- fois avec les seuls bruits du sol : chaque chunk obtient la même liste.
-- Un site : { x, y (niveau de la place), z, seed }.
function cave.hamlet_sites(cav)
	if cav.hamlets then
		return cav.hamlets
	end
	local list = {}
	cav.hamlets = list
	local size, offset = cave.chunk_geometry()
	local half, H = floor(size / 2), cave.HAMLET_HALF
	if size < 2 * H + 1 then
		return list -- chunks trop petits (chunksize < 5) : aucun hameau ne tiendrait
	end
	local arena = cave.arena_site(cav)
	local function chunk_of(v)
		return floor((v - offset) / size)
	end
	local candidates = {}
	local kx0 = ceil((cav.x - cav.rx * 0.8 - offset - half) / size)
	local kx1 = floor((cav.x + cav.rx * 0.8 - offset - half) / size)
	local kz0 = ceil((cav.z - cav.rz * 0.8 - offset - half) / size)
	local kz1 = floor((cav.z + cav.rz * 0.8 - offset - half) / size)
	for kx = kx0, kx1 do
		for kz = kz0, kz1 do
			local x, z = offset + kx * size + half, offset + kz * size + half
			if not (arena and chunk_of(arena.x) == kx and chunk_of(arena.z) == kz) then
				-- coins des bâtiments (à ±26) et centre : distance aux parois, sous-biome
				local wall, off_biome = 0, 0
				for _, d in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, 0 } }) do
					local px, pz = x + d[1] * (H - 6), z + d[2] * (H - 6)
					local b = cave.biome_at(px, pz)
					if b ~= cave.FIELDS and b ~= cave.GROVE then
						off_biome = off_biome + (d[1] == 0 and 2 or 1)
					end
					wall = max(wall, ((px - cav.x) / cav.rx) ^ 2 + ((pz - cav.z) / cav.rz) ^ 2)
				end
				local f = cave.floor_at(cav, x, z)
				local y = max(f + 1, cav.water_level + 2)
				local ybot = offset + chunk_of(y) * size
				if wall <= 0.85 and y - cave.HAMLET_BELOW >= ybot and y + cave.HAMLET_ABOVE <= ybot + size - 1 then
					local lo, hi = math.huge, -math.huge
					for i = -H, H, 8 do
						for j = -H, H, 8 do
							local g = cave.floor_at(cav, x + i, z + j)
							lo, hi = min(lo, g), max(hi, g)
						end
					end
					local score = (hi - lo) + 6 * off_biome + (wall > 0.7 and 20 or 0) + (f + 1 < y and 8 or 0)
					candidates[#candidates + 1] = { x = x, y = y, z = z, kx = kx, kz = kz, score = score }
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.score ~= b.score then
			return a.score < b.score
		end
		return a.kx < b.kx or (a.kx == b.kx and a.kz < b.kz)
	end)
	world_seed = world_seed or (tonumber(core.get_mapgen_setting("seed")) or 0) % 2147483647
	local pr = PcgRandom(world_seed + cav.x * 7907 + cav.z * 1009 + 4243)
	local want = min(cave.HAMLETS, pr:next(2, 3))
	-- parmi les meilleurs (deux fois plus de sites que de hameaux voulus), au hasard
	local pool = {}
	for i = 1, min(#candidates, want * 2) do
		pool[i] = candidates[i]
	end
	for i = #pool, 2, -1 do
		local j = pr:next(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = #pool + 1, #candidates do
		pool[i] = candidates[i]
	end
	-- d'abord des chunks qui ne se touchent pas, puis, s'il manque des hameaux, des voisins
	for pass = 1, 2 do
		for _, s in ipairs(pool) do
			if #list < want and not s.seed then
				local near = false
				for _, o in ipairs(list) do
					if abs(o.kx - s.kx) <= 1 and abs(o.kz - s.kz) <= 1 then
						near = true
						break
					end
				end
				if pass == 2 or not near then
					s.seed = pr:next(0, 2147483646)
					list[#list + 1] = s
				end
			end
		end
	end
	return list
end
