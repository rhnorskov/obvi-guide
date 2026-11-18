-- Engineering 1-300 (Alliance), as data: Profession.lua makes the guide from it (GUIDELINES.md).
-- The route (ranges, recipes, counts, choices) follows wow-professions.com's WoW Forever Engineering guide:
-- https://www.wow-professions.com/forever/engineering-leveling-guide (used with credit; will be removed on request).
-- The site's later parts are untested on live. The recipes' spells, the skill each is learned at and the schematics
-- that teach them come from WhatsTraining's Forever recipe list; their reagents from Zygor's Forever recipe data;
-- trainer and vendor ids and positions from Zygor's Forever data. See README.md.
--
-- Where this differs from the site: the trainer visits are worked out from when each recipe can be learned
-- (Profession.lua), so Journeyman comes at 50 with the spanner and the bombs, and Expert at 125 in Tinker Town with
-- the scope, the powder and the gizmo. Each trainer and vendor step goes to the nearest of the ones the site names.
local _, pack = ...
local P = pack.Place

local SW, IF, TAN, WINTERSPRING = 1453, 1455, 1446, 1452
local DUNMOROGH, DARKSHORE, DUSKWOOD, ZEPHRAS = 1426, 1439, 1431, 2521

local GEARCUTTER = P(IF, 67.83, 42.51, "Gearcutter Cogspinner", 5175)
-- the hammer and flux: the cities' engineering suppliers, the blacksmithing ones in Kharanos and Auberdine
local FLUX = { P(SW, 62.42, 29.91, "Billibub Cogspinner", 5519), GEARCUTTER,
	P(DUNMOROGH, 45.30, 51.53, "Thrawn Boltar", 1690), P(DARKSHORE, 38.14, 41.11, "Elisa Steelhand", 6300) }
local HAMMER = { FLUX[1], FLUX[2], FLUX[3], FLUX[4], P(ZEPHRAS, 44.88, 44.36, "Aedi Thriceforged", 251913) }

