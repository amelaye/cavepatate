-- Constructeurs de structures de la cave patate, appelés par le générateur.
--
-- Chaque constructeur reçoit un contexte `ctx` (données VoxelManip du chunk en
-- cours, content IDs, PcgRandom du chunk) et la position du premier nœud d'air
-- au-dessus du sol (ou sous le plafond). Il n'écrit JAMAIS hors de minp..maxp :
-- si la structure ne tient pas entière dans le chunk, ou chevauche une zone
-- réservée, il renonce et renvoie false.

local floor, ceil, max, min, abs, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.sqrt
local cave = cavepatate.cave

local st = {}
cavepatate.structures = st

-- Outils ------------------------------------------------------------------------

local function inside(ctx, x, y, z)
	local a, b = ctx.minp, ctx.maxp
	return x >= a.x and x <= b.x and y >= a.y and y <= b.y and z >= a.z and z <= b.z
end

local function get(ctx, x, y, z)
	if inside(ctx, x, y, z) then
		return ctx.data[ctx.area:index(x, y, z)]
	end
end

local function put(ctx, x, y, z, cid, param2)
	if inside(ctx, x, y, z) then
		local vi = ctx.area:index(x, y, z)
		ctx.data[vi] = cid
		ctx.p2[vi] = param2 or 0
	end
end

function st.is_air(ctx, cid)
	return cid == ctx.c.air or cid == ctx.c.cave_light
end
local is_air = st.is_air

local function put_air(ctx, x, y, z, cid, param2)
	if is_air(ctx, get(ctx, x, y, z)) then
		put(ctx, x, y, z, cid, param2)
		return true
	end
	return false
end

local function fits(ctx, x0, y0, z0, x1, y1, z1)
	if not (inside(ctx, x0, y0, z0) and inside(ctx, x1, y1, z1)) then
		return false
	end
	for _, r in ipairs(ctx.reserved) do
		if x1 >= r[1] and x0 <= r[4] and y1 >= r[2] and y0 <= r[5] and z1 >= r[3] and z0 <= r[6] then
			return false
		end
	end
	return true
end

