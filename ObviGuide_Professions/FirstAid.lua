-- First Aid 1-300 (Alliance), as data: Profession.lua makes the guide from it (GUIDELINES.md).
-- The route (ranges, recipes, counts, choices) follows wow-professions.com's WoW Forever First Aid guide:
-- https://www.wow-professions.com/forever/first-aid-leveling-guide (used with credit; will be removed on request).
-- The site's Artisan part (225-300) was not tested on the Forever beta. The recipes' spells, the skill each is learned
-- at and the manuals that teach them come from WhatsTraining's Forever recipe list (Forever's First Aid makes the
-- healing potions); the bandages' reagents from Zygor's Forever recipe data, the potions' from the site; NPC ids and
-- positions from QuestieDB's and Zygor's Forever data, the Triage patients' from Wowhead's Forever database. See
-- README.md.
--
-- Where this differs from the site: the trainer visits are worked out from when each recipe can be learned
-- (Profession.lua), and the manuals sold with the Expert book are bought in the same visit.
local _, pack = ...
local P = pack.Place

local SW, IF, ELWYNN, DUNMOROGH, ARATHI, DUSTWALLOW = 1453, 1455, 1429, 1426, 1417, 1445

-- Deneb Walker in Arathi Highlands: the Expert book and two manuals
local DENEB = { P(ARATHI, 26.97, 58.83, "Deneb Walker", 2805) }
-- Doctor Gustaf VanHowzen in Theramore: Artisan (his Triage quest), and two bandages after it
local DOCTOR = { P(DUSTWALLOW, 67.76, 48.97, "Doctor Gustaf VanHowzen", 12939) }

pack.Guide({
	title = "First Aid (1-300)",
	id = "obvi-first-aid",
	only = "Alliance",
	skill = "First Aid",
	credit = "Route after wow-professions.com's WoW Forever First Aid guide, used with credit.",
	intro = "First Aid takes no profession slot in Forever, and it makes the healing potions.",

	-- the trainers, by the highest rank they train (all four teach Silk Bandage too)
	trainers = {
		[150] = { P(SW, 53.00, 44.68, "Shaina Fuller", 2327), P(IF, 55.09, 58.26, "Nissa Firestone", 5150),
			P(ELWYNN, 43.39, 65.54, "Michelle Belle", 2329), P(DUNMOROGH, 47.17, 52.61, "Thamner Pol", 2326) },
	},
	ranks = {
		{ cap = 150, skill = 50 },
		{ cap = 225, skill = 125, book = 16084, sold = DENEB },
		-- his Triage quest: a target key for each kind of patient, most urgent first, and one for the bandage
		{ cap = 300, skill = 225, level = 35, at = DOCTOR,
			quest = { id = 6624, title = "Triage", objective = "Save 15 patients", use = 16991,
				on = { { "Critically Injured Alliance Soldier", 12937 }, { "Badly Injured Alliance Soldier", 12936 },
					{ "Injured Alliance Soldier", 12938 } } } },
	},

	items = {
		[2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth", [4338] = "Mageweave Cloth",
		[14047] = "Runecloth", [8838] = "Sungrass", [13464] = "Golden Sansam", [3713] = "Soothing Spices",
		[8925] = "Crystal Vial", [16084] = "Expert First Aid - Under Wraps", [16112] = "Manual: Heavy Silk Bandage",
		[16113] = "Manual: Mageweave Bandage", [255725] = "Manual: Superior Healing Potion",
		[255729] = "Manual: Major Healing Potion", [16991] = "Triage Bandage",
	},

	recipes = {
		["Linen Bandage"] = { spell = 3275, item = 1251, learn = 1, known = true, reagents = { [2589] = 1 } },
		["Heavy Linen Bandage"] = { spell = 3276, item = 2581, learn = 40, reagents = { [2589] = 2 } },
		["Wool Bandage"] = { spell = 3277, item = 3530, learn = 80, reagents = { [2592] = 1 } },
		["Heavy Wool Bandage"] = { spell = 3278, item = 3531, learn = 115, reagents = { [2592] = 2 } },
		["Silk Bandage"] = { spell = 7928, item = 6450, learn = 150, tier = 150, reagents = { [4306] = 1 } },
		["Heavy Silk Bandage"] = { spell = 7929, item = 6451, learn = 180, teach = 16112, sold = DENEB,
			reagents = { [4306] = 2 } },
		["Mageweave Bandage"] = { spell = 10840, item = 8544, learn = 210, teach = 16113, sold = DENEB,
			reagents = { [4338] = 1 } },
		["Superior Healing Potion"] = { spell = 1244435, item = 3928, learn = 215, teach = 255725,
			source = "The manual drops; no vendor sells it.", reagents = { [8838] = 1, [3713] = 1, [8925] = 1 } },
		["Heavy Mageweave Bandage"] = { spell = 10841, item = 8545, learn = 240, at = DOCTOR, reagents = { [4338] = 2 } },
		["Runecloth Bandage"] = { spell = 18629, item = 14529, learn = 260, at = DOCTOR, reagents = { [14047] = 1 } },
		["Major Healing Potion"] = { spell = 1244436, item = 13446, learn = 275, teach = 255729,
			source = "No vendor sells the manual.", reagents = { [13464] = 1, [3713] = 3, [8925] = 1 } },
	},

	-- from, to, what to make (how many: one per point, unless said)
	route = {
		{ 1, 40, { "Linen Bandage", 50 } },
		{ 40, 75, "Heavy Linen Bandage",
			alt = "Or about 81 Minor Healing Potion (Peacebloom, Mild Spices and an Empty Vial each)." },
		{ 75, 80, { "Heavy Linen Bandage", 12 }, note = "Green now: about every second one gives a point." },
		{ 80, 115, { "Wool Bandage", 50 } },
		{ 115, 150, { "Heavy Wool Bandage", 50 } },
		{ 150, 180, { "Silk Bandage", 42 } },
		{ 180, 210, { "Heavy Silk Bandage", 46 } },
		{ 210, 225, { "Mageweave Bandage", 17 },
			note = "Mageweave drops from level 40+ mobs. Without it: 42 more Heavy Silk Bandages." },
		{ 225, 240, { "Superior Healing Potion", 16 } },
		{ 240, 260, { "Heavy Mageweave Bandage", 30 } },
		{ 260, 275, { "Runecloth Bandage", 20 } },
		{ 275, 300, { "Major Healing Potion", 30 } },
	},
})
