-- Cooking 1-300 (Alliance), as data: Profession.lua makes the guide from it (GUIDELINES.md).
-- The route (ranges, counts, the dishes each range can use) follows wow-professions.com's WoW Forever Cooking guide:
-- https://www.wow-professions.com/forever/cooking-leveling-guide (used with credit; will be removed on request). The
-- site's Artisan part (225-300) was not tested on the Forever beta. The recipes' spells, the skill each is learned at
-- and the recipe items that teach them come from WhatsTraining's Forever recipe list; their reagents from Zygor's
-- Forever recipe data; NPC ids and positions from QuestieDB's and Zygor's Forever data. See README.md.
--
-- Where this differs from the site: each range has one main dish, mostly from raw fish and recipes sold by vendors,
-- with the site's other dishes as a choice; and the trainer visits are worked out by Profession.lua.
local _, pack = ...
local P = pack.Place

local SW, IF, ELWYNN, DUNMOROGH, LOCHMODAN, STV, ASH, TAN = 1453, 1455, 1429, 1426, 1432, 1434, 1440, 1446

local THARYNN = P(ELWYNN, 41.82, 67.16, "Tharynn Bouden", 66)
local CATHERINE = P(SW, 55.09, 69.76, "Catherine Leland", 5494)
local TANSY = P(IF, 48.17, 6.51, "Tansy Puddlefizz", 5162)
local KELSEY = P(STV, 28.23, 74.34, "Kelsey Yance", 2664)
local GIKKIX = P(TAN, 66.64, 22.08, "Gikkix", 8137)
-- the sellers (one table each: what one sells is bought in one visit)
local AT_THARYNN, AT_CATHERINE, AT_KELSEY, AT_GIKKIX = { THARYNN }, { CATHERINE }, { KELSEY }, { GIKKIX }
local SPICES = { P(SW, 78.53, 52.88, "Erika Tate", 5483), P(IF, 59.88, 37.37, "Emrul Riknussun", 5160) }

pack.Guide({
	title = "Cooking (1-300)",
	id = "obvi-cooking",
	only = "Alliance",
	skill = "Cooking",
	credit = "Route after wow-professions.com's WoW Forever Cooking guide, used with credit.",
	intro = "Cook at a fire: a town's, or your Basic Campfire Kit (Simple Wood, and Flint and Tinder).",

	trainers = {
		[150] = { P(SW, 78.17, 53.10, "Stephen Ryback", 5482), P(IF, 60.08, 36.43, "Daryl Riknussun", 5159) },
	},
	ranks = {
		{ cap = 150, skill = 50 },
		{ cap = 225, skill = 125, book = 16072, sold = { P(ASH, 49.48, 67.09, "Shandrina", 3955) } },
		{ cap = 300, skill = 225, level = 35, at = { P(TAN, 52.63, 28.11, "Dirge Quikcleave", 8125) },
			items = { [12207] = 12, [7974] = 10, [8932] = 20 },
			note = "Clamlette Surprise: Daryl Riknussun in Ironforge sends you." },
	},
	-- the raw fish and spices, from vendors
	buy = {
		[6291] = { THARYNN, P(DUNMOROGH, 31.53, 44.65, "Gretta Ganter", 8508), CATHERINE },
		[6289] = { CATHERINE, TANSY, P(LOCHMODAN, 40.27, 39.28, "Khara Deepwater", 1684) },
		[6308] = { CATHERINE },
		[8365] = { KELSEY, TANSY },
		[4603] = { GIKKIX },
		[2692] = SPICES,
	},

	items = {
		[6291] = "Raw Brilliant Smallfish", [6289] = "Raw Longjaw Mud Snapper", [6308] = "Raw Bristle Whisker Catfish",
		[8365] = "Raw Mithril Head Trout", [4603] = "Raw Spotted Yellowtail", [13760] = "Raw Sunscale Salmon",
		[3685] = "Raptor Egg", [2692] = "Hot Spices", [12207] = "Giant Egg", [7974] = "Zesty Clam Meat",
		[8932] = "Alterac Swiss", [16072] = "Expert Cookbook", [6325] = "Recipe: Brilliant Smallfish",
		[6328] = "Recipe: Longjaw Mud Snapper", [6330] = "Recipe: Bristle Whisker Catfish",
		[3682] = "Recipe: Curiously Tasty Omelet", [17062] = "Recipe: Mithril Head Trout",
		[13939] = "Recipe: Spotted Yellowtail", [13946] = "Recipe: Poached Sunscale Salmon",
	},

	recipes = {
		["Brilliant Smallfish"] = { spell = 7751, item = 6290, learn = 1, teach = 6325, sold = AT_THARYNN,
			reagents = { [6291] = 1 } },
		["Longjaw Mud Snapper"] = { spell = 7753, item = 4592, learn = 50, teach = 6328, sold = AT_THARYNN,
			reagents = { [6289] = 1 } },
		["Bristle Whisker Catfish"] = { spell = 7755, item = 4593, learn = 100, teach = 6330, sold = AT_CATHERINE,
			reagents = { [6308] = 1 } },
		["Curiously Tasty Omelet"] = { spell = 3376, item = 3665, learn = 130, teach = 3682,
			sold = { P(SW, 77.47, 52.69, "Kendor Kabonka", 340) }, reagents = { [3685] = 1, [2692] = 1 } },
		["Mithril Headed Trout"] = { spell = 20916, item = 8364, learn = 175, teach = 17062, sold = AT_KELSEY,
			reagents = { [8365] = 1 } },
		["Spotted Yellowtail"] = { spell = 18238, item = 6887, learn = 225, teach = 13939, sold = AT_GIKKIX,
			reagents = { [4603] = 1 } },
		["Poached Sunscale Salmon"] = { spell = 18244, item = 13932, learn = 250, teach = 13946, sold = AT_GIKKIX,
			reagents = { [13760] = 1 } },
	},

	-- from, to, the main dish (how many: one per point, unless said), and the site's others
	route = {
		{ 1, 50, { "Brilliant Smallfish", 55 },
			alt = "Or Slitherskin Mackerel, Charred Wolf Meat, Roasted Boar Meat or Herb Baked Egg." },
		{ 50, 100, { "Longjaw Mud Snapper", 55 },
			alt = "Or Rainbow Fin Albacore, Smoked Bear Meat, Boiled Clams or Coyote Steak." },
		{ 100, 130, { "Bristle Whisker Catfish", 35 }, alt = "Or Crab Cake, Cooked Crab Claw or Dry Pork Ribs." },
		{ 130, 150, { "Bristle Whisker Catfish", 25 }, alt = "Or Curiously Tasty Omelet or Goblin Deviled Clams." },
		{ 150, 175, { "Curiously Tasty Omelet", 25 }, note = "Raptor Eggs drop from raptors." },
		{ 175, 225, { "Mithril Headed Trout", 50 }, alt = "Or Roast Raptor or Soothing Turtle Bisque." },
		{ 225, 275, { "Spotted Yellowtail", 65 },
			alt = "Or Filet of Redgill, Undermine Clam Chowder, Monster Omelet or Tender Wolf Steak." },
		{ 275, 300, { "Poached Sunscale Salmon", 35 }, note = "Raw Sunscale Salmon is caught.", alt = "Or Nightfin Soup." },
	},
})
