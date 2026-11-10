-- Objets (non posables) de la cave patate.

local S = cavepatate.S
local util = cavepatate.util
local name, tex = util.name, util.tex

--- on_use d'un aliment qui empoisonne une fois sur `chance`.
function cavepatate.eat_risky(hp, bad_hp, chance)
	return function(itemstack, user, pointed_thing)
		if user and math.random(chance) == 1 then
			return core.do_item_eat(bad_hp, nil, itemstack, user, pointed_thing)
		end
		return core.do_item_eat(hp, nil, itemstack, user, pointed_thing)
	end
end
local eat_risky = cavepatate.eat_risky

local function eatable(item, hp)
	if rawget(_G, "farming") and farming.add_eatable then
		farming.add_eatable(item, hp)
	end
end

core.register_craftitem(name("blighted_potato"), {
	description = S("Blighted Potato"),
	inventory_image = tex("blighted_potato"),
	groups = { food_blighted_potato = 1 },
	on_use = eat_risky(2, -3, 2),
})

core.register_craftitem(name("blighted_slice"), {
	description = S("Blighted Potato Slice"),
	inventory_image = tex("blighted_slice"),
	on_use = eat_risky(1, -2, 2),
})

core.register_craftitem(name("potato_peel"), {
	description = S("Potato Peel"),
	inventory_image = tex("potato_peel"),
	groups = { flammable = 2 },
})

core.register_craftitem(name("potato_sticks"), {
	description = S("Raw Potato Sticks"),
	inventory_image = tex("potato_sticks"),
	on_use = core.item_eat(1),
})

core.register_craftitem(name("fries"), {
	description = S("Fries"),
	inventory_image = tex("fries"),
	on_use = core.item_eat(6),
})
eatable(name("fries"), 6)

core.register_craftitem(name("hash_brown"), {
	description = S("Hash Brown"),
	inventory_image = tex("hash_brown"),
	on_use = core.item_eat(5),
})
eatable(name("hash_brown"), 5)

core.register_craftitem(name("potato_oil"), {
	description = S("Potato Oil"),
	inventory_image = tex("potato_oil"),
	groups = { vessel = 1 },
})

core.register_craftitem(name("toxic_oil"), {
	description = S("Toxic Potato Oil"),
	inventory_image = tex("toxic_oil"),
	groups = { vessel = 1 },
})

core.register_craftitem(name("toxic_sap"), {
	description = S("Toxic Sap"),
	inventory_image = tex("toxic_sap"),
})
