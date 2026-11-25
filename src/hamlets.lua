-- Hameaux de la cave patate : une place avec un puits d'huile et des lampadaires, une
-- église, trois ou quatre chaumières en briques de patate, des potagers clos et des
-- chemins. Chaque hameau tient dans un chunk et n'est construit que par lui ; son site
-- vient de cave.hamlet_sites (fonction pure). Toits, meubles et détails : formes de More
-- Blocks ; sans More Blocks, escaliers et dalles de Minetest Game ; sans eux, des blocs
-- pleins. Les plans sont originaux.

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local cave = cavepatate.cave
local st = cavepatate.structures
local get, put, fits, reserve, is_air = st.get, st.put, st.fits, st.reserve, st.is_air

-- Formes ------------------------------------------------------------------------------

-- Noms essayés pour chaque forme, du meilleur au repli : More Blocks, Minetest Game.
local FORMS = {
	slope = { "cavepatate:slope_%s", "stairs:stair_cavepatate_%s" },
	slope_outer = { "cavepatate:slope_%s_outer", "stairs:stair_outer_cavepatate_%s" },
	stair = { "cavepatate:stair_%s", "stairs:stair_cavepatate_%s" },
	slab = { "cavepatate:slab_%s", "stairs:slab_cavepatate_%s" },
}
local shapes = {}

--- Content ID de la forme `form` du matériau `mat` (sous-nom : "baked_brick"...), ou du
--- bloc plein quand aucun mod de formes n'est là.
local function shape(form, mat)
	local key = form .. "|" .. mat
	local cid = shapes[key]
	if not cid then
		for _, pattern in ipairs(FORMS[form]) do
			local node = pattern:format(mat)
			if core.registered_nodes[node] then
				cid = core.get_content_id(node)
				break
			end
		end
		cid = cid or core.get_content_id("cavepatate:" .. mat)
		shapes[key] = cid
	end
	return cid
end

-- Repère d'un bâtiment --------------------------------------------------------------

-- lx court le long de la façade, lz vers le fond, ly au-dessus du sol intérieur (ly = -1 :
-- le plancher). La façade est en lz = 0 et regarde vers -lz ; `face` (0 à 3, comme
-- core.facedir_to_dir) est la direction dans laquelle elle regarde dans le monde.
-- Directions locales des facedir : 0 = +lz, 1 = +lx, 2 = -lz, 3 = -lx.
local FLIP = { [0] = 20, [1] = 23, [2] = 22, [3] = 21 } -- forme retournée (comme Minetest Game)

local Frame = {}
Frame.__index = Frame

--- Repère dont le point local (ax, 0, az) tombe sur (x, y, z).
local function frame(ctx, x, y, z, face, ax, az)
	local F = setmetatable({ ctx = ctx, ox = x, oy = y, oz = z, k = (face + 2) % 4 }, Frame)
	local wx, wz = F:xz(ax or 0, az or 0)
	F.ox, F.oz = 2 * x - wx, 2 * z - wz
	return F
end

function Frame:xz(lx, lz)
	local k = self.k
	if k == 0 then
		return self.ox + lx, self.oz + lz
	elseif k == 1 then
		return self.ox + lz, self.oz - lx
	elseif k == 2 then
		return self.ox - lx, self.oz - lz
	end
	return self.ox - lz, self.oz + lx
end

--- Pose `cid` en (lx, ly, lz). `p2` : facedir local (0 à 3), ou 20 + d pour une forme
--- retournée dont le côté plein regarde vers la direction locale d.
function Frame:put(lx, ly, lz, cid, p2)
	local x, z = self:xz(lx, lz)
	if p2 and p2 >= 20 then
		p2 = FLIP[(p2 - 20 + self.k) % 4]
	elseif p2 then
		p2 = (p2 + self.k) % 4
	end
	put(self.ctx, x, self.oy + ly, z, cid, p2)
end

