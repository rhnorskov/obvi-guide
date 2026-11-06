-- First Aid 1-300 (Alliance). The recipes, counts, skill ranges, rank-ups, trainers and vendors follow
-- wow-professions.com's WoW Forever First Aid guide: https://www.wow-professions.com/forever/first-aid-leveling-guide
-- (used with credit; will be removed on request). The step text is our own. The site's Artisan part (225-300) was not
-- tested on the Forever beta. NPC ids and positions come from QuestieDB's Forever data. See README.md.

local SW, IF, ARATHI, DUSTWALLOW = 1453, 1455, 1417, 1445
local FA = "First Aid"

-- who trains where: Ironforge for dwarves and gnomes, Stormwind for everyone else
local IN_IF, IN_SW = "Dwarf or Gnome", "not (Dwarf or Gnome)"

ObviGuide.Guide(function(g)
	g.title = "First Aid (1-300)"
	g.group = "Professions"
	g.id    = "obvi-first-aid"
	g.only  = "Alliance"

	local linen, wool, silk = g.Item("Linen Cloth", 2589), g.Item("Wool Cloth", 2592), g.Item("Silk Cloth", 4306)
	local mageweave, runecloth = g.Item("Mageweave Cloth", 4338), g.Item("Runecloth", 14047)

	--- A visit to your race's First Aid trainer (Stormwind, or Ironforge for dwarves and gnomes).
	---@param build fun(s: ObviGuideStepBuilder)
	local function Trainer(build)
		g:Step(function(s)
			s.only = IN_SW
			s:Goto(SW, 53.00, 44.68)
			s:Talk(g.Npc("Shaina Fuller", 2327))
			build(s)
		end)
		g:Step(function(s)
			s.only = IN_IF
			s:Goto(IF, 55.09, 58.26)
			s:Talk(g.Npc("Nissa Firestone", 5150))
			build(s)
		end)
	end

	--- Making `count` of an item, up to a skill level.
	---@param to integer
	---@param count integer
	---@param item ObviGuideMarker
	---@param notes? fun(s: ObviGuideStepBuilder)
	local function Make(to, count, item, notes)
		g:Step(function(s)
			s:Say("Make " .. count .. " ", item, ".")
			if notes then notes(s) end
			s:Skill(FA, to)
		end)
	end

	-- Apprentice (1-75)
	Trainer(function(s)
		s:Train(FA)
		s:Note("Route after wow-professions.com's WoW Forever First Aid guide, used with credit.")
		s:Note("First Aid takes no profession slot in Forever, and it makes the healing potions Alchemy made in Classic.")
		s:Note("The physicians in Goldshire (Michelle Belle) and Kharanos (Thamner Pol) teach Apprentice and Journeyman too.")
	end)
	Make(40, 50, g.Item("Linen Bandage"), function(s)
		s:Note("50 ", linen, ". Linen comes from humanoids around level 5-15, or the Auction House.")
	end)
	Make(75, 40, g.Item("Heavy Linen Bandage"), function(s)
		s:Note("80 ", linen, ". It turns yellow from 50.")
		s:Note("Or, from the potions tab: about 81 ", g.Item("Minor Healing Potion"), " (Peacebloom, Mild Spices and an Empty Vial each; spices from Cooking suppliers, vials from Alchemy suppliers).")
	end)

	-- Journeyman (75-150)
	Trainer(function(s)
		s:Train(FA, 150)
		s:Note("Needs First Aid 50.")
	end)
	Make(80, 12, g.Item("Heavy Linen Bandage"), function(s)
		s:Note("24 ", linen, ". Green now: about every second one gives a point.")
	end)
	Make(115, 50, g.Item("Wool Bandage"), function(s)
		s:Note("50 ", wool, ". The trainer teaches it at 80.")
	end)
	Make(150, 50, g.Item("Heavy Wool Bandage"), function(s)
		s:Note("100 ", wool, ". The trainer teaches it at 115.")
	end)

	-- Expert (150-225): a book, sold in Arathi Highlands
	g:Step(function(s)
		s.skip = "skill " .. FA .. " >= 151"   -- (past 150 only with the book learned)
		s:Goto(ARATHI, 26.97, 58.83)
		s:Talk(g.Npc("Deneb Walker", 2805))
		s:Do(g.Buy("Buy Expert First Aid - Under Wraps"), ", and Manual: Heavy Silk Bandage and Manual: Mageweave Bandage for later.")
		s:Note("Needs First Aid 125 to use. Use the book and the two manuals from your bags.")
	end)
	g:Step(function(s)
		s:Train(FA, 225)
		s:Note("Use Expert First Aid - Under Wraps from your bags.")
	end)
	Make(180, 42, g.Item("Silk Bandage"), function(s)
		s:Note("42 ", silk, ". Your trainer teaches it.")
	end)
	Make(210, 46, g.Item("Heavy Silk Bandage"), function(s)
		s:Note("92 ", silk, ". From Manual: Heavy Silk Bandage.")
	end)
	Make(225, 17, g.Item("Mageweave Bandage"), function(s)
		s:Note("17 ", mageweave, ". From Manual: Mageweave Bandage. Mageweave drops only from level 40+ mobs.")
		s:Note("Without Mageweave: 42 more Heavy Silk Bandages (84 ", silk, ").")
	end)

	-- Artisan (225-300): the Triage quest in Theramore
	g:Step(function(s)
		s.only = "level >= 35"
		s:Goto(DUSTWALLOW, 67.76, 48.97)
		s:Talk(g.Npc("Doctor Gustaf VanHowzen", 12939))
		s:Train(FA, 300)
		s:Note("Needs First Aid 225 and level 35. Do his Triage quest: save 15 patients with the bandages he gives, the critical ones first, and hand it in as soon as you reach 15.")
		s:Note("He also teaches Heavy Mageweave Bandage at 240 and Runecloth Bandage at 260.")
	end)
	Make(240, 16, g.Item("Superior Healing Potion"), function(s)
		s:Note("16 Sungrass, 16 Soothing Spices, 16 Crystal Vial. From Manual: Superior Healing Potion, which no vendor sells. It turns yellow at 230.")
	end)
	Make(260, 30, g.Item("Heavy Mageweave Bandage"), function(s)
		s:Note("60 ", mageweave, ". The doctor teaches it at 240.")
	end)
	Make(275, 20, g.Item("Runecloth Bandage"), function(s)
		s:Note("20 ", runecloth, ". The doctor teaches it at 260.")
	end)
	Make(300, 30, g.Item("Major Healing Potion"), function(s)
		s:Note("30 Golden Sansam, 90 Soothing Spices, 30 Crystal Vial. From Manual: Major Healing Potion, which no vendor sells.")
		s:Note("The site didn't test 225-300 on the Forever beta: it should be as in Classic.")
	end)
end)
