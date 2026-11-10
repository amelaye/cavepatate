-- /cavepatate : trouver la cave patate la plus proche (et s'y rendre).

local S = cavepatate.S
local cave = cavepatate.cave

local function safe_spot(cav)
	-- un point au sec, hors pilier, près du centre
	for i = 0, 12 do
		local x, z = cav.x + i * 6, cav.z + (i % 2) * 6
		local f = cave.floor_at(cav, x, z)
		if f > cav.water_level and not cave.pillar_at(x, z) then
			return { x = x, y = f + 2, z = z }
		end
	end
	return { x = cav.x, y = cav.water_level + 2, z = cav.z }
end

core.register_chatcommand("cavepatate", {
	params = "[goto]",
	description = S("Show the nearest potato cave (\"goto\": teleport to it)"),
	privs = { teleport = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("You must be in game.")
		end
		local pos = player:get_pos()
		local cav, dist = cave.find_nearest(pos, 3)
		if not cav then
			return false, S("No potato cave nearby.")
		end
		local spot = safe_spot(cav)
		if param == "goto" then
			player:set_pos(spot)
			return true, S("Teleported to the potato cave at @1.", core.pos_to_string(spot))
		end
		if cave.norm_dist(cav, pos) < 1 then
			return true, S("You are inside the potato cave centered at @1.", core.pos_to_string(cav))
		end
		return true, S("Nearest potato cave: @1 (@2 nodes away).", core.pos_to_string(spot), math.floor(dist))
	end,
})
