-- Blacksmithing 1-300 (Alliance), as data: Profession.lua makes the guide from it (GUIDELINES.md).
-- The route (ranges, recipes, counts, choices) follows wow-professions.com's WoW Forever Blacksmithing guide:
-- https://www.wow-professions.com/forever/blacksmithing-leveling-guide (used with credit; will be removed on request).
-- The site's 225-300 part is untested (it goes by the game's data). The recipes' spells, the skill each is learned at
-- and the plans that teach them come from WhatsTraining's Forever recipe list; their reagents from Zygor's Forever
-- recipe data; trainer and vendor ids and positions from QuestieDB's Forever data; the Imperial Plate quests from
-- Zygor's Forever guide. See README.md.
--
-- Where this differs from the site: its "Mithril Plate Pants" (185-215, 12 Mithril Bar each) is Mithril Scale Pants;
-- Imperial Plate Leggings are learned at 300 in the game's data, so 270-300 is Imperial Plate Boots all the way; and
-- the trainer visits are worked out from when each recipe can be learned (Profession.lua).
local _, pack = ...
local P = pack.Place

local SW, IF, STV, TAN = 1453, 1455, 1434, 1446

-- the supply vendors (hammer, flux), beside the trainers
local SUPPLY = { P(SW, 63.26, 37.74, "Kaita Deepforge", 5512), P(IF, 51.74, 42.78, "Thurgrum Deepforge", 4259) }
-- the Imperial Plate plans: Derotain's quests in Gadgetzan, each paid in Thorium Bars
local DEROTAIN = { P(TAN, 51.38, 28.67, "Derotain Mudsipper", 14567) }
local BARGAIN = { id = 7652, title = "A Blue Light Bargain" }

