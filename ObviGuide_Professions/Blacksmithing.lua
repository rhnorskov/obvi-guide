-- Blacksmithing 1-300 (Alliance). The recipes, counts, skill ranges, trainers and vendors follow wow-professions.com's
-- WoW Forever Blacksmithing guide: https://www.wow-professions.com/forever/blacksmithing-leveling-guide (used with
-- credit; will be removed on request). The step text is our own. The site's 225-300 part is untested (it goes by the
-- game's data). Trainer and vendor ids and positions come from QuestieDB's Forever data; the recipes' spells, the
-- skill each is learned at and the plans that teach them from WhatsTraining's Forever recipe list; the Imperial Plate
-- quests from Zygor's Forever guide. See README.md.
--
-- Where this differs from the site: its "Mithril Plate Pants" (185-215, 12 Mithril Bar each) is Mithril Scale Pants;
-- and Imperial Plate Leggings are learned at 300 in the game's data, so 270-300 is Imperial Plate Boots all the way.

local SW, IF, STV, TAN = 1453, 1455, 1434, 1446
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
	local denseStone     = g.Item("Dense Stone", 12365)
	local copperBar      = g.Item("Copper Bar", 2840)
	local bronzeBar      = g.Item("Bronze Bar", 2841)
	local ironBar        = g.Item("Iron Bar", 3575)
	local steelBar       = g.Item("Steel Bar", 3859)
	local mithrilBar     = g.Item("Mithril Bar", 3860)
	local thorium        = g.Item("Thorium Bar", 12359)
	local leather        = g.Item("Medium Leather", 2319)
	local thickLeather   = g.Item("Thick Leather", 4304)
	local ruggedLeather  = g.Item("Rugged Leather", 8170)
	local starRuby       = g.Item("Star Ruby", 7910)
	local aquamarine     = g.Item("Aquamarine", 7909)
	local weakFlux       = g.Item("Weak Flux", 2880)
	local strongFlux     = g.Item("Strong Flux", 3466)
	local greenDye       = g.Item("Green Dye", 2605)
	local hammer         = g.Item("Blacksmith Hammer", 5956)

	-- the recipes: the spell (a recipe you've learned is a spell you know), the item it makes, and for one taught by
	-- plans, the plans' item
	local RECIPES = {
		["Rough Sharpening Stone"] = { 2660, 2862 }, ["Rough Grinding Stone"] = { 3320, 3470 },
		["Coarse Grinding Stone"] = { 3326, 3478 }, ["Runed Copper Gauntlets"] = { 3323, 3472 },
		["Runed Copper Belt"] = { 2666, 2857 }, ["Silver Rod"] = { 7818, 6338 },
		["Patterned Bronze Bracers"] = { 2672, 2868 }, ["Heavy Grinding Stone"] = { 3337, 3486 },
		["Bronze Shortsword"] = { 2742, 2850 }, ["Bronze Warhammer"] = { 9985, 7956 },
		["Green Iron Bracers"] = { 3501, 3835 }, ["Golden Scale Bracers"] = { 7223, 6040 },
		["Mithril Scale Pants"] = { 9931, 7920 }, ["Heavy Mithril Breastplate"] = { 9959, 7930 },
		["Dense Sharpening Stone"] = { 16641, 12404 },
		["Heavy Mithril Boots"] = { 9968, 7933 }, ["Imperial Plate Belt"] = { 16647, 12424, 12688 },
		["Imperial Plate Bracers"] = { 16649, 12425, 12690 }, ["Imperial Plate Boots"] = { 16657, 12426, 12700 },
	}
	---@param name string
	local function Made(name) return g.Item(name, RECIPES[name][2]) end
	local roughGrinding, coarseGrinding = Made("Rough Grinding Stone"), Made("Coarse Grinding Stone")
	local heavyGrinding = Made("Heavy Grinding Stone")

	--- Learning a recipe: from the trainer the step goes to, or for one taught by plans, by using them (click the
	--- line). Ticked off once you know it.
	---@param s ObviGuideStepBuilder
	---@param name string
	---@return ObviGuideLine
	local function Learn(s, name)
		local r = RECIPES[name]
		if r[3] then return s:Use(g.Item("Plans: " .. name, r[3])):Done("knows " .. r[1]) end
		return s:Learn(g.Spell(name, r[1]))
	end

	---@class BSPlace
	---@field npc ObviGuideMarker
	---@field x number
	---@field y number
	---@field map? integer  (the city for your race's when not given)

	--- A step at an NPC: the one in your race's city (`sw` in Stormwind, `ir` in Ironforge), or one place for everyone.
	---@param at BSPlace|{sw: BSPlace, ir: BSPlace}
	---@param build fun(s: ObviGuideStepBuilder)
	local function At(at, build)
		local places = at.sw and { { IN_SW, SW, at.sw }, { IN_IF, IF, at.ir } } or { { nil, at.map, at } }
		for _, p in ipairs(places) do
			g:Step(function(s)
				s.only = p[1]
				s:Goto(p[3].map or p[2], p[3].x, p[3].y)
				s:Talk(p[3].npc)
				build(s)
			end)
		end
	end
	-- the recipe trainers, each with an anvil beside them: your city's up to 150, Bengus Deepforge in Ironforge for
	-- everyone from 150 (Expert), Brikk Keencraft in Booty Bay from 215 (Artisan)
	local TRAINER = { sw = { npc = g.Npc("Therum Deepforge", 5511), x = 63.66, y = 37.01 },
		ir = { npc = g.Npc("Rotgath Stonebeard", 10276), x = 52.36, y = 42.55 } }
	local BENGUS = { npc = g.Npc("Bengus Deepforge", 4258), map = IF, x = 52.55, y = 41.46 }
	local BRIKK = { npc = g.Npc("Brikk Keencraft", 2836), map = STV, x = 28.99, y = 75.56 }
	-- the supply vendors (hammer, flux) stand next to the trainers
	local SUPPLY = { sw = { npc = g.Npc("Kaita Deepforge", 5512), x = 63.26, y = 37.74 },
		ir = { npc = g.Npc("Thurgrum Deepforge", 4259), x = 51.74, y = 42.78 } }

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

	---@class BSCraft
	---@field at? BSPlace|{sw: BSPlace, ir: BSPlace}  the trainer to learn the recipe from (none: you know it already)
	---@field learn? string[]  more recipes to learn there, for later on
	---@field notes? fun(s: ObviGuideStepBuilder)

	--- Crafting up to a skill level, at an anvil. With `at`, at that trainer's anvil, learning the recipe there first;
	--- a recipe taught by plans is learned from them, wherever you are.
	---@param to integer
	---@param count integer|string
	---@param name string
	---@param o? BSCraft
	local function Craft(to, count, name, o)
		o = o or {}
		local function build(s)
			s.skip = "skill " .. BS .. " >= " .. to
			if o.at or RECIPES[name][3] then Learn(s, name) end
			for _, other in ipairs(o.learn or {}) do Learn(s, other) end
			s:Say("Make " .. count .. " ", Made(name), o.at and " at the anvil here." or " at an anvil.")
			if o.notes then o.notes(s) end
			s:Skill(BS, to)
		end
		if o.at then At(o.at, build) else g:Step(build) end
	end

	-- Apprentice (1-75)
	At({ sw = { npc = g.Npc("Dane Lindgren", 957), x = 64.12, y = 37.02 },
		ir = { npc = g.Npc("Groum Stonebeard", 10277), x = 52.26, y = 41.94 } }, function(s)
		s:Train(BS)
		s:Note("Route after wow-professions.com's WoW Forever Blacksmithing guide, used with credit.")
		s:Note("You know Rough Sharpening Stone from the start; each recipe after it is learned when you get to it.")
		s:Note("Blacksmithing eats a lot of ore: it goes well with Mining.")
	end)
	At(SUPPLY, function(s)
		s:Do(g.Buy("Buy a "), hammer, "."):Done("items 5956 >= 1")
		s:Note("Keep it in your bags: most recipes need it, and from 67 on all of them.")
	end)

	Materials(25, { { roughStone, 30 } }, function(s)
		s:Note("Rough Stone comes from Copper Veins, or the Auction House.")
	end)
	Craft(25, 30, "Rough Sharpening Stone", { notes = function(s)
		s:Note("Anvils stand by the trainers in Stormwind's and Ironforge's forges, and in most towns.")
	end })

	Materials(50, { { roughStone, 60 } })
	Craft(50, 30, "Rough Grinding Stone", { at = TRAINER, notes = function(s)
		s:Note("Keep 26: 16 for the gauntlets at 67, and 10 if you make Silver Rods at 75.")
	end })

	Materials(67, { { coarseStone, 72 } }, function(s)
		s:Note("Coarse Stone comes from Tin Veins, or the Auction House.")
	end)
	Craft(67, 36, "Coarse Grinding Stone", { at = TRAINER, notes = function(s)
		s:Note("Keep all 36, for the bronze bracers at 95 and 112.")
	end })

	Materials(75, { { copperBar, 64 }, { roughGrinding, 16 } })
	Craft(75, 8, "Runed Copper Gauntlets", { at = TRAINER })

	-- Journeyman (75-150)
	At(TRAINER, function(s)
		s:Train(BS, 150)
		s:Note("Needs Blacksmithing 50 and level 10.")
	end)

	-- no materials step here: the site gives a choice
	Craft(80, 5, "Runed Copper Belt", { at = TRAINER, notes = function(s)
		s:Note("50 ", copperBar, " in all.")
		s:Note("Or 5 ", Made("Silver Rod"), " (learn it here too: 1 Silver Bar and 2 ", roughGrinding,
			" each), if Silver Bars cost less than 10 Copper Bars.")
	end })

	Materials(95, { { copperBar, 180 } })
	Craft(95, 18, "Runed Copper Belt")

	Materials(100, { { bronzeBar, 25 }, { coarseGrinding, 10 } }, function(s)
		s:Note("Smelt Bronze from Copper and Tin Bars (Mining), or buy it.")
	end)
	Craft(100, 5, "Patterned Bronze Bracers", { at = TRAINER })

	Materials(112, { { heavyStone, 60 } }, function(s)
		s:Note("Heavy Stone comes from Iron Deposits, or the Auction House.")
	end)
	Craft(112, 20, "Heavy Grinding Stone", { at = TRAINER, notes = function(s)
		s:Note("Keep all 20 for the Golden Scale Bracers at 175.")
	end })

	Materials(125, { { bronzeBar, 65 }, { coarseGrinding, 26 } })
	Craft(125, 13, "Patterned Bronze Bracers")

	-- the flux for 125-165 in one go
	At(SUPPLY, function(s)
		s.skip = "skill " .. BS .. " >= 140"
		s:Do(g.Buy("Buy 96 "), weakFlux, ", for 125-140."):Done("items 2880 >= 96")
		s:Do(g.Buy("Buy 29 "), strongFlux, ", for 140-165."):Done("items 3466 >= 29")
	end)

	Materials(140, { { bronzeBar, 120 }, { weakFlux, 96 }, { leather, 48 } })
	Craft(140, 24, "Bronze Shortsword", { at = TRAINER })

	Materials(150, { { bronzeBar, 80 }, { strongFlux, 10 }, { leather, 10 } })
	Craft(150, 10, "Bronze Warhammer", { at = TRAINER })

	-- Expert (150-215): the trainer is in Ironforge for everyone
	At(BENGUS, function(s)
		s:Train(BS, 225)
		s:Note("Needs Blacksmithing 125, level 20 and 50 silver.")
	end)

	Materials(165, { { bronzeBar, 152 }, { strongFlux, 19 }, { leather, 19 } })
	Craft(165, 19, "Bronze Warhammer")

	At({ npc = g.Npc("Bombus Finespindle", 5128), map = IF, x = 39.62, y = 34.49 }, function(s)
		s.skip = "skill " .. BS .. " >= 175"
		s:Do(g.Buy("Buy 15 "), greenDye, "."):Done("items 2605 >= 15")
	end)
	Materials(175, { { ironBar, 90 }, { greenDye, 15 } })
	Craft(175, 15, "Green Iron Bracers", { at = BENGUS })

	Materials(185, { { steelBar, 50 }, { heavyGrinding, 20 } }, function(s)
		s:Note("With Mining 165 you can smelt Steel yourself: 1 ", ironBar, " and 1 ", g.Item("Coal", 3857),
			" each (Coal from a trade supplier).")
	end)
	Craft(185, 10, "Golden Scale Bracers", { at = BENGUS })

	-- no materials step here: the site gives a cheaper choice when Mithril is dear
	Craft(215, 36, "Mithril Scale Pants", { at = BENGUS, notes = function(s)
		s:Note("432 ", mithrilBar, " in all (12 each).")
		s:Note("If Mithril is dear: 15 Steel Breastplate to 200 (240 Steel Bar, 45 Heavy Grinding Stone), then 17 Steel",
			" Plate Helm to 215 (238 Steel Bar, 17 Solid Grinding Stone). Bengus teaches both.")
	end })

	-- Artisan (215-300)
	At(BRIKK, function(s)
		s:Train(BS, 300)
		s:Note("Needs Blacksmithing 200 and level 35. Brikk is in Booty Bay and trains both factions.")
	end)

	Materials(225, { { mithrilBar, 160 } }, function(s)
		s:Note("Or, if you find ", g.Item("Plans: Mithril Spurs", 7989), " (a world drop), 10 Mithril Spurs instead: 40 ",
			mithrilBar, " and 30 Solid Grinding Stone.")
	end)
	Craft(225, 10, "Heavy Mithril Breastplate", { at = BRIKK, learn = { "Heavy Mithril Boots" } })

	-- 225-300: the site hasn't tested this part (it couldn't get past 225 on the beta); it goes by the game's data
	Materials(230, { { denseStone, 5 } })
	Craft(230, 5, "Dense Sharpening Stone", { at = BRIKK, notes = function(s)
		s:Note("The site didn't test 225-300 in Forever: expect changes.")
	end })

	Materials(240, { { mithrilBar, 224 }, { thickLeather, 64 } })
	Craft(240, 16, "Heavy Mithril Boots")

	-- the Imperial Plate plans: Thorium Brotherhood quests in Gadgetzan, each paid in Thorium Bars
	local DEROTAIN = { npc = g.Npc("Derotain Mudsipper", 14567), map = TAN, x = 51.38, y = 28.67 }
	local BELT, BRACER, BOOTS = 7653, 7655, 7654
	-- a piece's quest only while you still need its plans (below the end of its range, or with the quest taken)
	local NEED_BELT = ("skill %s < 245 or onquest %d"):format(BS, BELT)
	local NEED_BRACER = ("skill %s < 270 or onquest %d"):format(BS, BRACER)
	local ALL_DONE = ("done %d and done %d and done %d"):format(BELT, BRACER, BOOTS)
	At(DEROTAIN, function(s)
		s.skip = ALL_DONE
		s:Level(50)
		s:Accept(7652, "A Blue Light Bargain")
		s:Accept(BELT, "Imperial Plate Belt"):Only(NEED_BELT)
		s:Accept(BRACER, "Imperial Plate Bracer"):Only(NEED_BRACER)
		s:Accept(BOOTS, "Imperial Plate Boots")
		s:Note("Each pays you the plans for its piece, for Thorium Bars.")
	end)
	g:Step(function(s)
		s.skip = ALL_DONE
		s:Collect(thorium, { count = 80 })
		s:Note("20 for the belt, 20 for the bracers and 40 for the boots.")
	end)
	At(DEROTAIN, function(s)
		s:Turnin(BELT, "Imperial Plate Belt"):Only(NEED_BELT)
		s:Turnin(BRACER, "Imperial Plate Bracer"):Only(NEED_BRACER)
		s:Turnin(BOOTS, "Imperial Plate Boots")
	end)

	Materials(245, { { thorium, 110 }, { ruggedLeather, 30 }, { aquamarine, 5 } })
	Craft(245, 5, "Imperial Plate Belt")

	Materials(270, { { thorium, 540 }, { starRuby, 27 } })
	Craft(270, 27, "Imperial Plate Bracers")

	Materials(300, { { thorium, 1020 }, { starRuby, 30 }, { aquamarine, 30 } }, function(s)
		s:Note("For about 30 boots: 34 ", thorium, ", a ", starRuby, " and an ", aquamarine, " each.")
	end)
	Craft(300, "about 30", "Imperial Plate Boots", { notes = function(s)
		s:Note("The site makes Imperial Plate Leggings from 290, but the game's data has them learned at 300.")
	end })
end)