--- Pose `cid` avec un param2 brut (fruits, plants).
function Frame:put_raw(lx, ly, lz, cid, p2)
	local x, z = self:xz(lx, lz)
	put(self.ctx, x, self.oy + ly, z, cid, p2)
end

--- Tige couchée le long de lx.
function Frame:beam(lx, ly, lz, cid)
	local x, z = self:xz(lx, lz)
	put(self.ctx, x, self.oy + ly, z, cid, self.k % 2 == 0 and 12 or 4)
end

function Frame:box(lx0, ly0, lz0, lx1, ly1, lz1)
	local xa, za = self:xz(lx0, lz0)
	local xb, zb = self:xz(lx1, lz1)
	return min(xa, xb), self.oy + ly0, min(za, zb), max(xa, xb), self.oy + ly1, max(za, zb)
end

-- facedir local d'une pente d'angle dont le sommet est vers le coin (px, pz) (±1).
local function corner(px, pz)
	if px < 0 then
		return pz > 0 and 0 or 3
	end
	return pz > 0 and 1 or 2
end

-- Fondation et dégagement de la colonne (x, z) : comble d'abord, sous y, l'air et l'huile
-- jusqu'au sol (12 nœuds au plus) avec `fill`, pose `top` en y, puis vide de y + 1 à y + h.
local function settle(ctx, x, y, z, top, h, fill)
	local c = ctx.c
	for yy = y - 1, max(ctx.minp.y, y - 12), -1 do
		local cid = get(ctx, x, yy, z)
		if not cid or not (is_air(ctx, cid) or cid == c.oil) then
			break
		end
		put(ctx, x, yy, z, fill)
	end
	if top then
		put(ctx, x, y, z, top)
	end
	for yy = y + 1, y + h do
		put(ctx, x, yy, z, c.air)
	end
end

function Frame:settle(lx, ly, lz, top, h, fill)
	local x, z = self:xz(lx, lz)
	settle(self.ctx, x, self.oy + ly, z, top, h, fill)
end

-- Porte (deux nœuds) en (lx, 0, lz), face vers -lz ; `right` : battant de droite d'une
-- porte double. Sans le mod doors, une simple ouverture.
local function door(F, lx, lz, right)
	local c = F.ctx.c
	local leaf = right and c.door_b or c.door
	if leaf and c.door_top then
		F:put(lx, 0, lz, leaf, 0)
		F:put(lx, 1, lz, c.door_top, right and 3 or 0) -- comme Minetest Game au-dessus d'un battant _b
	else
		F:put(lx, 0, lz, c.air)
		F:put(lx, 1, lz, c.air)
	end
end

-- Zones sans petites décorations (intérieurs, potagers, place), lues par le générateur.
local function no_decor(ctx, x0, z0, x1, z1)
	ctx.no_decor = ctx.no_decor or {}
	table.insert(ctx.no_decor, { min(x0, x1), min(z0, z1), max(x0, x1), max(z0, z1) })
end

-- Chaumière -----------------------------------------------------------------------------

local WALLS = { "baked_brick", "baked_brick", "stale_brick", "tuber_planks" }
local ROOFS = { "charred_brick", "tuber_planks", "stale_brick" }