pack.Guide({
	title = "Blacksmithing (1-300)",
	id = "obvi-blacksmithing",
	only = "Alliance",
	skill = "Blacksmithing",
	credit = "Route after wow-professions.com's WoW Forever Blacksmithing guide, used with credit.",
	intro = "Every recipe needs an anvil: the trainers have one beside them.",

	-- the trainers, by the highest rank they train
	trainers = {
		[75] = { P(SW, 64.12, 37.02, "Dane Lindgren", 957), P(IF, 52.26, 41.94, "Groum Stonebeard", 10277) },
		[150] = { P(SW, 63.66, 37.01, "Therum Deepforge", 5511), P(IF, 52.36, 42.55, "Rotgath Stonebeard", 10276) },
		[225] = { P(IF, 52.55, 41.46, "Bengus Deepforge", 4258) },
		[300] = { P(STV, 28.99, 75.56, "Brikk Keencraft", 2836) },
	},
	ranks = {
		{ cap = 150, skill = 50, level = 10 },
		{ cap = 225, skill = 125, level = 20 },
		{ cap = 300, skill = 200, level = 35 },
	},
	tools = { { item = 5956, at = SUPPLY } },
	buy = { [2880] = SUPPLY, [3466] = SUPPLY,
		[2605] = { P(IF, 39.62, 34.49, "Bombus Finespindle", 5128) } },

	items = {
		[2835] = "Rough Stone", [2836] = "Coarse Stone", [2838] = "Heavy Stone", [12365] = "Dense Stone",
		[2840] = "Copper Bar", [2842] = "Silver Bar", [2841] = "Bronze Bar", [3575] = "Iron Bar", [3859] = "Steel Bar",
		[3860] = "Mithril Bar", [12359] = "Thorium Bar", [2319] = "Medium Leather", [4304] = "Thick Leather",
		[8170] = "Rugged Leather", [7910] = "Star Ruby", [7909] = "Aquamarine", [2880] = "Weak Flux",
		[3466] = "Strong Flux", [2605] = "Green Dye", [5956] = "Blacksmith Hammer",
		[12688] = "Plans: Imperial Plate Belt", [12690] = "Plans: Imperial Plate Bracers",
		[12700] = "Plans: Imperial Plate Boots",
	},

	recipes = {
		["Rough Sharpening Stone"] = { spell = 2660, item = 2862, learn = 1, known = true, reagents = { [2835] = 1 } },
		["Rough Grinding Stone"] = { spell = 3320, item = 3470, learn = 25, reagents = { [2835] = 2 } },
		["Coarse Grinding Stone"] = { spell = 3326, item = 3478, learn = 50, reagents = { [2836] = 2 } },
		["Runed Copper Gauntlets"] = { spell = 3323, item = 3472, learn = 35, reagents = { [3470] = 2, [2840] = 8 } },
		["Runed Copper Belt"] = { spell = 2666, item = 2857, learn = 45, reagents = { [2840] = 10 } },
		["Patterned Bronze Bracers"] = { spell = 2672, item = 2868, learn = 95, reagents = { [3478] = 2, [2841] = 5 } },
		["Heavy Grinding Stone"] = { spell = 3337, item = 3486, learn = 100, reagents = { [2838] = 3 } },
		["Bronze Shortsword"] = { spell = 2742, item = 2850, learn = 95,
			reagents = { [2880] = 4, [2319] = 2, [2841] = 5 } },
		["Bronze Warhammer"] = { spell = 9985, item = 7956, learn = 100,
			reagents = { [3466] = 1, [2319] = 1, [2841] = 8 } },
		["Green Iron Bracers"] = { spell = 3501, item = 3835, learn = 140, reagents = { [3575] = 6, [2605] = 1 } },
		["Golden Scale Bracers"] = { spell = 7223, item = 6040, learn = 160, reagents = { [3486] = 2, [3859] = 5 } },
		["Mithril Scale Pants"] = { spell = 9931, item = 7920, learn = 185, reagents = { [3860] = 12 } },
		["Heavy Mithril Breastplate"] = { spell = 9959, item = 7930, learn = 205, reagents = { [3860] = 16 } },
		["Dense Sharpening Stone"] = { spell = 16641, item = 12404, learn = 225, reagents = { [12365] = 1 } },
		["Heavy Mithril Boots"] = { spell = 9968, item = 7933, learn = 210, reagents = { [3860] = 14, [4304] = 4 } },
		["Imperial Plate Belt"] = { spell = 16647, item = 12424, learn = 240, teach = 12688,
			quest = { id = 7653, title = "Imperial Plate Belt", at = DEROTAIN, level = 50, pre = BARGAIN,
				items = { [12359] = 20 } },
			reagents = { [8170] = 6, [7909] = 1, [12359] = 22 } },
		["Imperial Plate Bracers"] = { spell = 16649, item = 12425, learn = 245, teach = 12690,
			quest = { id = 7655, title = "Imperial Plate Bracer", at = DEROTAIN, level = 50, pre = BARGAIN,
				items = { [12359] = 20 } },
			reagents = { [7910] = 1, [12359] = 20 } },
		["Imperial Plate Boots"] = { spell = 16657, item = 12426, learn = 270, teach = 12700,
			quest = { id = 7654, title = "Imperial Plate Boots", at = DEROTAIN, level = 50, pre = BARGAIN,
				items = { [12359] = 40 } },
			reagents = { [7909] = 1, [7910] = 1, [12359] = 34 } },
	},

	-- from, to, what to make (how many: one per point, unless said)
	route = {
		{ 1, 25, { "Rough Sharpening Stone", 30 } },
		{ 25, 50, { "Rough Grinding Stone", 30 } },
		{ 50, 67, { "Coarse Grinding Stone", 36 } },
		{ 67, 75, { "Runed Copper Gauntlets", 8 } },
		{ 75, 80, "Runed Copper Belt", alt = "Or 5 Silver Rod, if Silver Bars are cheap." },
		{ 80, 95, { "Runed Copper Belt", 18 } },
		{ 95, 100, "Patterned Bronze Bracers" },
		{ 100, 112, { "Heavy Grinding Stone", 20 } },
		{ 112, 125, "Patterned Bronze Bracers" },
		{ 125, 140, { "Bronze Shortsword", 24 } },
		{ 140, 150, "Bronze Warhammer" },
		{ 150, 165, { "Bronze Warhammer", 19 } },
		{ 165, 175, { "Green Iron Bracers", 15 } },
		{ 175, 185, "Golden Scale Bracers" },
		{ 185, 215, { "Mithril Scale Pants", 36 },
			alt = "Or, if Mithril is dear: 15 Steel Breastplate to 200, then 17 Steel Plate Helm to 215." },
		{ 215, 225, "Heavy Mithril Breastplate", note = "Or 10 Mithril Spurs, if you find their plans." },
		{ 225, 230, "Dense Sharpening Stone" },
		{ 230, 240, { "Heavy Mithril Boots", 16 } },
		{ 240, 245, "Imperial Plate Belt" },
		{ 245, 270, { "Imperial Plate Bracers", 27 } },
		{ 270, 300, "Imperial Plate Boots" },
	},
})
