-- Cooking 1-300 (Alliance). The recipes, counts, skill ranges, rank-ups, trainers and vendors follow
-- wow-professions.com's WoW Forever Cooking guide: https://www.wow-professions.com/forever/cooking-leveling-guide (used
-- with credit; will be removed on request). The step text is our own. The site's Artisan part (225-300) was not tested
-- on the Forever beta. NPC ids and positions come from QuestieDB's Forever data. See README.md.

local SW, IF, ASH, TAN = 1453, 1455, 1440, 1446
local COOK = "Cooking"

-- who trains where: Ironforge for dwarves and gnomes, Stormwind for everyone else
local IN_IF, IN_SW = "Dwarf or Gnome", "not (Dwarf or Gnome)"

ObviGuide.Guide(function(g)
	g.title = "Cooking (1-300)"
	g.group = "Professions"
	g.id    = "obvi-cooking"
	g.only  = "Alliance"

	local mild, hot, soothing = g.Item("Mild Spices", 2678), g.Item("Hot Spices", 2692), g.Item("Soothing Spices", 3713)
	local water = g.Item("Refreshing Spring Water", 159)

	---@class CookPlace
	---@field npc ObviGuideMarker
	---@field x number
	---@field y number

	--- A visit to the city for your race: Stormwind's or Ironforge's NPC, with the lines `build` adds.
	---@param sw CookPlace
	---@param ir CookPlace
	---@param build fun(s: ObviGuideStepBuilder)
	local function City(sw, ir, build)
		g:Step(function(s)
			s.only = IN_SW
			s:Goto(SW, sw.x, sw.y)
			s:Talk(sw.npc)
			build(s)
		end)
		g:Step(function(s)
			s.only = IN_IF
			s:Goto(IF, ir.x, ir.y)
			s:Talk(ir.npc)
			build(s)
		end)
	end
	local trainers = { { npc = g.Npc("Stephen Ryback", 5482), x = 78.17, y = 53.10 },
		{ npc = g.Npc("Daryl Riknussun", 5159), x = 60.08, y = 36.43 } }
	local supplies = { { npc = g.Npc("Erika Tate", 5483), x = 78.53, y = 52.88 },
		{ npc = g.Npc("Emrul Riknussun", 5160), x = 59.88, y = 37.37 } }

	--- Cooking up to a skill level: about `count` of any of the recipes the notes list.
	---@param to integer
	---@param count integer
	---@param notes fun(s: ObviGuideStepBuilder)
	local function Cook(to, count, notes)
		g:Step(function(s)
			s:Say("Cook about " .. count .. " of any of these (or a mix):")
			notes(s)
			s:Skill(COOK, to)
		end)
	end

	--- A recipe (or book) to buy on the way: ticked off by hand, passed over once you're past `upTo`.
	---@param upTo integer
	---@param map integer
	---@param x number
	---@param y number
	---@param npc ObviGuideMarker
	---@param build fun(s: ObviGuideStepBuilder)
	local function Buy(upTo, map, x, y, npc, build)
		g:Step(function(s)
			s.skip = "skill " .. COOK .. " >= " .. upTo
			s:Goto(map, x, y)
			s:Talk(npc)
			build(s)
		end)
	end

	-- Apprentice (1-50)
	City(trainers[1], trainers[2], function(s)
		s:Train(COOK)
		s:Note("Route after wow-professions.com's WoW Forever Cooking guide, used with credit.")
		s:Note("Cooking takes no profession slot in Forever. You learn Basic Campfire Kit with it: a campfire you place from your bags, made from Simple Wood and Flint and Tinder.")
	end)
	City(supplies[1], supplies[2], function(s)
		s:Do(g.Buy("Buy Simple Wood and Flint and Tinder"), " for campfire kits, and Mild Spices if you'll make Herb Baked Eggs.")
		s:Note("Spices and Refreshing Spring Water come from the Cooking supply vendors; the Auction House charges more.")
	end)
	Cook(50, 55, function(s)
		s:Note(g.Item("Brilliant Smallfish"), ": raw fish from Tharynn Bouden (Goldshire), Gretta Ganter (Dun Morogh) or Catherine Leland (Stormwind).")
		s:Note(g.Item("Slitherskin Mackerel"), ": raw fish from Tansy Puddlefizz (Ironforge) or Kriggon Talsone (Westfall).")
		s:Note(g.Item("Charred Wolf Meat"), " (Stringy Wolf Meat) or ", g.Item("Roasted Boar Meat"), " (Chunk of Boar Meat).")
		s:Note(g.Item("Herb Baked Egg"), ": Small Egg and ", mild, ".")
	end)

	-- Journeyman (50-150)
	City(trainers[1], trainers[2], function(s)
		s:Train(COOK, 150)
		s:Note("Needs Cooking 50. Learn it before 75: without it you stop getting points there.")
	end)
	Cook(100, 55, function(s)
		s:Note(g.Item("Longjaw Mud Snapper"), " or ", g.Item("Rainbow Fin Albacore"), ": raw fish from Catherine Leland (Stormwind), Tansy Puddlefizz (Ironforge) or Khara Deepwater (Loch Modan).")
		s:Note(g.Item("Smoked Bear Meat"), " (Bear Meat; recipe from Drac Roughcut in Loch Modan). It turns yellow sooner: make 65-75.")
		s:Note(g.Item("Boiled Clams"), " (Clam Meat and ", water, ") or ", g.Item("Coyote Steak"), " (Coyote Meat).")
	end)
	Buy(170, SW, 77.47, 52.69, g.Npc("Kendor Kabonka", 340), function(s)
		s:Do(g.Buy("Buy Recipe: Cooked Crab Claw and Recipe: Curiously Tasty Omelet"), ".")
		s:Note("Both are used from 100 to 175.")
	end)
	Cook(130, 35, function(s)
		s:Note(g.Item("Bristle Whisker Catfish"), ": raw fish from Catherine Leland (Stormwind). Buy about 55: 25 more are used at 130-150.")
		s:Note(g.Item("Crab Cake"), " (Crawler Meat and ", mild, ") or ", g.Item("Cooked Crab Claw"), " (Crawler Claw and ", mild, ").")
		s:Note(g.Item("Dry Pork Ribs"), " (Boar Ribs and ", mild, ").")
	end)
	Cook(150, 25, function(s)
		s:Note(g.Item("Bristle Whisker Catfish"), ", the rest of the raw fish.")
		s:Note(g.Item("Curiously Tasty Omelet"), " (Raptor Egg and ", hot, ").")
		s:Note(g.Item("Goblin Deviled Clams"), " (Tangy Clam Meat and ", hot, ").")
	end)

	-- Expert (150-225): a book, sold in Ashenvale
	-- (past 150 only with the book learned)
	Buy(151, ASH, 49.48, 67.09, g.Npc("Shandrina", 3955), function(s)
		s:Do(g.Buy("Buy the "), g.Item("Expert Cookbook", 16072), " at Mystral Lake, then use it.")
	end)
	g:Step(function(s)
		s:Train(COOK, 225)
		s:Note("Use the Expert Cookbook from your bags. Needs Cooking 125.")
	end)
	Cook(175, 25, function(s)
		s:Note(g.Item("Curiously Tasty Omelet"), " (Raptor Egg and ", hot, "). It turns yellow from 170: make a few extra.")
	end)
	Cook(225, 50, function(s)
		s:Note(g.Item("Mithril Headed Trout"), ": raw fish from Tansy Puddlefizz (Ironforge), Stuart Fleming (Wetlands), Lindea Rabonne (Hillsbrad) or Kelsey Yance (Stranglethorn).")
		s:Note(g.Item("Roast Raptor"), " (Raptor Flesh and ", hot, "; recipe from Hammon Karwn in Arathi Highlands).")
		s:Note(g.Item("Soothing Turtle Bisque"), " (Turtle Meat and ", soothing, "; recipe from Chef Jessen's quest in Hillsbrad).")
		s:Note("All three turn yellow from 215: the last points take more.")
	end)

	-- Artisan (225-300): a quest, ending in Gadgetzan
	g:Step(function(s)
		s.skip = "skill " .. COOK .. " >= 226"   -- (only possible once Artisan is learned)
		s:Goto(IF, 60.08, 36.43)
		s:Talk(trainers[2].npc)
		s:Do('Accept "I Know A Guy..." (needs level 35 and Cooking 225).')
		s:Note("Get 12 ", g.Item("Giant Egg", 12207), ", 10 ", g.Item("Zesty Clam Meat", 7974), " and 20 ", g.Item("Alterac Swiss", 8932), " before you go to Gadgetzan.")
		s.only = "level >= 35"
	end)
	g:Step(function(s)
		s:Goto(TAN, 52.63, 28.11)
		s:Talk(g.Npc("Dirge Quikcleave", 8125))
		s:Train(COOK, 300)
		s:Note("Hand in the eggs, clams and cheese (Clamlette Surprise): Dirge teaches Artisan Cooking.")
	end)
	Buy(290, TAN, 66.64, 22.08, g.Npc("Gikkix", 8137), function(s)
		s:Do(g.Buy("Buy Gikkix's recipes"), ": Spotted Yellowtail, Poached Sunscale Salmon and Nightfin Soup.")
	end)
	Cook(275, 65, function(s)
		s:Note(g.Item("Spotted Yellowtail"), ": raw fish from Gikkix.")
		s:Note(g.Item("Filet of Redgill"), ": recipe and raw fish from Kelsey Yance (Stranglethorn).")
		s:Note(g.Item("Undermine Clam Chowder"), " (2 Zesty Clam Meat, ", hot, ", Ice Cold Milk from innkeepers; recipe from Jabbey, Gadgetzan).")
		s:Note(g.Item("Monster Omelet"), " (Giant Egg, 2 ", soothing, "; recipe from Himmik, Winterspring, or Malygen, Felwood).")
		s:Note(g.Item("Tender Wolf Steak"), " (Tender Wolf Meat and ", soothing, "; recipe from Dirge).")
	end)
	Cook(300, 35, function(s)
		s:Note(g.Item("Poached Sunscale Salmon"), " (Raw Sunscale Salmon) or ", g.Item("Nightfin Soup"), " (Raw Nightfin Snapper and ", water, ").")
		s:Note("Both turn yellow from 290. If they're dear, keep cooking the 225-275 dishes up to 285.")
		s:Note("The site didn't test 225-300 on the Forever beta: it should be as in Classic.")
	end)
end)