local function reserve(ctx, x0, y0, z0, x1, y1, z1)
	ctx.reserved[#ctx.reserved + 1] = { x0, y0, z0, x1, y1, z1 }
end

-- Écart de hauteur du sol sur une emprise carrée (d'après les bruits du sol).
local function unevenness(ctx, x, z, r)
	local lo, hi = math.huge, -math.huge
	for i = -r, r, r do
		for j = -r, r, r do
			local f = cave.floor_at(ctx.cav, x + i, z + j)
			lo, hi = min(lo, f), max(hi, f)
		end
	end
	return hi - lo
end

-- param2 facedir d'un coffre dont la face avant regarde vers (fx, fz).
local function chest_facedir(fx, fz)
	return core.dir_to_facedir({ x = -fx, y = 0, z = -fz })
end

-- Brin de racines pendantes vers le bas depuis (x, y, z), sur `len` nœuds d'air.
local function root_strand(ctx, x, y, z, len)
	for i = 0, len - 1 do
		if not put_air(ctx, x, y - i, z, ctx.c.hanging_root) then
			return
		end
	end
end

-- Ellipsoïde de patate (peau + chair) centré en (cx, cy, cz).
local function potato_blob(ctx, cx, cy, cz, rx, ry, rz, skin, flesh)
	local rmin = min(rx, ry, rz)
	local core_d = ((rmin - 1.2) / rmin) ^ 2
	for dz = -rz, rz do
		for dy = -ry, ry do
			for dx = -rx, rx do
				local d = (dx / rx) ^ 2 + (dy / ry) ^ 2 + (dz / rz) ^ 2
				if d <= 1 then
					put(ctx, cx + dx, cy + dy, cz + dz, d < core_d and flesh or skin)
				end
			end
		end
	end
end

-- Sommet de l'ellipsoïde au-dessus de la colonne (x, z).
local function blob_top(cx, cy, cz, rx, ry, rz, x, z)
	local k = 1 - ((x - cx) / rx) ^ 2 - ((z - cz) / rz) ^ 2
	if k < 0 then
		return nil
	end
	return cy + floor(ry * sqrt(k))
end

-- Structures du sol ----------------------------------------------------------------

-- Patate géante à moitié enfouie, avec des germes qui sortent de ses yeux.
function st.giant_potato(ctx, x, y, z, blighted)
	local pr, c = ctx.pr, ctx.c
	local rx, ry, rz = pr:next(3, 8), pr:next(3, 6), pr:next(3, 8)
	local cy = y + ry - floor(ry * 0.4) - 1
	if not fits(ctx, x - rx - 1, cy - ry, z - rz - 1, x + rx + 1, cy + ry + 1, z + rz + 1) then
		return false
	end
	local skin = blighted and c.blighted or c.potato_block
	local flesh = blighted and c.tuberstone_blighted or c.potato_flesh
	potato_blob(ctx, x, cy, z, rx, ry, rz, skin, flesh)
	for _ = 1, pr:next(1, 4) do
		local ex, ez = x + pr:next(1 - rx, rx - 1), z + pr:next(1 - rz, rz - 1)
		local top = blob_top(x, cy, z, rx, ry, rz, ex, ez)
		if top then
			put_air(ctx, ex, top + 1, ez, blighted and c.tuber_spike or c.glow_sprout, 1)
		end
	end
	reserve(ctx, x - rx, cy - ry, z - rz, x + rx, cy + ry, z + rz)
	return true
end

-- Arbre-tubercule : tige, couronne de feuillage, racines et patates pendantes.
function st.tuber_tree(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local h, r, rv = pr:next(6, 12), pr:next(3, 5), pr:next(2, 3)
	if not fits(ctx, x - r - 1, y, z - r - 1, x + r + 1, y + h + rv + 1, z + r + 1) then
		return false
	end
	for i = 0, h + rv do
		if not is_air(ctx, get(ctx, x, y + i, z)) then
			return false -- plafond trop bas
		end
	end
	for i = 0, h do
		put(ctx, x, y + i, z, c.tuber_stem)
	end
	local top = y + h
	for dz = -r, r do
		for dy = -rv, rv do
			for dx = -r, r do
				if (dx / r) ^ 2 + (dy / rv) ^ 2 + (dz / r) ^ 2 <= 1 and pr:next(1, 8) > 1 then
					put_air(ctx, x + dx, top + dy, z + dz, c.tuber_leaves)
				end
			end
		end
	end
	for _ = 1, pr:next(2, 6) do
		local fx, fz = x + pr:next(1 - r, r - 1), z + pr:next(1 - r, r - 1)
		local k = 1 - ((fx - x) / r) ^ 2 - ((fz - z) / r) ^ 2
		if k > 0 then
			local below = top - floor(rv * sqrt(k)) - 1
			if pr:next(1, 3) == 1 then
				put_air(ctx, fx, below, fz, c.tuber_fruit)
			else
				root_strand(ctx, fx, below, fz, pr:next(1, 3))
			end
		end
	end
	reserve(ctx, x - r, y, z - r, x + r, top + rv, z + r)
	return true
end

-- Stalagmite (dir = 1) ou stalactite (dir = -1) de roche-tubercule.
local function cone(ctx, x, y, z, dir, blighted)
	local pr, c = ctx.pr, ctx.c
	local r = pr:next(1, 4)
	local h = pr:next(3, 5) * r + pr:next(0, 4)
	local y1 = y + dir * (h - 1)
	if not fits(ctx, x - r, min(y, y1), z - r, x + r, max(y, y1), z + r) then
		return false
	end
	local mat = blighted and c.tuberstone_blighted or c.tuberstone
	for i = 0, h - 1 do
		local rad = r * (1 - i / h) + 0.35
		local ir = ceil(rad)
		for dz = -ir, ir do
			for dx = -ir, ir do
				if dx * dx + dz * dz <= rad * rad then
					put_air(ctx, x + dx, y + dir * i, z + dz, mat)
				end
			end
		end
	end
	return true
end

function st.stalagmite(ctx, x, y, z, blighted)
	return cone(ctx, x, y, z, 1, blighted)
end

function st.stalactite(ctx, x, y, z, blighted)
	return cone(ctx, x, y, z, -1, blighted)
end

-- Hauteur de la surface libre près de y, au sol (dir = 1) ou au plafond (dir = -1).
local function surface_y(ctx, x, y, z, dir)
	for _, k in ipairs({ 0, 1, -1 }) do
		local yy = y + k
		local support = get(ctx, x, yy - dir, z)
		if is_air(ctx, get(ctx, x, yy, z)) and support and not is_air(ctx, support)
				and support ~= ctx.c.water then
			return yy
		end
	end
end

-- Patate suspendue au plafond par des racines (comme une île flottante).
function st.hanging_potato(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local len = pr:next(3, 8)
	local rx, ry, rz = pr:next(2, 4), pr:next(2, 3), pr:next(2, 4)
	local cy = y - len - ry
	if not fits(ctx, x - rx, cy - ry - 3, z - rz, x + rx, y, z + rz) then
		return false
	end
	for i = 0, len + ry + 3 do
		if not is_air(ctx, get(ctx, x, y - i, z)) then
			return false -- sol trop proche
		end
	end
	for _ = 1, pr:next(1, 3) do
		local sx, sz = x + pr:next(-1, 1), z + pr:next(-1, 1)
		root_strand(ctx, sx, y, sz, len + ry)
	end
	potato_blob(ctx, x, cy, z, rx, ry, rz, c.potato_block, c.potato_flesh)
	for _ = 1, pr:next(0, 3) do
		local sx, sz = x + pr:next(1 - rx, rx - 1), z + pr:next(1 - rz, rz - 1)
		local k = 1 - ((sx - x) / rx) ^ 2 - ((sz - z) / rz) ^ 2
		if k > 0 then
			root_strand(ctx, sx, cy - floor(ry * sqrt(k)) - 1, sz, pr:next(1, 3))
		end
	end
	return true
end

-- Rideau de racines pendantes.
function st.root_curtain(ctx, x, y, z)
	local pr = ctx.pr
	local r = pr:next(2, 3)
	if not fits(ctx, x - r, y - 12, z - r, x + r, y, z + r) then
		return false
	end
	for dz = -r, r do
		for dx = -r, r do
			if dx * dx + dz * dz <= r * r and pr:next(1, 3) > 1 then
				-- remonte jusqu'au plafond de cette colonne
				local top = y
				while is_air(ctx, get(ctx, x + dx, top + 1, z + dz)) and top < y + 3 do
					top = top + 1
				end
				if not is_air(ctx, get(ctx, x + dx, top + 1, z + dz)) then
					root_strand(ctx, x + dx, top, z + dz, pr:next(2, 10))
				end
			end
		end
	end
	return true
end

-- Ruines ---------------------------------------------------------------------------

-- Silo effondré : tour ronde en briques, ruinée, avec un coffre.
function st.silo(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local R, H = 4, pr:next(8, 11)
	if not fits(ctx, x - R - 1, y - 3, z - R - 1, x + R + 1, y + H + 1, z + R + 1) then
		return false
	end
	if unevenness(ctx, x, z, R) > 4 then
		return false
	end
	local door = pr:next(0, 3)
	local ddx, ddz = ({ 1, -1, 0, 0 })[door + 1], ({ 0, 0, 1, -1 })[door + 1]
	for dz = -R - 1, R + 1 do
		for dx = -R - 1, R + 1 do
			local d = sqrt(dx * dx + dz * dz)
			if d <= R + 0.5 then
				for yy = y - 3, y - 2 do
					local cid = get(ctx, x + dx, yy, z + dz)
					if is_air(ctx, cid) or cid == c.water then
						put(ctx, x + dx, yy, z + dz, c.starchstone)
					end
				end
				local wall = d > R - 0.5
				put(ctx, x + dx, y - 1, z + dz, wall and c.starchstone or c.tuber_planks)
				local is_door = (ddx ~= 0 and dx * ddx >= R - 1 and abs(dz) <= 1)
					or (ddz ~= 0 and dz * ddz >= R - 1 and abs(dx) <= 1)
				local top = wall and (H - pr:next(0, 6)) or -1
				for h = 0, H + 1 do
					local cid = c.air
					if wall and h <= top and not (is_door and h < 3) and pr:next(1, 12) > 1 then
						local k = pr:next(1, 6)
						cid = k == 1 and c.tuberstone_rubble or (k <= 3 and c.baked_brick or c.starchstone)
					end
					put(ctx, x + dx, y + h, z + dz, cid)
				end
			end
		end
	end
	for _ = 1, pr:next(3, 6) do
		local px, pz = x + pr:next(1 - R, R - 2), z + pr:next(1 - R, R - 2)
		put(ctx, px, y, pz, c.potato_block)
		if pr:next(1, 2) == 1 then
			put(ctx, px, y + 1, pz, c.potato_block)
		end
	end
	-- coffre contre le mur opposé à la porte, face à la porte
	put(ctx, x - ddx * (R - 1), y, z - ddz * (R - 1), c.loot, chest_facedir(ddx, ddz))
	reserve(ctx, x - R - 1, y - 3, z - R - 1, x + R + 1, y + H + 1, z + R + 1)
	return true
end

-- Autel des germes : plate-forme, piédestal, piliers et cercle de germes.
function st.shrine(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	if not fits(ctx, x - 4, y - 2, z - 4, x + 4, y + 5, z + 4) then
		return false
	end
	if unevenness(ctx, x, z, 3) > 3 then
		return false
	end
	for dz = -3, 3 do
		for dx = -3, 3 do
			local cid = get(ctx, x + dx, y - 2, z + dz)
			if is_air(ctx, cid) or cid == c.water then
				put(ctx, x + dx, y - 2, z + dz, c.starchstone)
			end
			put(ctx, x + dx, y - 1, z + dz, c.starchstone)
			for h = 0, 4 do
				put(ctx, x + dx, y + h, z + dz, c.air)
			end
			if max(abs(dx), abs(dz)) == 2 and pr:next(1, 3) > 1 then
				put(ctx, x + dx, y, z + dz, c.glow_sprout)
			end
		end
	end
	for _, p in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		local h = pr:next(1, 3)
		for i = 0, h - 1 do
			put(ctx, x + p[1], y + i, z + p[2], c.baked_brick)
		end
		put(ctx, x + p[1], y + h, z + p[2], c.glow_sprout)
	end
	put(ctx, x, y, z, c.pedestal)
	put(ctx, x, y + 1, z, c.glow_sprout) -- piédestal surmonté d'un germe
	reserve(ctx, x - 4, y - 2, z - 4, x + 4, y + 5, z + 4)
	return true
end

-- Arène enfouie (une par cave) : gradins circulaires, mur d'enceinte percé de
-- quatre entrées, colonnes brisées, cœur flétri et deux coffres.
st.ARENA_R = 15
st.ARENA_BELOW, st.ARENA_ABOVE = 8, 12

function st.arena(ctx, site)
	local pr, c = ctx.pr, ctx.c
	local R = st.ARENA_R
	local x, y, z = site.x, site.y, site.z
	if not fits(ctx, x - R - 1, y - st.ARENA_BELOW, z - R - 1, x + R + 1, y + st.ARENA_ABOVE, z + R + 1) then
		return false
	end
	for dz = -R, R do
		for dx = -R, R do
			local d = sqrt(dx * dx + dz * dz)
			if d <= R + 0.5 then
				local px, pz = x + dx, z + dz
				for yy = y - 2, y - st.ARENA_BELOW, -1 do
					local cid = get(ctx, px, yy, pz)
					if is_air(ctx, cid) or cid == c.water then
						put(ctx, px, yy, pz, c.starchstone)
					else
						break
					end
				end
				for h = 0, st.ARENA_ABOVE - 1 do
					put(ctx, px, y + h, pz, c.air)
				end
				local aisle = abs(dx) <= 1 or abs(dz) <= 1
				if d <= 2.5 then
					put(ctx, px, y - 1, pz, c.compressed)
				elseif d <= 6.5 then
					put(ctx, px, y - 1, pz, c.stale_brick)
				else
					put(ctx, px, y - 1, pz, c.baked_brick)
					if d <= R - 1.5 then
						if not aisle then
							local k = floor((d - 6.5) / 2) + 1
							for h = 0, k - 1 do
								put(ctx, px, y + h, pz, c.baked_brick)
							end
							if pr:next(1, 40) == 1 then
								put(ctx, px, y + k, pz, c.glow_sprout)
							end
						end
					else
						for h = 0, 4 do
							if not (aisle and h < 4) and pr:next(1, 15) > 1 then
								put(ctx, px, y + h, pz, h == 4 and c.charred_brick or (pr:next(1, 3) == 1 and c.stale_brick or c.baked_brick))
							end
						end
					end
				end
			end
		end
	end
	-- colonnes brisées sur l'enceinte (entre les entrées)
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local px, pz = x + floor(R * math.cos(a) + 0.5), z + floor(R * math.sin(a) + 0.5)
		local h = pr:next(1, 6)
		for k = 5, 4 + h do
			put(ctx, px, y + k, pz, c.charred_brick)
		end
		if pr:next(1, 2) == 1 then
			put(ctx, px, y + 5 + h, pz, c.head, pr:next(0, 3))
		end
	end
	-- coffres riches au bord de l'aire centrale, face au centre
	for _, a in ipairs({ math.pi / 4, 5 * math.pi / 4 }) do
		local ox, oz = floor(5 * math.cos(a) + 0.5), floor(5 * math.sin(a) + 0.5)
		local fx = ox > 0 and -1 or 1
		put(ctx, x + ox, y, z + oz, c.loot_rich, chest_facedir(fx, 0))
	end
	-- au centre, un piédestal surmonté d'une tête de patate vénéneuse
	put(ctx, x, y, z, c.pedestal)
	put(ctx, x, y + 1, z, c.head, pr:next(0, 3))
	reserve(ctx, x - R - 1, y - st.ARENA_BELOW, z - R - 1, x + R + 1, y + st.ARENA_ABOVE, z + R + 1)
	return true
end


-- Champs ---------------------------------------------------------------------------

-- Potager abandonné : terre labourée humide, rigole d'eau au milieu, plants de patates.
function st.farm_plot(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local w, d = pr:next(5, 8), pr:next(4, 6)
	if not fits(ctx, x - 1, y - 2, z - 1, x + w, y + 2, z + d) then
		return false
	end
	if unevenness(ctx, x + floor(w / 2), z + floor(d / 2), floor(max(w, d) / 2)) > 2 then
		return false
	end
	local mid = floor(d / 2)
	for dz = -1, d do
		for dx = -1, w do
			local border = dx == -1 or dx == w or dz == -1 or dz == d
			put(ctx, x + dx, y - 2, z + dz, c.tuber_soil)
			if border then
				put(ctx, x + dx, y - 1, z + dz, c.tuber_planks)
			elseif dz == mid then
				put(ctx, x + dx, y - 1, z + dz, c.water)
			else
				put(ctx, x + dx, y - 1, z + dz, c.farmland_wet)
			end
			for h = 0, 2 do
				put(ctx, x + dx, y + h, z + dz, c.air)
			end
			if not border and dz ~= mid and c.crop and pr:next(1, 4) > 1 then
				put(ctx, x + dx, y, z + dz, (c.crop3 and pr:next(1, 3) == 1) and c.crop3 or c.crop, 3)
			end
		end
	end
	reserve(ctx, x - 1, y - 2, z - 1, x + w, y + 2, z + d)
	return true
end

-- Tas de pelures (naturelles ou grises).
function st.peel_mound(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local r = pr:next(2, 4)
	local h = pr:next(2, r + 1)
	if not fits(ctx, x - r, y - 1, z - r, x + r, y + h, z + r) then
		return false
	end
	local cid = pr:next(1, 3) == 1 and c.peel_grey or c.peel_block
	for dz = -r, r do
		for dx = -r, r do
			for dy = 0, h do
				if (dx / r) ^ 2 + (dz / r) ^ 2 + (dy / h) ^ 2 <= 1 then
					put(ctx, x + dx, y - 1 + dy, z + dz, cid)
				end
			end
		end
	end
	return true
end

-- Arche effondrée : vestige d'un portique de roche d'amidon et de briques, avec un
-- piédestal devant (aucun portail : purement décoratif).
function st.ruined_arch(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local along_x = pr:next(0, 1) == 1
	if not fits(ctx, x - 3, y - 1, z - 3, x + 3, y + 6, z + 3) then
		return false
	end
	local mats = { c.starchstone, c.starchstone, c.baked_brick, c.stale_brick }
	local function at(u, v, cid)
		if along_x then
			put(ctx, x + u, y + v, z, cid)
		else
			put(ctx, x, y + v, z + u, cid)
		end
	end
	for u = -2, 2 do
		at(u, -1, c.starchstone)
		for v = 0, 5 do
			local frame = (u == -2 or u == 2 or v == 5)
			if frame and pr:next(1, 10) > (v >= 4 and 4 or 1) then
				at(u, v, mats[pr:next(1, #mats)])
			end
		end
	end
	for _ = 1, pr:next(1, 3) do -- éboulis
		local ox, oz = pr:next(-3, 3), pr:next(-3, 3)
		put_air(ctx, x + ox, y, z + oz, pr:next(1, 2) == 1 and c.starchstone or c.baked_brick)
	end
	if along_x then
		put_air(ctx, x, y, z - 2, c.pedestal)
	else
		put_air(ctx, x - 2, y, z, c.pedestal)
	end
	reserve(ctx, x - 3, y - 1, z - 3, x + 3, y + 6, z + 3)
	return true
end

-- Galerie de tubercule : puits d'accès avec échelle, puis tunnel étayé de pédicelles
-- creusé sous le sol, avec un coffre au bout.
function st.mineshaft(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local depth, len = pr:next(8, 12), pr:next(8, 16)
	local fy = y - depth -- sol du tunnel
	if not fits(ctx, x - len - 1, fy - 1, z - 2, x + len + 1, y, z + 2) then
		return false
	end
	-- le tunnel doit rester sous le sol de la cave (et sous ses lacs)
	for dx = -len, len, 4 do
		if cave.floor_at(ctx.cav, x + dx, z) - 4 < fy + 3 then
			return false
		end
	end
	-- puits : 1×1, échelle accrochée à la paroi z+1
	for yy = fy, y - 1 do
		put(ctx, x, yy, z, c.ladder or c.air, 4)
		put(ctx, x, yy, z + 1, c.starchstone)
	end
	for dx = -len, len do
		for dz = -1, 1 do
			put(ctx, x + dx, fy - 1, z + dz, c.tuber_planks)
			for h = 0, 2 do
				put(ctx, x + dx, fy + h, z + dz, c.air)
			end
		end
		if c.rail and pr:next(1, 6) > 1 then
			put(ctx, x + dx, fy, z, c.rail)
		end
		if dx % 4 == 0 then
			for h = 0, 2 do
				put(ctx, x + dx, fy + h, z - 1, c.tuber_pedicel)
				put(ctx, x + dx, fy + h, z + 1, c.tuber_pedicel)
			end
			for dz = -1, 1 do
				put(ctx, x + dx, fy + 3, z + dz, c.tuber_planks)
			end
		end
	end
	put(ctx, x, fy, z, c.ladder or c.air, 4)
	local e = pr:next(0, 1) == 1 and len or -len
	put(ctx, x + e, fy, z, c.loot, chest_facedir(e > 0 and -1 or 1, 0))
	reserve(ctx, x - len - 1, fy - 1, z - 2, x + len + 1, y, z + 2)
	return true
end

-- Géode de patate vénéneuse, enfouie sous le sol : coque de roche d'amidon, couches
-- de patate vénéneuse, cœur creux hérissé de pointes.
local INWARD = { { 0, -1, 0, 1 }, { 0, 1, 0, 0 }, { -1, 0, 0, 3 }, { 1, 0, 0, 2 }, { 0, 0, -1, 5 }, { 0, 0, 1, 4 } }

function st.potato_geode(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local r = pr:next(4, 6)
	local cy = y - r - 4
	if not fits(ctx, x - r, cy - r, z - r, x + r, cy + r, z + r) then
		return false
	end
	local hollow = {}
	for dz = -r, r do
		for dy = -r, r do
			for dx = -r, r do
				local d = sqrt(dx * dx + dy * dy + dz * dz)
				if d <= r then
					local cid
					if d > r - 1 then
						cid = c.starchstone
					elseif d > r - 2 then
						cid = c.blighted
					elseif d > r - 2.6 then
						cid = pr:next(1, 6) == 1 and c.compressed or c.blighted
					else
						cid = c.air
						hollow[#hollow + 1] = { x + dx, cy + dy, z + dz }
					end
					put(ctx, x + dx, cy + dy, z + dz, cid)
				end
			end
		end
	end
	-- pointes sur les parois intérieures (wallmounted vers la paroi)
	for _, h in ipairs(hollow) do
		for _, dvec in ipairs(INWARD) do
			local wall = get(ctx, h[1] + dvec[1], h[2] + dvec[2], h[3] + dvec[3])
			if wall and not is_air(ctx, wall) and pr:next(1, 3) == 1 then
				put(ctx, h[1], h[2], h[3], c.tuber_spike, dvec[4])
				break
			end
		end
	end
	return true
end

-- Flétrissure ------------------------------------------------------------------------

local function spikes(ctx, x, y, z, dir)
	local pr, c = ctx.pr, ctx.c
	local r = pr:next(1, 3)
	if not fits(ctx, x - r, y - 2, z - r, x + r, y + 2, z + r) then
		return false
	end
	for dz = -r, r do
		for dx = -r, r do
			if dx * dx + dz * dz <= r * r and pr:next(1, 3) > 1 then
				local yy = surface_y(ctx, x + dx, y, z + dz, dir)
				if yy then
					put(ctx, x + dx, yy, z + dz, c.tuber_spike, dir == 1 and 1 or 0)
				end
			end
		end
	end
	return true
end

function st.spike_cluster(ctx, x, y, z)
	return spikes(ctx, x, y, z, 1)
end

function st.spike_cluster_ceiling(ctx, x, y, z)
	return spikes(ctx, x, y, z, -1)
end

-- Plaque de pelures corrompues dans le sol.
function st.corrupted_patch(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local r = pr:next(2, 4)
	if not fits(ctx, x - r, y - 2, z - r, x + r, y + 1, z + r) then
		return false
	end
	for dz = -r, r do
		for dx = -r, r do
			if dx * dx + dz * dz <= r * r + 1 then
				local yy = surface_y(ctx, x + dx, y, z + dz, 1)
				if yy then
					put(ctx, x + dx, yy - 1, z + dz, c.blighted_peel_block)
					if pr:next(1, 6) == 1 then
						put(ctx, x + dx, yy, z + dz, c.blighted_peel_block)
					end
				end
			end
		end
	end
	return true
end

-- Flaque de purée vénéneuse (couches d'épaisseur variable).
function st.mash_pool(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local r = pr:next(2, 4)
	if not fits(ctx, x - r, y - 2, z - r, x + r, y + 2, z + r) then
		return false
	end
	for dz = -r, r do
		for dx = -r, r do
			local d2 = dx * dx + dz * dz
			if d2 <= r * r then
				local yy = surface_y(ctx, x + dx, y, z + dz, 1)
				if yy then
					local level = 8 * math.max(1, math.min(4, r - floor(sqrt(d2)) + pr:next(0, 1)))
					put(ctx, x + dx, yy, z + dz, c.mash, level)
				end
			end
		end
	end
	return true
end

-- Râpures ----------------------------------------------------------------------------

-- « Cactus » de pelures vertes : colonne et un ou deux bras.
function st.peel_cactus(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local h = pr:next(2, 5)
	if not fits(ctx, x - 2, y, z - 2, x + 2, y + h + 2, z + 2) then
		return false
	end
	for i = 0, h - 1 do
		put_air(ctx, x, y + i, z, c.peel_green)
	end
	if h >= 3 then
		for _ = 1, pr:next(1, 2) do
			local ax, az = 0, 0
			if pr:next(0, 1) == 1 then ax = pr:next(0, 1) == 1 and 1 or -1 else az = pr:next(0, 1) == 1 and 1 or -1 end
			local ay = y + pr:next(1, h - 2)
			put_air(ctx, x + ax, ay, z + az, c.peel_green)
			for k = 1, pr:next(1, 2) do
				put_air(ctx, x + ax, ay + k, z + az, c.peel_green)
			end
		end
	end
	return true
end

-- Puits calciné : margelle de briques calcinées, eau, toit sur quatre pédicelles.
function st.hash_well(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	if not fits(ctx, x - 2, y - 4, z - 2, x + 2, y + 4, z + 2) then
		return false
	end
	if unevenness(ctx, x, z, 2) > 2 then
		return false
	end
	for dz = -2, 2 do
		for dx = -2, 2 do
			local rim = math.abs(dx) == 2 or math.abs(dz) == 2
			put(ctx, x + dx, y - 1, z + dz, c.charred_brick)
			put(ctx, x + dx, y - 4, z + dz, c.starchstone)
			for yy = y - 3, y - 2 do
				put(ctx, x + dx, yy, z + dz, rim and c.starchstone or c.water)
			end
			if not rim then
				put(ctx, x + dx, y - 1, z + dz, c.water)
			end
			for h = 0, 3 do
				put(ctx, x + dx, y + h, z + dz, c.air)
			end
			put(ctx, x + dx, y, z + dz, rim and c.charred_brick or c.air)
			if pr:next(1, 6) > 1 or not rim then
				put(ctx, x + dx, y + 4, z + dz, c.charred_brick)
			end
		end
	end
	for _, p in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		for h = 1, 3 do
			put(ctx, x + p[1], y + h, z + p[2], c.tuber_pedicel)
		end
	end
	reserve(ctx, x - 2, y - 4, z - 2, x + 2, y + 4, z + 2)
	return true
end

-- Plafond ----------------------------------------------------------------------------

-- Patate vigoureuse suspendue à des racines faibles, déjà prolongée de racines robustes.
function st.mighty_potato(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local len, strong = pr:next(1, 3), pr:next(1, 4)
	if not fits(ctx, x, y - len - strong, z, x, y, z) then
		return false
	end
	for i = 0, len + strong do
		if not is_air(ctx, get(ctx, x, y - i, z)) then
			return false
		end
	end
	root_strand(ctx, x, y, z, len)
	put(ctx, x, y - len, z, c.mighty_potato)
	for i = 1, strong do
		put(ctx, x, y - len - i, z, c.strong_root)
	end
	return true
end

-- Nuage de fécule flottant (ne remplace que l'air).
function st.cloud(ctx, x, y, z)
	local pr, c = ctx.pr, ctx.c
	local rx, ry, rz = pr:next(3, 7), pr:next(1, 2), pr:next(3, 7)
	if not fits(ctx, x - rx, y - ry, z - rz, x + rx, y + ry, z + rz) then
		return false
	end
	for dz = -rz, rz do
		for dy = -ry, ry do
			for dx = -rx, rx do
				local d = (dx / rx) ^ 2 + (dy / ry) ^ 2 + (dz / rz) ^ 2
				if d <= 1 and (d < 0.6 or pr:next(1, 3) > 1) then
					put_air(ctx, x + dx, y + dy, z + dz, c.starch_cloud)
				end
			end
		end
	end
	return true
end
