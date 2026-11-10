-- Ambiance des caves patate : dans une cave, le lointain se fond dans une légère brume
-- dorée (au lieu du gris sombre « indoors » de Luanti) et les couleurs sont à peine plus
-- saturées. Le ciel du joueur (fond, brouillard) et sa saturation sont mémorisés à
-- l'entrée et rendus à la sortie.

local cave = cavepatate.cave

if not cave.AMBIENCE then
	return
end

-- jaune pâle, peu dense : la brume ne commence qu'à 75 % de la distance de vue. Le fond
-- (au-delà de la distance de vue) prend la même couleur, sinon la brume se fondrait dans du gris.
local HAZE = "#e9d89a"
local SKY = { type = "plain", base_color = HAZE, clouds = false, fog = { fog_color = HAZE, fog_start = 0.75 } }
local SATURATION = 1.1
local CHECK_EVERY = 1 -- secondes

local saved = {} -- nom du joueur -> { sky = ..., saturation = ... }

local function in_cave(pos)
	if pos.y < cave.YMIN or pos.y > cave.YMAX then
		return false
	end
	local cav = cave.get(cave.cell_of(pos.x, pos.z))
	return cav ~= nil and cave.norm_dist(cav, pos) < 1.05
end

local function enter(player)
	local light = player:get_lighting() or {}
	saved[player:get_player_name()] = {
		sky = player:get_sky(true),
		saturation = light.saturation or 1,
	}
	player:set_sky(SKY)
	player:set_lighting({ saturation = SATURATION })
end

local function leave(player)
	local name = player:get_player_name()
	local s = saved[name]
	saved[name] = nil
	if s then
		player:set_sky(s.sky or {})
		player:set_lighting({ saturation = s.saturation })
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < CHECK_EVERY then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local inside = in_cave(player:get_pos())
		local was = saved[player:get_player_name()] ~= nil
		if inside and not was then
			enter(player)
		elseif was and not inside then
			leave(player)
		end
	end
end)

core.register_on_leaveplayer(function(player)
	leave(player)
end)