--- Chaumière dont le milieu de la façade est en (x, z) et le sol intérieur au niveau y,
--- façade tournée vers `face`. Renvoie la position (x, z) du seuil, ou nil.
function st.cottage(ctx, x, y, z, face, pr)
	local c = ctx.c
	local W = pr:next(0, 1) == 1 and 11 or 9 -- largeur extérieure, le long de la façade
	local D = pr:next(0, 1) == 1 and 9 or 7  -- profondeur extérieure
	local cx, mid = floor((W - 1) / 2), floor((D - 1) / 2)
	local F = frame(ctx, x, y, z, face, cx, 0)
	local top = max(4 + mid, 6)
	local x0, y0, z0, x1, y1, z1 = F:box(-1, -1, -1, W, top, D)
	if not fits(ctx, x0, y0, z0, x1, y1, z1) then
		return nil
	end
	local wall = c[WALLS[pr:next(1, #WALLS)]]
	local roof_mat = ROOFS[pr:next(1, #ROOFS)]
	local slope = shape("slope", roof_mat)

	-- fondation, plancher et dégagement (débord du toit compris)
	for lz = -1, D do
		for lx = -1, W do
			local inner = lx > 0 and lx < W - 1 and lz > 0 and lz < D - 1
			F:settle(lx, -1, lz, inner and c.tuber_planks or c.starchstone, top + 1, c.starchstone)
		end
	end
	-- murs : soubassement de roche d'amidon, poteaux d'angle en tige
	for ly = 0, 3 do
		for lz = 0, D - 1 do
			for lx = 0, W - 1 do
				if lx == 0 or lx == W - 1 or lz == 0 or lz == D - 1 then
					local post = (lx == 0 or lx == W - 1) and (lz == 0 or lz == D - 1)
					F:put(lx, ly, lz, post and c.tuber_stem or (ly == 0 and c.starchstone or wall))
				end
			end
		end
	end
	-- pignons en planches, sous les deux pans
	for ly = 4, 3 + mid do
		for lz = ly - 3, D - 1 - (ly - 3) do
			F:put(0, ly, lz, c.tuber_planks)
			F:put(W - 1, ly, lz, c.tuber_planks)
		end
	end
	-- toit à deux pans (faîte le long de la façade), débord d'un nœud
	for lx = -1, W do
		for i = 0, mid do
			F:put(lx, 3 + i, i - 1, slope, 0)
			F:put(lx, 3 + i, D - i, slope, 2)
		end
		F:put(lx, 3 + mid, mid, c[roof_mat])
		F:put(lx, 4 + mid, mid, shape("slab", roof_mat))
	end
	-- entrait qui porte la lampe, cheminée dans le mur du fond
	for lx = 0, W - 1 do
		F:beam(lx, 4, mid, c.tuber_stem)
	end
	for ly = 0, 6 do
		F:put(W - 3, ly, D - 1, c.charred_brick)
	end
	-- fenêtres et porte
	for ly = 1, 2 do
		F:put(2, ly, 0, c.glass)
		F:put(W - 3, ly, 0, c.glass)
		F:put(cx, ly, D - 1, c.glass)
		F:put(0, ly, mid, c.glass)
		F:put(W - 1, ly, mid, c.glass)
	end
	door(F, cx, 0)
	-- meubles : table et chaises, tapis, friteuse (ou trancheuse) devant l'âtre,
	-- garde-manger, coffre, fruit lumineux pendu à l'entrait
	F:put(2, 0, mid, shape("slab", "tuber_planks"), 20)
	F:put(1, 0, mid, shape("stair", "tuber_planks"), 3)
	F:put(3, 0, mid, shape("stair", "tuber_planks"), 1)
	for lz = mid - 1, mid + 1 do
		for lx = cx, cx + 2 do
			F:put(lx, 0, lz, c.peel_carpet)
		end
	end
	F:put(W - 3, 0, D - 2, pr:next(1, 3) == 1 and c.slicer or c.fryer, 0)
	F:put(W - 2, 0, D - 2, c.potato_block)
	F:put(W - 2, 1, D - 2, c.peel_block)
	F:put(1, 0, D - 2, c.loot, 0)
	F:put_raw(cx, 3, mid, c.tuber_fruit, 1)

	reserve(ctx, x0, y0, z0, x1, y1, z1)
	no_decor(ctx, x0, z0, x1, z1)
	return F:xz(cx, -1)
end

-- Église --------------------------------------------------------------------------------

--- Église dont le milieu de la porte double est en (x, z) (battant gauche) et le sol au
--- niveau y, façade tournée vers `face`. Plan : tour-clocher de 6×6 à l'entrée (lx 3..8,
--- lz 0..5), nef de 10×15 (lx 1..10, lz 5..19) et ses contreforts (lx 0 et 11).
--- Renvoie la position (x, z) du seuil, ou nil.
function st.church(ctx, x, y, z, face, pr)
	local c = ctx.c
	local TH = 14 + pr:next(0, 2) -- corniche du clocher
	local F = frame(ctx, x, y, z, face, 5, 0)
	local x0, y0, z0, x1, y1, z1 = F:box(0, -1, -1, 11, TH + 5, 20)
	if not fits(ctx, x0, y0, z0, x1, y1, z1) then
		return nil
	end
	local brick, dark = c.tuberstone_brick, c.charred_brick
	local slope = shape("slope", "charred_brick")
	local outer = shape("slope_outer", "charred_brick")

	-- fondation et dégagement ; seuil devant la porte
	for lz = -1, 20 do
		for lx = 0, 11 do
			if lz >= 0 or (lx >= 4 and lx <= 7) then
				local tower = lx >= 3 and lx <= 8 and lz <= 5
				F:settle(lx, -1, lz, c.starchstone, tower and TH + 6 or 11, c.starchstone)
			end
		end
	end
	-- nef : murs, contreforts coiffés d'une pente, fenêtres hautes
	for ly = 0, 5 do
		for lz = 5, 19 do
			for lx = 1, 10 do
				if lx == 1 or lx == 10 or lz == 5 or lz == 19 then
					F:put(lx, ly, lz, brick)
				end
			end
		end
	end
	for _, lz in ipairs({ 6, 10, 14, 18 }) do
		for ly = 0, 2 do
			F:put(0, ly, lz, brick)
			F:put(11, ly, lz, brick)
		end
		F:put(0, 3, lz, slope, 1)
		F:put(11, 3, lz, slope, 3)
	end
	for _, lz in ipairs({ 8, 12, 16 }) do
		for _, lx in ipairs({ 1, 10 }) do
			F:put(lx, 1, lz, dark)
			for ly = 2, 4 do
				F:put(lx, ly, lz, c.glass)
			end
			F:put(lx, 5, lz, dark)
		end
	end
	-- toit à deux pans (faîte le long de la nef) et pignons, vitrail du chevet
	for ly = 6, 10 do
		for lx = ly - 4, 11 - (ly - 4) do
			F:put(lx, ly, 5, brick)
			F:put(lx, ly, 19, brick)
		end
	end
	for ly = 7, 8 do
		F:put(5, ly, 19, c.glass)
		F:put(6, ly, 19, c.glass)
	end
	for lz = 5, 20 do
		for i = 0, 5 do
			F:put(i, 5 + i, lz, slope, 1)
			F:put(11 - i, 5 + i, lz, slope, 3)
		end
	end
	-- clocher : murs aux angles calcinés, plancher de la chambre des cloches, corniche
	for ly = 0, TH - 1 do
		for lz = 0, 5 do
			for lx = 3, 8 do
				local edge = lx == 3 or lx == 8 or lz == 0 or lz == 5
				if edge then
					local quoin = (lx == 3 or lx == 8) and (lz == 0 or lz == 5)
					F:put(lx, ly, lz, quoin and dark or brick)
				elseif ly == TH - 4 then
					F:put(lx, ly, lz, c.tuber_planks)
				else
					F:put(lx, ly, lz, c.air)
				end
			end
		end
	end
	for lz = 0, 5 do
		for lx = 3, 8 do
			F:put(lx, TH, lz, dark)
		end
	end
	-- baies de la chambre des cloches, en arc, sur les quatre faces
	for ly = TH - 3, TH - 2 do
		for _, l in ipairs({ 5, 6 }) do
			F:put(l, ly, 0, c.air)
			F:put(l, ly, 5, c.air)
			F:put(3, ly, l - 3, c.air)
			F:put(8, ly, l - 3, c.air)
		end
	end
	local stair = shape("stair", "tuberstone_brick")
	for _, lz in ipairs({ 0, 5 }) do
		F:put(5, TH - 1, lz, stair, 23)
		F:put(6, TH - 1, lz, stair, 21)
	end
	for _, lx in ipairs({ 3, 8 }) do
		F:put(lx, TH - 1, 2, stair, 22)
		F:put(lx, TH - 1, 3, stair, 20)
	end
	-- cloche : une patate vigoureuse pendue à une racine
	F:put(5, TH - 1, 2, c.hanging_root)
	F:put(5, TH - 2, 2, c.mighty_potato)
	-- flèche pyramidale : anneaux de pentes (angles en pente d'angle) et assises pleines
	local function ring(ly, a, b, za, zb)
		for lz = za, zb do
			for lx = a, b do
				local ex = lx == a and -1 or (lx == b and 1 or 0)
				local ez = lz == za and -1 or (lz == zb and 1 or 0)
				if ex ~= 0 and ez ~= 0 then
					F:put(lx, ly, lz, outer, corner(-ex, -ez))
				elseif ex ~= 0 then
					F:put(lx, ly, lz, slope, ex < 0 and 1 or 3)
				elseif ez ~= 0 then
					F:put(lx, ly, lz, slope, ez < 0 and 0 or 2)
				else
					F:put(lx, ly, lz, dark)
				end
			end
		end
	end
	ring(TH + 1, 3, 8, 0, 5)
	for lz = 1, 4 do
		for lx = 4, 7 do
			F:put(lx, TH + 2, lz, dark)
		end
	end
	ring(TH + 3, 4, 7, 1, 4)
	for lz = 2, 3 do
		for lx = 5, 6 do
			F:put(lx, TH + 4, lz, dark)
		end
	end
	ring(TH + 5, 5, 6, 2, 3)
	-- entrée : porte double, passage vers la nef
	door(F, 5, 0, false)
	door(F, 6, 0, true)
	for ly = 0, 2 do
		F:put(5, ly, 5, c.air)
		F:put(6, ly, 5, c.air)
	end
	-- intérieur : allée de tapis, bancs, chœur surélevé, autel, coffre riche, germes
	for lz = 6, 15 do
		F:put(5, 0, lz, c.peel_carpet)
		F:put(6, 0, lz, c.peel_carpet)
	end
	local pew = shape("stair", "tuber_planks")
	for _, lz in ipairs({ 7, 9, 11, 13 }) do
		for _, lx in ipairs({ 2, 3, 4, 7, 8, 9 }) do
			F:put(lx, 0, lz, pew, 2)
		end
	end
	for lx = 2, 9 do
		F:put(lx, 0, 16, stair, 0)
		F:put(lx, 0, 17, c.stale_brick)
		F:put(lx, 0, 18, c.stale_brick)
	end
	for _, lx in ipairs({ 5, 6 }) do
		F:put(lx, 1, 17, c.pedestal)
		F:put(lx, 2, 17, c.glow_sprout)
	end
	F:put(5, 1, 18, c.loot_rich, 0)
	F:put(2, 1, 18, c.glow_sprout)
	F:put(9, 1, 18, c.glow_sprout)

	reserve(ctx, x0, y0, z0, x1, y1, z1)
	no_decor(ctx, x0, z0, x1, z1)
	return F:xz(5, -1)
end

-- Hameau --------------------------------------------------------------------------------

local DIRS = { [0] = { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }

local function reserved_at(ctx, x, y, z)
	for _, r in ipairs(ctx.reserved) do
		if x >= r[1] and x <= r[4] and y >= r[2] and y <= r[5] and z >= r[3] and z <= r[6] then
			return true
		end
	end
	return false
end

-- Potager clos entre (x1, z1) et (x2, z2) au niveau y : terre labourée humide, rigole
-- d'huile, plants de patates, barrière de tubercule et portillon en (gx, gz).
local function garden(ctx, x1, z1, x2, z2, y, gx, gz, pr)
	local c = ctx.c
	x1, x2, z1, z2 = min(x1, x2), max(x1, x2), min(z1, z2), max(z1, z2)
	if not fits(ctx, x1, y - 2, z1, x2, y + 2, z2) then
		return false
	end
	local midz = floor((z1 + z2) / 2)
	local post = c.fence or c.tuber_pedicel
	for z = z1, z2 do
		for x = x1, x2 do
			local border = x == x1 or x == x2 or z == z1 or z == z2
			local top = border and c.tuber_soil or (z == midz and c.oil or c.farmland_wet)
			settle(ctx, x, y - 1, z, top, 3, c.starchstone)
			if x == gx and z == gz then
				put(ctx, x, y, z, c.gate or c.air, (z == z1 or z == z2) and 0 or 1)
			elseif border then
				put(ctx, x, y, z, post)
			elseif z ~= midz and c.crop and pr:next(1, 4) > 1 then
				put(ctx, x, y, z, (c.crop3 and pr:next(1, 3) == 1) and c.crop3 or c.crop, 3)
			end
		end
	end
	reserve(ctx, x1, y - 2, z1, x2, y + 2, z2)
	no_decor(ctx, x1, z1, x2, z2)
	return true
end

-- Chemin de tubercule du seuil (x, z) jusqu'à la place, en escalier (4-connexe), posé sur
-- le relief ; il contourne ce qui est déjà bâti en sautant ces cases.
local function path(ctx, x, z, cx, y0, cz)
	local c = ctx.c
	for _ = 1, 64 do
		local dx, dz = cx - x, cz - z
		if dx * dx + dz * dz <= 30 then
			return
		end
		for y = y0 + 5, y0 - 6, -1 do
			local cid = get(ctx, x, y, z)
			if cid and not is_air(ctx, cid) then
				if cid ~= c.oil and not reserved_at(ctx, x, y, z) then
					put(ctx, x, y, z, c.tuber_path)
					for h = 1, 2 do
						if not reserved_at(ctx, x, y + h, z) then
							put(ctx, x, y + h, z, c.air)
						end
					end
				end
				break
			end
		end
		-- pas sur l'axe le plus long ; sur l'autre si la case visée est déjà bâtie
		local sx, sz = dx > 0 and 1 or -1, dz > 0 and 1 or -1
		local along_x = abs(dx) >= abs(dz)
		if dz ~= 0 and along_x and reserved_at(ctx, x + sx, y0, z) then
			along_x = false
		elseif dx ~= 0 and not along_x and reserved_at(ctx, x, y0, z + sz) then
			along_x = true
		end
		if along_x then
			x = x + sx
		else
			z = z + sz
		end
	end
end

--- Hameau du site `site` (cave.hamlet_sites), construit d'un seul coup par le chunk qui le
--- contient entier.
function st.hamlet(ctx, site)
	local c = ctx.c
	local pr = PcgRandom(site.seed)
	local x0, y0, z0 = site.x, site.y, site.z
	local H = cave.HAMLET_HALF
	local thresholds = {} -- seuils des portes, reliés ensuite à la place

	-- niveau d'un bâtiment des coins ou d'un potager : sol naturel près de son centre, à
	-- un nœud au plus de la place (les fondations comblent, le dégagement creuse)
	local function level(x, z)
		return max(y0 - 1, min(y0 + 1, cave.floor_at(ctx.cav, x, z) + 1), ctx.cav.water_level + 1)
	end

	-- 1. place nivelée ; au milieu, un bassin d'huile de friture bordé de briques calcinées
	-- autour d'une patate monumentale coiffée d'un germe ; lampadaires
	for dz = -6, 6 do
		for dx = -6, 6 do
			local r2 = dx * dx + dz * dz
			if r2 <= 42 then
				settle(ctx, x0 + dx, y0 - 1, z0 + dz, r2 <= 25 and c.tuber_path or c.starchstone, 8, c.starchstone)
			end
		end
	end
	local rim = shape("slab", "charred_brick")
	for dz = -2, 2 do
		for dx = -2, 2 do
			local r2 = dx * dx + dz * dz
			if r2 <= 5 then
				put(ctx, x0 + dx, y0 - 2, z0 + dz, c.starchstone)
				if r2 >= 4 then
					put(ctx, x0 + dx, y0 - 1, z0 + dz, c.charred_brick)
					put(ctx, x0 + dx, y0, z0 + dz, rim)
				else
					put(ctx, x0 + dx, y0 - 1, z0 + dz, c.oil)
				end
			end
		end
	end
	put(ctx, x0, y0 - 1, z0, c.starchstone)
	put(ctx, x0, y0, z0, c.starchstone)
	for dy, r in ipairs({ 0, 1, 2, 1, 0 }) do -- la patate : 5 de haut, 5 de large au milieu
		for dz = -r, r do
			for dx = -r, r do
				if r < 2 or abs(dx) + abs(dz) < 4 then
					put(ctx, x0 + dx, y0 + dy, z0 + dz, c.potato_block)
				end
			end
		end
	end
	put(ctx, x0, y0 + 6, z0, c.glow_sprout)
	local post = c.fence or c.tuber_pedicel
	for _, d in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
		put(ctx, x0 + d[1], y0, z0 + d[2], post)
		put(ctx, x0 + d[1], y0 + 1, z0 + d[2], post)
		put(ctx, x0 + d[1], y0 + 2, z0 + d[2], c.tuber_fruit, 1)
	end
	reserve(ctx, x0 - 6, y0 - 2, z0 - 6, x0 + 6, y0 + 7, z0 + 6)
	no_decor(ctx, x0 - 6, z0 - 6, x0 + 6, z0 + 6)

	-- 2. l'église sur un côté de la place, une chaumière sur chacun des trois autres
	local church_side = pr:next(0, 3)
	for side = 0, 3 do
		local d = DIRS[side]
		local fx, fz = x0 + d[1] * 8, z0 + d[2] * 8 -- milieu de la façade, à 8 du centre
		local by = y0 -- au niveau de la place : le seuil touche son bord
		local face = (side + 2) % 4
		local tx, tz
		if side == church_side then
			tx, tz = st.church(ctx, fx, by, fz, face, pr)
		else
			tx, tz = st.cottage(ctx, fx, by, fz, face, pr)
		end
		if tx then
			thresholds[#thresholds + 1] = { tx, tz }
		end
	end

	-- 3. aux coins : parfois une quatrième chaumière, puis un ou deux potagers
	local corners = { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
	for i = #corners, 2, -1 do
		local j = pr:next(1, i)
		corners[i], corners[j] = corners[j], corners[i]
	end
	local used = 0
	if pr:next(0, 1) == 1 then
		local s = corners[1]
		local along_x = pr:next(0, 1) == 1
		-- façade tournée vers la place, le long de x ou de z
		local fx, fz = x0 + s[1] * (along_x and 15 or 14), z0 + s[2] * (along_x and 14 or 15)
		local face = along_x and (s[1] > 0 and 3 or 1) or (s[2] > 0 and 2 or 0)
		local tx, tz = st.cottage(ctx, fx, level(x0 + s[1] * 19, z0 + s[2] * 19), fz, face, pr)
		if tx then
			thresholds[#thresholds + 1] = { tx, tz }
			used = 1
		end
	end
	for k = used + 1, used + pr:next(1, 2) do
		local s = corners[k]
		local w, dd = pr:next(6, 8), pr:next(5, 7)
		local ax, az = x0 + s[1] * 11, z0 + s[2] * 11
		local bx, bz = ax + s[1] * (w - 1), az + s[2] * (dd - 1)
		local gx = floor((ax + bx) / 2)
		garden(ctx, ax, az, bx, bz, level(floor((ax + bx) / 2), floor((az + bz) / 2)), gx, az, pr)
	end

	-- 4. chemins des seuils jusqu'à la place
	for _, t in ipairs(thresholds) do
		path(ctx, t[1], t[2], x0, y0, z0)
	end

	reserve(ctx, x0 - H, y0 - cave.HAMLET_BELOW, z0 - H, x0 + H, y0 + cave.HAMLET_ABOVE, z0 + H)
	return true
end
