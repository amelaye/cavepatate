-- Formes dérivées : avec More Blocks, toutes les formes Stairs+ (et la scie
-- circulaire) ; sinon escaliers et dalles de Minetest Game. Murets : mod walls.

local S = cavepatate.S
local util = cavepatate.util
local tex = util.tex
local name = util.name

local stone_sounds = default.node_sound_stone_defaults()
local wood_sounds = default.node_sound_wood_defaults()

-- { sous-nom, description, escalier, dalle, escalier intérieur, escalier extérieur, groupes, sons }
local SHAPES = {
	{ "tuberstone", S("Tuberstone"), S("Tuberstone Stair"), S("Tuberstone Slab"),
		S("Inner Tuberstone Stair"), S("Outer Tuberstone Stair"), { cracky = 3 }, stone_sounds },
	{ "tuberstone_brick", S("Tuberstone Bricks"), S("Tuberstone Brick Stair"), S("Tuberstone Brick Slab"),
		S("Inner Tuberstone Brick Stair"), S("Outer Tuberstone Brick Stair"), { cracky = 2 }, stone_sounds },
	{ "starchstone", S("Starchstone"), S("Starchstone Stair"), S("Starchstone Slab"),
		S("Inner Starchstone Stair"), S("Outer Starchstone Stair"), { cracky = 3 }, stone_sounds },
	{ "baked_brick", S("Baked Potato Bricks"), S("Baked Potato Brick Stair"), S("Baked Potato Brick Slab"),
		S("Inner Baked Potato Brick Stair"), S("Outer Baked Potato Brick Stair"), { cracky = 2 }, stone_sounds },
	{ "charred_brick", S("Charred Potato Bricks"), S("Charred Potato Brick Stair"), S("Charred Potato Brick Slab"),
		S("Inner Charred Potato Brick Stair"), S("Outer Charred Potato Brick Stair"), { cracky = 2 }, stone_sounds },
	{ "stale_brick", S("Stale Potato Bricks"), S("Stale Potato Brick Stair"), S("Stale Potato Brick Slab"),
		S("Inner Stale Potato Brick Stair"), S("Outer Stale Potato Brick Stair"), { cracky = 2 }, stone_sounds },
	{ "tuber_planks", S("Tuber Planks"), S("Tuber Plank Stair"), S("Tuber Plank Slab"),
		S("Inner Tuber Plank Stair"), S("Outer Tuber Plank Stair"),
		{ choppy = 2, oddly_breakable_by_hand = 2 }, wood_sounds },
}

local stairsplus = rawget(_G, "stairsplus")
local has_moreblocks = core.get_modpath("moreblocks") and stairsplus and stairsplus.register_all

for _, v in ipairs(SHAPES) do
	if has_moreblocks then
		stairsplus:register_all("cavepatate", v[1], name(v[1]), {
			description = v[2],
			tiles = { tex(v[1]) },
			groups = v[7],
			sounds = v[8],
		})
	elseif rawget(_G, "stairs") and stairs.register_stair_and_slab then
		stairs.register_stair_and_slab("cavepatate_" .. v[1], name(v[1]), v[7], { tex(v[1]) },
			v[3], v[4], v[8], true, v[5], v[6])
	end
end

if rawget(_G, "walls") and walls.register then
	for _, w in ipairs({
		{ "tuberstone", S("Tuberstone Wall") },
		{ "tuberstone_rubble", S("Tuberstone Rubble Wall") },
		{ "tuberstone_brick", S("Tuberstone Brick Wall") },
		{ "starchstone", S("Starchstone Wall") },
		{ "baked_brick", S("Baked Potato Brick Wall") },
		{ "charred_brick", S("Charred Potato Brick Wall") },
		{ "stale_brick", S("Stale Potato Brick Wall") },
	}) do
		walls.register(name(w[1] .. "_wall"), w[2], { tex(w[1]) }, name(w[1]), stone_sounds)
	end
end
