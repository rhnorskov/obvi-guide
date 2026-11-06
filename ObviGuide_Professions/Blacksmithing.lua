-- Blacksmithing 1-300 (Alliance). The recipes, counts, skill ranges, trainers and vendors follow wow-professions.com's
-- WoW Forever Blacksmithing guide: https://www.wow-professions.com/forever/blacksmithing-leveling-guide (used with
-- credit; will be removed on request). The step text is our own. The site's 225-300 part is untested (it goes by the
-- game's data). Trainer and vendor ids and positions come from QuestieDB's Forever data. See README.md.

local SW, IF, STV = 1453, 1455, 1434
local BS = "Blacksmithing"

-- who trains where: Ironforge for dwarves and gnomes, Stormwind for everyone else
local IN_IF, IN_SW = "Dwarf or Gnome", "not (Dwarf or Gnome)"

ObviGuide.Guide(function(g)
	g.title = "Blacksmithing (1-300)"
	g.group = "Professions"
	g.id    = "obvi-blacksmithing"
	g.only  = "Alliance"

	local roughStone     = g.Item("Rough Stone", 2835)
	local coarseStone    = g.Item("Coarse Stone", 2836)
	local heavyStone     = g.Item("Heavy Stone", 2838)
	local copperBar      = g.Item("Copper Bar", 2840)
	local bronzeBar      = g.Item("Bronze Bar", 2841)
	local ironBar        = g.Item("Iron Bar", 3575)
	local steelBar       = g.Item("Steel Bar", 3859)
	local mithrilBar     = g.Item("Mithril Bar", 3860)
	local leather        = g.Item("Medium Leather", 2319)
	local weakFlux       = g.Item("Weak Flux", 2880)
	local strongFlux     = g.Item("Strong Flux", 3466)
	local roughGrinding  = g.Item("Rough Grinding Stone", 3470)
	local coarseGrinding = g.Item("Coarse Grinding Stone", 3478)
	local heavyGrinding  = g.Item("Heavy Grinding Stone", 3486)
	local bronzeBracers  = g.Item("Patterned Bronze Bracers", 2868)
	local warhammer      = g.Item("Bronze Warhammer", 7956)

	---@class BSPlace
	---@field npc ObviGuideMarker
	---@field x number
	---@field y number

	--- A visit to the city for your race: Stormwind's or Ironforge's NPC, with the lines `build` adds.
	---@param sw BSPlace
	---@param ir BSPlace
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
	-- the supply vendors (hammer, flux, coal) stand next to the trainers
	local swSupply = { npc = g.Npc("Kaita Deepforge", 5512), x = 63.26, y = 37.74 }
	local ifSupply = { npc = g.Npc("Thurgrum Deepforge", 4259), x = 51.74, y = 42.78 }

	--- Getting the materials for a range: done once they are in your bags, passed over once you're past the range.
	---@param to integer
	---@param mats {[1]: ObviGuideMarker, [2]: integer}[]
	---@param notes? fun(s: ObviGuideStepBuilder)
	local function Materials(to, mats, notes)
		g:Step(function(s)
			s.skip = "skill " .. BS .. " >= " .. to
			for i = 1, #mats do s:Collect(mats[i][1], { count = mats[i][2] }) end
			if notes then notes(s) end
		end)
	end

	--- Crafting up to a skill level.
	---@param to integer
	---@param count integer
	---@param item ObviGuideMarker
	---@param notes? fun(s: ObviGuideStepBuilder)
	local function Craft(to, count, item, notes)
		g:Step(function(s)
			s:Say("Make " .. count .. " ", item, ".")
			if notes then notes(s) end
			s:Skill(BS, to)
		end)
	end

	City({ npc = g.Npc("Dane Lindgren", 957), x = 64.12, y = 37.02 },
		{ npc = g.Npc("Groum Stonebeard", 10277), x = 52.26, y = 41.94 }, function(s)
		s:Train(BS)
		s:Note("Route after wow-professions.com's WoW Forever Blacksmithing guide, used with credit.")
		s:Note("Also train Rough Sharpening Stone. Train each new recipe below as you reach it.")
		s:Note("Blacksmithing eats a lot of ore: it goes well with Mining.")
	end)

	City(swSupply, ifSupply, function(s)
		s:Collect(g.Item("Blacksmith Hammer", 5956))
		s:Note(g.Buy("Buy a Blacksmith Hammer"), " (a few copper). Most recipes need it; from 67 on, all of them.")
	end)

	-- Apprentice (1-75)
	Materials(25, { { roughStone, 30 } }, function(s)
		s:Note("Rough Stone comes from Copper Veins, or the Auction House.")
	end)
	Craft(25, 30, g.Item("Rough Sharpening Stone", 2862))

	Materials(50, { { roughStone, 60 } })
	Craft(50, 30, roughGrinding, function(s)
		s:Note("Train Rough Grinding Stone first. Keep 26: 16 for the gauntlets at 67, 10 if you make Silver Rods at 75.")
	end)

	Materials(67, { { coarseStone, 72 } }, function(s)
		s:Note("Coarse Stone comes from Tin Veins, or the Auction House.")
	end)
	Craft(67, 36, coarseGrinding, function(s)
		s:Note("Train Coarse Grinding Stone first. Make and keep all 36, for the bracers at 95 and 112.")
	end)

	Materials(75, { { copperBar, 64 }, { roughGrinding, 16 } })
	Craft(75, 8, g.Item("Runed Copper Gauntlets", 3472), function(s)
		s:Note("Train Runed Copper Gauntlets first. The hammer is needed from here on.")
	end)

	-- Journeyman (75-150)
	City({ npc = g.Npc("Therum Deepforge", 5511), x = 63.66, y = 37.01 },
		{ npc = g.Npc("Rotgath Stonebeard", 10276), x = 52.36, y = 42.55 }, function(s)
		s:Train(BS, 150)
		s:Note("Needs Blacksmithing 50 and level 10.")
	end)

	-- no materials step here: the site gives a choice
	Craft(80, 5, g.Item("Runed Copper Belt", 2857), function(s)
		s:Note("50 ", copperBar, " in all.")
		s:Note("Or 5 ", g.Item("Silver Rod", 6338), " (1 Silver Bar and 2 Rough Grinding Stone each), if Silver Bars cost less than 10 Copper Bars.")
	end)

	Materials(95, { { copperBar, 180 } })
	Craft(95, 18, g.Item("Runed Copper Belt", 2857))

	Materials(100, { { bronzeBar, 25 }, { coarseGrinding, 10 } }, function(s)
		s:Note("Smelt Bronze from Copper and Tin Bars (Mining), or buy it.")
	end)
	Craft(100, 5, bronzeBracers)

	Materials(112, { { heavyStone, 60 } }, function(s)
		s:Note("Heavy Stone comes from Iron Deposits, or the Auction House.")
	end)
	Craft(112, 20, heavyGrinding, function(s)
		s:Note("Keep all 20 for the Golden Scale Bracers at 175.")
	end)

	Materials(125, { { bronzeBar, 65 }, { coarseGrinding, 26 } })
	Craft(125, 13, bronzeBracers)

	-- the flux for 125-165 in one go
	City(swSupply, ifSupply, function(s)
		s.skip = "skill " .. BS .. " >= 140"
		s:Collect(weakFlux, { count = 96 })
		s:Collect(strongFlux, { count = 29 })
		s:Note(g.Buy("Buy 96 Weak Flux and 29 Strong Flux"), " (10 for 140-150, 19 for 150-165).")
	end)

	Materials(140, { { bronzeBar, 120 }, { weakFlux, 96 }, { leather, 48 } })
	Craft(140, 24, g.Item("Bronze Shortsword", 2850))

	Materials(150, { { bronzeBar, 80 }, { strongFlux, 10 }, { leather, 10 } })
	Craft(150, 10, warhammer)

	-- Expert (150-215): the trainer is in Ironforge for everyone
	g:Step(function(s)
		s:Goto(IF, 52.55, 41.46)
		s:Talk(g.Npc("Bengus Deepforge", 4258))
		s:Train(BS, 225)
		s:Note("Needs Blacksmithing 125, level 20 and 50 silver.")
	end)

	Materials(165, { { bronzeBar, 152 }, { strongFlux, 19 }, { leather, 19 } })
	Craft(165, 19, warhammer)

	g:Step(function(s)
		s.skip = "skill " .. BS .. " >= 175"
		s:Goto(IF, 39.62, 34.49)
		s:Talk(g.Npc("Bombus Finespindle", 5128))
		s:Collect(g.Item("Green Dye", 2605), { count = 15 })
		s:Note(g.Buy("Buy 15 Green Dye."))
	end)

	Materials(175, { { ironBar, 90 } })
	Craft(175, 15, g.Item("Green Iron Bracers", 3835))

	Materials(185, { { steelBar, 50 }, { heavyGrinding, 20 } }, function(s)
		s:Note("With Mining 165 you can smelt Steel yourself: 1 ", ironBar, " and 1 ", g.Item("Coal", 3857),
			" each (Coal from the Blacksmithing supply vendor).")
	end)
	Craft(185, 10, g.Item("Golden Scale Bracers", 6040))

	-- no materials step here: the site gives a cheaper choice when Mithril is dear
	Craft(215, 36, g.Item("Mithril Plate Pants"), function(s)
		s:Note("432 ", mithrilBar, " in all (12 each).")
		s:Note("If Mithril is dear: 15 Steel Breastplate to 200 (240 Steel Bar, 45 Heavy Grinding Stone), then 17 Steel Plate Helm to 215 (238 Steel Bar, 17 Solid Grinding Stone).")
	end)

	-- Artisan (215-225)
	g:Step(function(s)
		s:Goto(STV, 28.99, 75.56)
		s:Talk(g.Npc("Brikk Keencraft", 2836))
		s:Train(BS, 300)
		s:Note("Needs Blacksmithing 200 and level 35. Brikk is in Booty Bay and trains both factions.")
	end)

	Craft(225, 10, g.Item("Heavy Mithril Breastplate", 7930), function(s)
		s:Note("160 ", mithrilBar, " in all.")
		s:Note("Or, if you find ", g.Item("Plans: Mithril Spurs", 7989), " (a world drop), 10 Mithril Spurs: 40 Mithril Bar and 30 Solid Grinding Stone.")
	end)

	-- 225-300: the site hasn't tested this part (it couldn't get past 225 on the beta); it goes by the game's data
	Craft(230, 5, g.Item("Dense Sharpening Stone"), function(s)
		s:Note("5 ", g.Item("Dense Stone"), ". The site didn't test 225-300 in Forever: expect changes.")
	end)
	Craft(240, 16, g.Item("Heavy Mithril Boots"), function(s)
		s:Note("224 ", mithrilBar, " and 64 ", g.Item("Thick Leather"), " in all.")
	end)

	-- the Imperial Plate plans: Thorium Brotherhood quests in Gadgetzan, each paid in Thorium Bars
	local thorium = g.Item("Thorium Bar")
	g:Step(function(s)
		s.skip = "skill " .. BS .. " >= 245"
		s:Goto(1446, 51.38, 28.67)
		s:Talk(g.Npc("Derotain Mudsipper", 14567))
		s:Do("Do his Imperial Plate quests for the plans: Belt (20 ", thorium, "), Bracer (20), Boots (40) and Leggings (60).")
		s:Note("Needs level 50. Forever lowered these recipes from 265 to 240; the site thinks the quests were lowered too, but hasn't checked.")
		s:Note("If they still need 265: 15 Ebon Shiv to 255 and 15 Ornate Thorium Handaxe to 270, plans from Magnus Frostwake in Western Plaguelands (68.1, 77.6).")
		s:Note("Bring at least 250 Thorium Bars: 140 for the quests, the rest for the first crafts.")
	end)
	Craft(245, 5, g.Item("Imperial Plate Belt"), function(s)
		s:Note("110 ", thorium, ", 30 ", g.Item("Rugged Leather"), " and 5 ", g.Item("Aquamarine"), " in all.")
	end)
	Craft(270, 27, g.Item("Imperial Plate Bracers"), function(s)
		s:Note("540 ", thorium, " and 27 ", g.Item("Star Ruby"), " in all.")
	end)
	Craft(290, 20, g.Item("Imperial Plate Boots"), function(s)
		s:Note("680 ", thorium, ", 20 ", g.Item("Star Ruby"), " and 20 ", g.Item("Aquamarine"), " in all.")
	end)
	Craft(300, 10, g.Item("Imperial Plate Leggings"), function(s)
		s:Note("440 ", thorium, " and 20 ", g.Item("Star Ruby"), " in all.")
	end)
end)
