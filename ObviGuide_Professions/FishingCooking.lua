-- Fishing and Cooking 1-300 together (Alliance). The route, zones, recipes, counts, skill ranges, rank-ups and quests
-- follow wow-professions.com's WoW Forever Fishing and Cooking guide:
-- https://www.wow-professions.com/forever/fishing-and-cooking-leveling-guide (used with credit; will be removed on
-- request). The step text is our own. The site's Artisan Fishing part was not tested on the Forever beta. NPC, item and
-- quest ids and NPC positions come from QuestieDB's Forever data. See README.md.

local SW, ELWYNN, DUNMOROGH, TELDRASSIL, DARNASSUS, ZEPHRAS = 1453, 1429, 1426, 1438, 1457, 2521
local STV, ASH, BARRENS, DUSTWALLOW, TAN, FERALAS = 1434, 1440, 1413, 1445, 1446, 1444
local FISH, COOK = "Fishing", "Cooking"

-- where you start: the site's four Alliance starting zones, by race (anyone else uses Elwynn Forest)
local IN_DM, IN_TEL, IN_ZEP = "Dwarf or Gnome", "NightElf", "Skyborne"
local IN_ELW = "not (Dwarf or Gnome or NightElf or Skyborne)"

ObviGuide.Guide(function(g)
	g.title = "Fishing and Cooking (1-300)"
	g.group = "Professions"
	g.id    = "obvi-fishing-cooking"
	g.only  = "Alliance"

	local pole, bauble = g.Item("Fishing Pole", 6256), g.Item("Shiny Bauble", 6529)
	local crawlers, attractor = g.Item("Nightcrawlers", 6530), g.Item("Aquadynamic Fish Attractor", 6533)
	local smallfish, longjaw = g.Item("Raw Brilliant Smallfish", 6291), g.Item("Raw Longjaw Mud Snapper", 6289)
	local catfish, trout = g.Item("Raw Bristle Whisker Catfish", 6308), g.Item("Raw Mithril Head Trout", 8365)
	local swiss = g.Item("Alterac Swiss", 8932)
	local NAT, CLAMLETTE = 6607, 6610

	local ryback = g.Npc("Stephen Ryback", 5482)
	local pagle = g.Npc("Nat Pagle", 12919)

	--- Fishing to 75 in a starting zone, then Journeyman Fishing from the same trainer.
	---@param only string
	---@param map integer
	---@param trainer { npc: ObviGuideMarker, x: number, y: number, map?: integer }
	---@param shop fun()  the steps that buy the recipes, pole and bauble
	---@param water { x: number, y: number, text: string }
	local function Start(only, map, trainer, shop, water)
		g:Step(function(s)
			s.only = only
			s:Goto(trainer.map or map, trainer.x, trainer.y)
			s:Talk(trainer.npc)
			s:Train(FISH)
			s:Note("Route after wow-professions.com's WoW Forever Fishing and Cooking guide, used with credit.")
			s:Note("Every fish you catch is a Cooking recipe too: keep them all, you cook them in Stormwind.")
		end)
		shop()
		g:Step(function(s)
			s.only = only
			s:Goto(map, water.x, water.y, 25)
			s:Equip(pole)
			s:Use(bauble)
			s:Say(water.text)
			s:Skill(FISH, 75)
			s:Note("About 45 ", smallfish, " and 30 ", longjaw, ".")
		end)
		g:Step(function(s)
			s.only = only
			s:Goto(trainer.map or map, trainer.x, trainer.y)
			s:Talk(trainer.npc)
			s:Train(FISH, 150)
			s:Note("Journeyman Fishing needs level 10.")
		end)
	end

	--- Buying on the way: ticked off by hand, passed over once `skip` holds.
	---@param only string?
	---@param skip string
	---@param map integer
	---@param x number
	---@param y number
	---@param npc ObviGuideMarker
	---@param build fun(s: ObviGuideStepBuilder)
	local function Buy(only, skip, map, x, y, npc, build)
		g:Step(function(s)
			s.only = only
			s.skip = skip
			s:Goto(map, x, y)
			s:Talk(npc)
			build(s)
		end)
	end
	local EARLY = "skill " .. FISH .. " >= 75"
	-- each purchase only while the skill it's for still needs it: the fish recipes until Cooking 100 (the fish you
	-- catch until 75 are cooked up to there), the pole while you have none
	local RECIPES, NO_POLE = "skill " .. COOK .. " < 100", "items 6256 < 1"
	---@param s ObviGuideStepBuilder
	local function Gear(s)
		s:Do(g.Buy("Buy a "), pole, " and a ", bauble, "."):Only(NO_POLE)
		s:Note("Buy any ", attractor, " you see and keep it for the Artisan Fishing quest.")
	end

	-- Fishing 1-75: the starting zone
	Start(IN_ELW, ELWYNN, { npc = g.Npc("Lee Brown", 1651), x = 47.61, y = 62.32 }, function()
		Buy(IN_ELW, EARLY, ELWYNN, 41.82, 67.16, g.Npc("Tharynn Bouden", 66), function(s)
			s:Do(g.Buy("Buy Recipe: Brilliant Smallfish and Recipe: Longjaw Mud Snapper"), "."):Only(RECIPES)
			Gear(s)
		end)
	end, { x = 49.5, y = 63.5, text = "Fish in Crystal Lake, by Lee Brown." })

	Start(IN_DM, DUNMOROGH, { npc = g.Npc("Paxton Ganter", 1700), x = 35.48, y = 40.22 }, function()
		Buy(IN_DM, EARLY, DUNMOROGH, 31.53, 44.65, g.Npc("Gretta Ganter", 8508), function(s)
			s:Do(g.Buy("Buy Recipe: Brilliant Smallfish"), "."):Only(RECIPES)
			s:Note("Recipe: Longjaw Mud Snapper comes later, from Tharynn Bouden in Goldshire.")
			Gear(s)
		end)
	end, { x = 35.0, y = 42.5, text = "Fish in Iceflow Lake." })

	Start(IN_TEL, TELDRASSIL, { npc = g.Npc("Astaia", 4156), map = DARNASSUS, x = 47.89, y = 56.65 }, function()
		Buy(IN_TEL, "skill " .. COOK .. " >= 100", TELDRASSIL, 57.19, 61.26, g.Npc("Nyoma", 4265), function(s)
			s:Do(g.Buy("Buy Recipe: Brilliant Smallfish and Recipe: Longjaw Mud Snapper"), ".")
		end)
		Buy(IN_TEL, EARLY, TELDRASSIL, 55.27, 57.15, g.Npc("Narret Shadowgrove", 3614), function(s)
			Gear(s)
		end)
	end, { x = 58.0, y = 67.5, text = "Fish in Lake Al'Ameth, south of Dolanaar." })

	Start(IN_ZEP, ZEPHRAS, { npc = g.Npc("Fenn Fairweather", 251992), x = 45.02, y = 48.44 }, function()
		Buy(IN_ZEP, EARLY, ZEPHRAS, 44.77, 45.05, g.Npc("Belandiel Farflight", 254360), function(s)
			Gear(s)
			s:Note("Baelann Swiftcurrent in Valanaar teaches Fishing and sells them too.")
		end)
	end, { x = 45.0, y = 48.4, text = "Fish in any lake or river on Zephras Isle, e.g. by Fenn Fairweather." })
	Buy(IN_ZEP, "skill " .. COOK .. " >= 100", ZEPHRAS, 60.64, 72.66, g.Npc("Nyalah Brightfire", 257006), function(s)
		s:Do(g.Buy("Buy Recipe: Brilliant Smallfish and Recipe: Longjaw Mud Snapper"), " in Valanaar.")
	end)

	-- Fishing 75-130 and Cooking 1-100: Stormwind
	g:Step(function(s)
		s:Goto(SW, 78.17, 53.10)
		s:Talk(ryback)
		s:Train(COOK)
		s:Note("Cooking takes no profession slot in Forever. You learn Basic Campfire Kit with it, to cook anywhere.")
	end)
	Buy(nil, "skill " .. COOK .. " >= 175", SW, 55.09, 69.76, g.Npc("Catherine Leland", 5494), function(s)
		s:Do(g.Buy("Buy Recipe: Bristle Whisker Catfish"), ".")
		s:Note("No Recipe: Longjaw Mud Snapper yet? Tharynn Bouden in Goldshire sells it.")
	end)
	Buy(nil, "items 8932 >= 20 or done " .. CLAMLETTE .. " or skill " .. COOK .. " > 225", SW, 66.36, 73.51, g.Npc("Ben Trias", 4981), function(s)
		s:Do(g.Buy("Buy 20 "), swiss, ": for the Artisan Cooking quest, much later.")
	end)
	g:Step(function(s)
		s:Goto(SW, 54.0, 67.0, 25)
		s:Say("Fish in the canals of Stormwind. From 75 no fish gets away.")
		s:Skill(FISH, 130)
		s:Note("About 20 ", smallfish, ", 60 ", longjaw, " and 30 ", catfish, ".")
	end)
	g:Step(function(s)
		s:Say("Learn Recipe: Brilliant Smallfish and cook your ", smallfish, ".")
		s:Skill(COOK, 50)
		s:Note("A few points short? Catch and cook a few more.")
	end)
	g:Step(function(s)
		s:Goto(SW, 78.17, 53.10)
		s:Talk(ryback)
		s:Train(COOK, 150)
	end)
	g:Step(function(s)
		s.skip = "skill " .. COOK .. " >= 100"
		s:Do("Learn Recipe: Longjaw Mud Snapper and cook all your ", longjaw, ".")
		s:Note("It should take you past 100. If not, you catch more of them later.")
	end)

	-- Fishing 130-205 and Cooking 100-175: Booty Bay, then Mystral Lake
	Buy(nil, "skill " .. FISH .. " >= 205", STV, 27.42, 77.16, g.Npc("Old Man Heming", 2626), function(s)
		s:Do(g.Buy("Buy "), g.Item("Expert Fishing - The Bass and You", 16083), " in Booty Bay.")
	end)
	g:Step(function(s)
		s:Train(FISH, 225)
		s:Note("Read Expert Fishing - The Bass and You from your bags. Needs level 20 and Fishing 125.")
	end)
	Buy(nil, "skill " .. COOK .. " >= 250", STV, 28.23, 74.34, g.Npc("Kelsey Yance", 2664), function(s)
		s:Do(g.Buy("Buy Recipe: Mithril Head Trout and Recipe: Filet of Redgill"), ".")
	end)
	Buy(nil, "skill " .. FISH .. " >= 205", ASH, 49.48, 67.09, g.Npc("Shandrina", 3955), function(s)
		s:Do(g.Buy("Buy the "), g.Item("Expert Cookbook", 16072), " and 5 ", crawlers, " at Mystral Lake.")
		s:Note("2 last until 150. Keep the other 3 for Dustwallow Marsh, where nobody sells them.")
	end)
	g:Step(function(s)
		s:Goto(ASH, 49.0, 68.5, 30)
		s:Use(crawlers)
		s:Say("Fish in the open water of Mystral Lake.")
		s:Skill(FISH, 205)
		s:Note("About 95 ", longjaw, " and 145 ", catfish, ".")
	end)
	g:Step(function(s)
		s:Say("Cook ", longjaw, " (below 100), then learn Recipe: Bristle Whisker Catfish and cook ", catfish, ".")
		s:Skill(COOK, 125)
	end)
	g:Step(function(s)
		s:Train(COOK, 225)
		s:Note("Read the Expert Cookbook from your bags now: without it you stop getting points at 150.")
	end)
	g:Step(function(s)
		s.skip = "skill " .. COOK .. " >= 175"
		s:Do("Cook all your ", catfish, ".")
		s:Note("It should come close to 175. If not, you catch more of them in Dustwallow Marsh.")
	end)

	-- Artisan Fishing: Nat Pagle's quest (needs level 35 and Fishing 225)
	Buy(nil, "items 6530 >= 1 or skill " .. FISH .. " >= 225", BARRENS, 62.77, 38.24, g.Npc("Kilxx", 3497), function(s)
		s:Do(g.Buy("No Nightcrawlers left? Buy 3"), " in Ratchet: nobody in Dustwallow Marsh sells them.")
	end)
	g:Step(function(s)
		s:Use(crawlers)
		s:Say("Fish in any inland open water in Dustwallow Marsh (not the sea).")
		s:Skill(FISH, 225)
		s:Note("A few fish get away until 225: keep a Nightcrawler on.")
	end)
	g:Step(function(s)
		s:Level(35)
		s:Goto(DUSTWALLOW, 58.61, 60.06)
		s:Talk(pagle)
		s:Accept(NAT, "Nat Pagle, Angler Extreme")
		s:Note("Needs level 35 and Fishing 225. It is how you learn Artisan Fishing.")
	end)
	g:Step(function(s)
		s.skip = "done " .. NAT
		s:Collect(g.Item("Feralas Ahi", 16967), { count = 1 })
		s:Note("Feralas: put on the ", attractor, " you kept, or Bright Baubles from Vivianna, or most get away.")
		s:Collect(g.Item("Misty Reed Mahi Mahi", 16970), { count = 1 })
		s:Note("Swamp of Sorrows.")
		s:Collect(g.Item("Sar'theris Striker", 16968), { count = 1 })
		s:Note("Desolace.")
		s:Collect(g.Item("Savage Coast Blue Sailfin", 16969), { count = 1 })
		s:Note("Stranglethorn Vale.")
		s:Note("The site didn't test this quest on the Forever beta: it should be as in Classic.")
	end)
	g:Step(function(s)
		s:Goto(DUSTWALLOW, 58.61, 60.06)
		s:Talk(pagle)
		s:Turnin(NAT, "Nat Pagle, Angler Extreme")
		s:Train(FISH, 300)
	end)

	-- Fishing 225-255 and Cooking 175-225: Dustwallow Marsh
	g:Step(function(s)
		s:Say("Keep fishing inland in Dustwallow Marsh.")
		s:Skill(FISH, 255)
	end)
	g:Step(function(s)
		s:Say("Cook at Theramore Isle or a campfire: ", catfish, " (below 175), then learn Recipe: Mithril Head Trout and cook ", trout, ".")
		s:Skill(COOK, 225)
		s:Note("Stop at 225 and keep the rest of the trout.")
	end)

	-- Artisan Cooking: Dirge's quest in Gadgetzan (needs level 35 and Cooking 225)
	g:Step(function(s)
		s:Level(35)
		s:Goto(TAN, 52.63, 28.11)
		s:Talk(g.Npc("Dirge Quikcleave", 8125))
		s:Accept(CLAMLETTE, "Clamlette Surprise")
	end)
	g:Step(function(s)
		s.skip = "done " .. CLAMLETTE
		s:Collect(g.Item("Giant Egg", 12207), { count = 12 })
		s:Note("From the rocs in Tanaris.")
		s:Collect(g.Item("Zesty Clam Meat", 7974), { count = 10 })
		s:Note("From Big-mouth Clams: Steeljaw Snappers and Surf Gliders on the Tanaris coast drop them.")
		s:Collect(swiss, { count = 20 })
	end)
	g:Step(function(s)
		s:Goto(TAN, 52.63, 28.11)
		s:Talk(g.Npc("Dirge Quikcleave", 8125))
		s:Turnin(CLAMLETTE, "Clamlette Surprise")
		s:Train(COOK, 300)
	end)
	Buy(nil, "skill " .. COOK .. " >= 290", TAN, 66.64, 22.08, g.Npc("Gikkix", 8137), function(s)
		s:Do(g.Buy("Buy Recipe: Nightfin Soup, Recipe: Poached Sunscale Salmon and Recipe: Spotted Yellowtail"), " at Steamwheedle Port.")
	end)

	-- Fishing 255-300: Feralas, then Cooking to 300
	Buy(nil, "skill " .. FISH .. " >= 300", FERALAS, 31.30, 43.46, g.Npc("Vivianna", 7947), function(s)
		s:Do(g.Buy("Buy Recipe: Baked Salmon and 10 "), crawlers, " at Feathermoon Stronghold.")
	end)
	g:Step(function(s)
		s:Use(crawlers)
		s:Say("Fish in Feralas's inland water (any lake but Jademir Lake). A new Nightcrawler every 10 minutes.")
		s:Skill(FISH, 300)
	end)
	g:Step(function(s)
		s:Say("Cook the rest of your ", trout, ", then learn Recipe: Filet of Redgill and cook ", g.Item("Raw Redgill", 13758), ".")
		s:Skill(COOK, 250)
	end)
	g:Step(function(s)
		s:Say("Learn Recipe: Nightfin Soup and Recipe: Poached Sunscale Salmon and cook those fish.")
		s:Note("From 275, Recipe: Baked Salmon too if you caught Raw Whitescale Salmon.")
		s:Note("Not enough fish for 300? Fish a bit longer, or buy a few on the Auction House.")
		s:Skill(COOK, 300)
	end)
end)