pack.Guide({
	title = "Engineering (1-300)",
	id = "obvi-engineering",
	only = "Alliance",
	skill = "Engineering",
	credit = "Route after wow-professions.com's WoW Forever Engineering guide, used with credit.",

	-- the trainers, by the highest rank they train
	trainers = {
		[75] = { P(SW, 61.89, 30.56, "Sprite Jumpsprocket", 11026), P(IF, 67.65, 44.20, "Jemma Quikswitch", 11028),
			P(DUNMOROGH, 50.17, 50.37, "Bronk Guzzlegear", 1702), P(DARKSHORE, 38.30, 41.11, "Jenna Lemkenilli", 11037),
			P(ZEPHRAS, 53.96, 38.90, "Strange Hermit", 251684) },
		[150] = { P(SW, 62.09, 30.31, "Lilliam Sparkspindle", 5518), P(IF, 67.48, 42.91, "Trixie Quikswitch", 11029),
			P(DUSKWOOD, 77.38, 48.82, "Finbus Geargrind", 1676) },
		[225] = { P(IF, 68.46, 43.56, "Springspindle Fizzlegear", 5174) },
		[300] = { P(TAN, 52.34, 27.72, "Buzzek Bracketswing", 8736) },
	},
	ranks = {
		{ cap = 150, skill = 50, level = 10 },
		{ cap = 225, skill = 125, level = 20 },
		{ cap = 300, skill = 200, level = 35 },
	},
	tools = { { item = 5956, at = HAMMER } },
	buy = { [2880] = FLUX },

	items = {
		[2835] = "Rough Stone", [2836] = "Coarse Stone", [2838] = "Heavy Stone", [7912] = "Solid Stone",
		[12365] = "Dense Stone", [2840] = "Copper Bar", [2842] = "Silver Bar", [2841] = "Bronze Bar",
		[3859] = "Steel Bar", [3860] = "Mithril Bar", [12359] = "Thorium Bar", [2589] = "Linen Cloth",
		[2592] = "Wool Cloth", [4338] = "Mageweave Cloth", [14047] = "Runecloth", [2318] = "Light Leather",
		[2319] = "Medium Leather", [818] = "Tigerseye", [1206] = "Moss Agate", [2880] = "Weak Flux",
		[5956] = "Blacksmith Hammer", [16042] = "Schematic: Thorium Widget", [16047] = "Schematic: Thorium Tube",
	},

	recipes = {
		["Rough Blasting Powder"] = { spell = 3918, item = 4357, learn = 1, known = true, reagents = { [2835] = 1 } },
		["Handful of Copper Bolts"] = { spell = 3922, item = 4359, learn = 30, reagents = { [2840] = 1 } },
		["Arclight Spanner"] = { spell = 7430, item = 6219, learn = 50, tool = true, reagents = { [2840] = 6 } },
		["Rough Copper Bomb"] = { spell = 3923, item = 4360, learn = 30,
			reagents = { [4357] = 2, [2589] = 1, [2840] = 1, [4359] = 1 } },
		["Coarse Blasting Powder"] = { spell = 3929, item = 4364, learn = 75, reagents = { [2836] = 1 } },
		["Coarse Dynamite"] = { spell = 3931, item = 4365, learn = 75, reagents = { [4364] = 3, [2589] = 1 } },
		["Silver Contact"] = { spell = 3973, item = 4404, learn = 90, reagents = { [2842] = 1 } },
		["Flying Tiger Goggles"] = { spell = 3934, item = 4368, learn = 100, reagents = { [818] = 2, [2318] = 6 } },
		["Bronze Tube"] = { spell = 3938, item = 4371, learn = 105, reagents = { [2880] = 1, [2841] = 2 } },
		["Standard Scope"] = { spell = 3978, item = 4406, learn = 110, reagents = { [4371] = 1, [1206] = 1 } },
		["Heavy Blasting Powder"] = { spell = 3945, item = 4377, learn = 125, reagents = { [2838] = 1 } },
		["Whirring Bronze Gizmo"] = { spell = 3942, item = 4375, learn = 125, reagents = { [2592] = 1, [2841] = 2 } },
		["Bronze Framework"] = { spell = 3953, item = 4382, learn = 145,
			reagents = { [2319] = 1, [2592] = 1, [2841] = 2 } },
		["Explosive Sheep"] = { spell = 3955, item = 4384, learn = 150,
			reagents = { [4382] = 1, [4377] = 2, [2592] = 2, [4375] = 1 } },
		["Solid Blasting Powder"] = { spell = 12585, item = 10505, learn = 175, reagents = { [7912] = 2 } },
		["Gyromatic Micro-Adjustor"] = { spell = 12590, item = 10498, learn = 175, tool = true,
			reagents = { [3859] = 4 } },
		["Mithril Tube"] = { spell = 12589, item = 10559, learn = 195, reagents = { [3860] = 3 } },
		["Unstable Trigger"] = { spell = 12591, item = 10560, learn = 200,
			reagents = { [3860] = 1, [10505] = 1, [4338] = 1 } },
		["Mithril Casing"] = { spell = 12599, item = 10561, learn = 215, reagents = { [3860] = 3 } },
		["Hi-Explosive Bomb"] = { spell = 12619, item = 10562, learn = 235,
			reagents = { [10561] = 2, [10560] = 1, [10505] = 2 } },
		["Dense Blasting Powder"] = { spell = 19788, item = 15992, learn = 250, reagents = { [12365] = 2 } },
		["Thorium Widget"] = { spell = 19791, item = 15994, learn = 260, teach = 16042, sold = { GEARCUTTER },
			reagents = { [14047] = 1, [12359] = 3 } },
		["Thorium Tube"] = { spell = 19795, item = 16000, learn = 275, teach = 16047,
			sold = { P(WINTERSPRING, 60.81, 38.60, "Xizzer Fizzbolt", 11185) }, reagents = { [12359] = 6 } },
	},

	-- from, to, what to make (how many: one per point, unless said)
	route = {
		{ 1, 30, { "Rough Blasting Powder", 60 } },
		{ 30, 50, { "Handful of Copper Bolts", 30 }, anvil = true },
		{ 50, 51, "Arclight Spanner", anvil = true },
		{ 51, 75, { "Rough Copper Bomb", 30 } },
		{ 75, 90, { "Coarse Blasting Powder", 60 } },
		{ 90, 100, { "Coarse Dynamite", 20 } },
		{ 100, 105, "Silver Contact", alt = "Or 5 Flying Tiger Goggles, if Silver Bars are dear." },
		{ 105, 125, { "Bronze Tube", 25 }, note = "Short of 125? Go on to the scopes." },
		{ 125, 135, { "Standard Scope", 10 }, note = "No Moss Agate? Make Heavy Blasting Powder instead." },
		{ 135, 150, { "Heavy Blasting Powder", 30 }, { "Whirring Bronze Gizmo", 15 } },
		{ 150, 160, { "Bronze Framework", 15 } },
		{ 160, 175, { "Explosive Sheep", 15 }, note = "Keep 5 for Goblin Engineering." },
		{ 175, 194, { "Solid Blasting Powder", 60 } },
		{ 194, 195, "Gyromatic Micro-Adjustor", note = "Not at 195? Make anything that still gives points." },
		{ 195, 200, { "Mithril Tube", 6 },
			note = "Keep them for Gnomish Engineering. At 200 you can choose Gnomish or Goblin Engineering." },
		{ 200, 215, { "Unstable Trigger", 20 } },
		{ 215, 238, { "Mithril Casing", 40 } },
		{ 238, 250, { "Hi-Explosive Bomb", 20 } },
		{ 250, 260, { "Dense Blasting Powder", 30 } },
		{ 260, 285, { "Thorium Widget", 35 } },
		{ 285, 300, { "Thorium Tube", 20 } },
	},
})
