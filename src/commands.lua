-- /patate : coordonnées de la cave patate la plus proche (comme /candycave de Friandises).

local S = cavepatate.S

core.register_chatcommand("patate", {
	description = S("Show the nearest potato cave"),
	privs = { teleport = true },
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("You must be in game to use this command.")
		end
		local cav = cavepatate.cave.find_nearest(player:get_pos(), 6)
		if not cav then
			return false, S("No potato cave found nearby.")
		end
		return true, S("Nearest potato cave: @1", core.pos_to_string(vector.new(cav.x, cav.y, cav.z)))
	end,
})
