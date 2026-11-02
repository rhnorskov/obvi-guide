-- Mining 1-300 (Alliance). The route, zones, skill ranges and rank-ups follow wow-professions.com's WoW Forever
-- Mining guide: https://www.wow-professions.com/forever/mining-leveling-guide (used with credit; will be removed on
-- request). The step text is our own. Trainer and vendor ids and positions come from QuestieDB's Forever data; the
-- waypoint in each mining zone is a spot where that ore's veins are dense in QuestieDB's spawn data, not the site's
-- route (its route maps are pictures). See README.md.

local SW, IF, DARKSHORE, DARNASSUS = 1453, 1455, 1439, 1457
local ELWYNN, DUN_MOROGH, WETLANDS, ARATHI, HINTERLANDS, UNGORO = 1429, 1426, 1437, 1417, 1425, 1449

-- who trains where: Ironforge for dwarves and gnomes, Auberdine for night elves (Darnassus has no Mining trainer),
-- Stormwind for everyone else
local IN_IF, IN_DARKSHORE, IN_SW = "Dwarf or Gnome", "NightElf", "not (Dwarf or Gnome or NightElf)"

ObviGuide.Guide(function(g)
	g.title = "Mining (1-300)"
	g.group = "Professions"
	g.id    = "obvi-mining"
	g.only  = "Alliance"

	local gelman  = g.Npc("Gelman Stonehand", 5513)
	local geofram = g.Npc("Geofram Bouldertoe", 4254)
	local kurdram = g.Npc("Kurdram Stonehammer", 6297)
	local pick    = g.Item("Mining Pick", 2901)

	--- A visit to the Mining trainer (the one for your race), with the lines `build` adds.
	---@param build fun(s: ObviGuideStepBuilder)
	local function Trainer(build)
		g:Step(function(s)
			s.only = IN_SW
			s:Goto(SW, 59.25, 37.83)
			s:Talk(gelman)
			build(s)
		end)
		g:Step(function(s)
			s.only = IN_IF
			s:Goto(IF, 50.00, 26.29)
			s:Talk(geofram)
			build(s)
		end)
		g:Step(function(s)
			s.only = IN_DARKSHORE
			s:Goto(DARKSHORE, 38.25, 41.01)
			s:Talk(kurdram)
			build(s)
		end)
	end

	Trainer(function(s)
		s:Train("Mining")
		s:Note("Route after wow-professions.com's WoW Forever Mining guide, used with credit.")
		s:Note("Turn on ", g.Spell("Find Minerals", 2580), " in the Professions window and put it on a bar. It turns off when you die.")
	end)

	-- the pick is required; the Mining supplier stands next to the trainer
	g:Step(function(s)
		s.only = IN_SW
		s:Goto(SW, 59.15, 37.50)
		s:Talk(g.Npc("Brooke Stonebraid", 5514))
		s:Collect(pick)
		s:Note(g.Buy("Buy a Mining Pick."))
	end)
	g:Step(function(s)
		s.only = IN_IF
		s:Goto(IF, 51.74, 42.78)
		s:Talk(g.Npc("Thurgrum Deepforge", 4259))
		s:Collect(pick)
		s:Note(g.Buy("Buy a Mining Pick."))
	end)
	g:Step(function(s)
		s.only = IN_DARKSHORE
		s:Goto(DARNASSUS, 60.96, 17.67)
		s:Talk(g.Npc("Mythrin'dir", 4229))
		s:Collect(pick)
		s:Note(g.Buy("Buy a Mining Pick."))
	end)

	-- 1-65: Copper
	g:Step(function(s)
		s.only = "not (Dwarf or Gnome)"
		s:Goto(ELWYNN, 40.4, 79.7)
		s:Skill("Mining", 65)
		s:Note("Mine ", g.Item("Copper Ore", 2770), " in loops around Elwynn Forest; the cave is optional.")
		s:Note("Smelt it at the forge in Goldshire after each lap.")
		s:Note("Shortcut: buy about 140 Copper Ore and 70 Tin Ore and smelt your way to 105 (Copper to 65, then Tin and Bronze).")
	end)
	g:Step(function(s)
		s.only = "Dwarf or Gnome"
		s:Goto(DUN_MOROGH, 71.2, 53.0)
		s:Skill("Mining", 65)
		s:Note("Mine ", g.Item("Copper Ore", 2770), " in loops; the two caves respawn very fast.")
		s:Note("Smelt it at the forge in Kharanos after each lap.")
		s:Note("Shortcut: buy about 140 Copper Ore and 70 Tin Ore and smelt your way to 105 (Copper to 65, then Tin and Bronze).")
	end)

	Trainer(function(s)
		s:Train("Mining", 150)
		s:Note("Needs Mining 50. The Junior Mining Trainers in the starting areas don't teach it.")
		s:Note("Smelt any Copper and Tin you have and make Bronze now: smelting stops giving points around 105.")
	end)

	-- 65-125: Tin and Silver
	g:Step(function(s)
		s:Goto(WETLANDS, 49.5, 61.1)
		s:Skill("Mining", 125)
		s:Note("The Wetlands cave is full of ", g.Item("Tin Ore", 2771), " and Incendicite veins that respawn very fast.")
		s:Note("Tin Veins need 65, Silver Veins 75. Mobs are about level 20 and respawn fast here: outlevel them well.")
		s:Note("Westfall's Tin cave (mobs 13-15) is the easier alternative.")
	end)

	Trainer(function(s)
		s:Train("Mining", 225)
		s:Note("Needs Mining 125.")
		s:Note("Optional: smelt about 20 ", g.Item("Iron Ore", 2772), " up to 135; after that it rarely gives a point.")
	end)

	-- 125-175: Iron and Gold
	g:Step(function(s)
		s:Goto(ARATHI, 33.3, 44.9)
		s:Skill("Mining", 175)
		s:Note("Mine ", g.Item("Iron Ore", 2772), " around Arathi Highlands; Gold Veins open at 155.")
		s:Note(g.Warn("Low level: skip the four caves, and go round south of Hammerfall."))
		s:Note("Around level 30, Thousand Needles is the safer zone.")
		s:Note("Optional: at 155 learn Smelt Gold; about 22 ", g.Item("Gold Ore", 2776), " takes you from 155 to 175.")
	end)

	-- 175-245: Mithril and Truesilver
	g:Step(function(s)
		s:Goto(HINTERLANDS, 57.4, 43.2)
		s:Skill("Mining", 200)
		s:Note("Mine ", g.Item("Mithril Ore", 3858), " in The Hinterlands (or Tanaris).")
		s:Note(g.Warn("Parts of The Hinterlands are full of level 62 elites; keep to the safer veins if you're low."))
	end)

	Trainer(function(s)
		s:Train("Mining", 300)
		s:Note("Needs Mining 200; you can't go past 225 without it.")
	end)

	g:Step(function(s)
		s:Goto(HINTERLANDS, 57.4, 43.2)
		s:Skill("Mining", 245)
		s:Note("Keep mining ", g.Item("Mithril Ore", 3858), "; Truesilver Deposits open at 230.")
		s:Note("In Tanaris, skip the four big caves below level 60.")
	end)

	-- 245-275: Thorium
	g:Step(function(s)
		s:Goto(UNGORO, 66.7, 15.5)
		s:Skill("Mining", 275)
		s:Note("Mine Small Thorium Veins (", g.Item("Thorium Ore", 10620), ") around Un'Goro Crater; its two caves have 2-3 veins each.")
		s:Note("Lower levels may want to skip the southern cave.")
		s:Note("Also good: the Jaedenar cave in Felwood (about 2 veins, few mobs).")
		s:Note(g.Warn("Blasted Lands: Alliance can't mine inside the Garrison Armory."))
	end)

	-- 275-300: Thorium and Rich Thorium
	g:Step(function(s)
		s:Goto(UNGORO, 66.7, 15.5)
		s:Skill("Mining", 300)
		s:Note("The same Un'Goro loop; Rich Thorium Veins open at 275.")
		s:Note("Eastern Plaguelands (elites level 57-58 in parts) and Burning Steppes (caves with level 50 mobs) work too.")
		s:Note("Winterspring is hard to farm without dying; most players should avoid it.")
	end)
end)
