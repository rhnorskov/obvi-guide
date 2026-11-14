-- Upper Blackrock Spire (55-60), one guide for each faction: the quests for the dungeon. Egg Freezing and Egg
-- Collection for Tinkee Steamboil, Blackhand's Command (the Mark of Drakkisath), The Matron Protectorate from Awbee,
-- Eye of the Emberseer for Duke Hydraxis, Pip Quickwit's quest from The Beast, and General Drakkisath's Demise with
-- Doomrigger's Clasp (Alliance) or For The Horde! (Horde). Egg Collection needs a second run. For those on their
-- chains only: the parts of the Onyxia's Lair chains done here, Drakefire Amulet (Alliance; the chain starts with
-- Jail Break! in Blackrock Depths) or Oculus Illusions and Blood of the Black Dragon Champion (Horde; it starts with
-- Thrall after For The Horde!), and The Demon Forge for blacksmiths (after Lorax's Tale, in Winterspring).
-- Quest list from Attune (CixiDelmont) and DungeonJournal (Exehn); quest, NPC and item ids and positions from Attune
-- and QuestieDB's Forever data; the entrance and where things are inside from DungeonJournal. See README.md.

local STORMWIND, ORGRIMMAR, STEPPES, SEARING, AZSHARA, WINTERSPRING = 1453, 1454, 1428, 1427, 1447, 1452
local WPL, DESOLACE = 1422, 1443

---@param g ObviGuideGuideBuilder
---@param horde boolean
local function spire(g, horde)
	local tinkee   = g.Npc("Tinkee Steamboil", 10267)
	local hydraxis = g.Npc("Duke Hydraxis", 13278)
	local maxwell  = g.Npc("Marshal Maxwell", 9560)
	local mayara   = g.Npc("Mayara Brightwing", 9565)
	local thrall   = g.Npc("Thrall", 4949)
	local scope    = g.Item("Eggscilloscope Prototype", 12286)

	-- what the guide passes over until you have it
	g:Step(function(s)
		if horde then
			s.only = "not (done 6804 and done 6805) or not done 4810 or not done 4941"
		else
			s.only = "not (done 6804 and done 6805) or not done 4810"
		end
		s:Say("Some of these quests need earlier ones; the guide passes over the ones you can't take yet:")
		s:Say("Eye of the Emberseer: Duke Hydraxis's Poisoned Water and Stormers and Rumblers."):Only("not (done 6804 and done 6805)")
		s:Say("Egg Freezing: the Tinkee Steamboil chain with Felnok Steelspring in Winterspring, up to Return to Tinkee."):Only("not done 4810")
		s:Say("For The Horde!: Warlord's Command from Badlands and Eitrigg's Wisdom."):Only("Horde and not done 4941")
	end)

	-- Kalimdor first: the Eye only drops while you have its quest
	g:Step(function(s)
		s.only = "(done 6804 and done 6805) or onquest 6821 or done 6821"
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Accept(6821, "Eye of the Emberseer")
		s:Note("On the little island off the east coast of Azshara.")
	end)

	if horde then
		g:Step(function(s)
			s.only = "onquest 4941 or done 4941"
			s:Goto(ORGRIMMAR, 34.3, 39.4)
			s:Talk(g.Npc("Eitrigg", 3144))
			s:Quest(4941, 1, "Talk with Eitrigg."):Only("onquest 4941")
			s:Goto(ORGRIMMAR, 31.7, 37.8)
			s:Talk(thrall)
			s:Turnin(4941, "Eitrigg's Wisdom")
			s:Accept(4974, "For The Horde!")
			s:Note("In Grommash Hold, in the Valley of Wisdom.")
		end)
	else
		-- Stormwind: the breadcrumb to Mayara
		g:Step(function(s)
			s.only = "not onquest 4764 and not done 4764"
			s:Goto(STORMWIND, 76.9, 47.8)
			s:Talk(g.Npc("Count Remington Ridgewell", 2285))
			s:Accept(4766, "Mayara Brightwing")
			s:Note("In Stormwind Keep. Then fly to Morgan's Vigil in the Burning Steppes.")
		end)

		-- Morgan's Vigil
		g:Step(function(s)
			s:Goto(STEPPES, 84.8, 69.1)
			s:Talk(mayara)
			s:Turnin(4766, "Mayara Brightwing"):Only("onquest 4766")
			s:Accept(4764, "Doomrigger's Clasp")
			s:Note("At Morgan's Vigil, in the east of the Burning Steppes.")
		end)

		g:Step(function(s)
			local command = g.Item("General Drakkisath's Command", 12780)
			s.only = "items 12780 >= 1 or onquest 5089 or done 5089"
			s:Goto(STEPPES, 84.7, 69.0)
			s:Use(command):Only("not onquest 5089 and not done 5089")
			s:Accept(5089, "General Drakkisath's Command")
			s:Talk(maxwell)
			s:Turnin(5089, "General Drakkisath's Command")
			s:Accept(5102, "General Drakkisath's Demise")
			s:Note("General Drakkisath's Demise starts from ", command, ", which Overlord Wyrmthalak drops in Lower Blackrock Spire.")
		end)
	end

	-- Flame Crest
	g:Step(function(s)
		s.only = "done 4810 or onquest 4907"
		s:Goto(STEPPES, 65.2, 24.0)
		s:Talk(tinkee)
		s:Turnin(4907, "Tinkee Steamboil"):Only("onquest 4907")
		s:Accept(4734, "Egg Freezing")
		s:Note("At Flame Crest, in the north of the Burning Steppes.")
	end)

	-- Blackrock Mountain
	g:Step(function(s)
		local command = g.Item("Blackhand's Command", 18987)
		s.skip = "onquest 7761 or done 7761"
		s:Goto(SEARING, 34.8, 84.0)
		s:Kill(g.Mob("Scarshield Quartermaster", 9046))
		s:Collect(command)
		s:Use(command)
		s:Accept(7761, "Blackhand's Command")
		s:Note("Inside Blackrock Mountain, by the Blackrock Spire portal on the upper ledge. He drops ", command, ".")
	end)

	g:Step(function(s)
		s.skip = "ready 4734 or done 4734 or onquest 5160 or done 5160"   -- (been inside already)
		s:Goto(SEARING, 34.8, 84.0)
		s:Do("Enter Blackrock Spire with your group and go through to the sealed door of the upper part.")
	end)

	-- Horde, Oculus Illusions: only for those on the Onyxia chain
	if horde then
		g:Side("out", function(s)
			s.only = "onquest 6569"
			s:Collect(g.Item("Black Dragonspawn Eye", 16786), { count = 20, quest = 6569, objective = 1 })
			s:Note("The black dragonspawn throughout the spire drop them.")
		end)
	end

	-- only if someone skins The Beast
	g:Side("out", function(s)
		s:Talk(g.Npc("Pip Quickwit", 10776))
		s:Accept(5047, "Pip Quickwit, At Your Service!")
		s:Note("Only if someone skins The Beast (it takes Finkle's Skinner and a high Skinning skill): Pip climbs out of it.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Pyroguard Emberseer", 9816))
		s:Collect(g.Item("Eye of the Emberseer", 17322), { quest = 6821, objective = 1 }):Only("onquest 6821")
		s:Note("In the first big room past the sealed door: kill the Blackhand Incarcerators around him and he wakes.")
	end)

	g:Step(function(s)
		s.only = horde and "onquest 4734" or "onquest 4734 or onquest 4764"
		s:Use(scope):Only("onquest 4734")
		s:Quest(4734, 1, "Use the Eggscilloscope on a Rookery Egg."):Only("onquest 4734")
		s:Collect(g.Item("Doomrigger's Clasp", 12352), { quest = 4764, objective = 1 }):Only("onquest 4764")
		s:Note("In the Rookery, right after Emberseer. Don't walk up to the eggs: they hatch. Doomrigger's Coffer stands in the middle of the room, before the ramp.")
	end)

	-- The Demon Forge: only for blacksmiths on it
	g:Step(function(s)
		s.only = "onquest 5127"
		s:Kill(g.Mob("Goraluk Anvilcrack", 10899))
		s:Use(g.Item("Blood Stained Pike", 12848))
		s:Collect(g.Item("Soul Stained Pike", 12847), { quest = 5127, objective = 1 })
		s:Collect(g.Item("Unforged Rune Covered Breastplate", 12806), { quest = 5127, objective = 2 })
		s:Note("The Dark Horde blacksmith, after the Rookery on the way to the stadium. Use the pike on his corpse; the breastplate lies nearby.")
	end)

	if horde then
		g:Step(function(s)
			s.only = "onquest 4974"
			s:Kill(g.Mob("Warchief Rend Blackhand", 10429))
			s:Collect(g.Item("Head of Rend Blackhand", 12630), { quest = 4974, objective = 1 })
			s:Note("Jump down into the stadium from the Hall of Blackhand: waves of orcs and dragons, then Gyth and Rend.")
		end)
	end

	g:Step(function(s)
		s:Talk(g.Npc("Awbee", 10740))
		s:Accept(5160, "The Matron Protectorate")
		s:Note("On the ledge just past the door out of the stadium, after Gyth and Warchief Rend Blackhand.")
	end)

	g:Step(function(s)
		local blood = g.Item("Blood of the Black Dragon Champion", 16663)
		s.only = "onquest 5102 or onquest 7761 or onquest 6502 or onquest 6602"
		s:Kill(g.Mob("General Drakkisath", 10363), { quest = 5102, objective = 1 }):Only("onquest 5102")
		s:Turnin(7761, "Blackhand's Command"):Only("onquest 7761")
		s:Note("The last boss, past The Beast. After the fight, click Drakkisath's Brand behind him for the Mark of Drakkisath.")
		if horde then
			s:Collect(blood, { quest = 6602, objective = 1 }):Only("onquest 6602")
		else
			s:Collect(blood, { quest = 6502, objective = 1 }):Only("onquest 6502")
		end
		s:Note("He drops his blood for the Onyxia's Lair chain.")
	end)

	-- out: the Burning Steppes, and back in for the eggs
	if not horde then
		g:Step(function(s)
			s.label = "out"
			s.only = "ready 4764 or ready 5102"
			s:Goto(STEPPES, 84.8, 69.1)
			s:Talk(mayara)
			s:Turnin(4764, "Doomrigger's Clasp"):Only("ready 4764")
			s:Talk(maxwell)
			s:Turnin(5102, "General Drakkisath's Demise"):Only("ready 5102")
		end)
	end

	g:Step(function(s)
		if horde then s.label = "out" end
		s.only = "ready 4734 or done 4734"
		s:Goto(STEPPES, 65.2, 24.0)
		s:Talk(tinkee)
		s:Turnin(4734, "Egg Freezing")
		s:Accept(4735, "Egg Collection")
	end)

	g:Step(function(s)
		s.only = "onquest 4735 and not ready 4735"
		s:Goto(SEARING, 34.8, 84.0)
		s:Do("Enter Blackrock Spire again with your group, up to the Rookery.")
	end)

	g:Step(function(s)
		s.only = "onquest 4735"
		s:Use(g.Item("Collectronic Module", 12287))
		s:Collect(g.Item("Collected Dragon Egg", 12241), { count = 8, quest = 4735, objective = 1 })
		s:Note("Use the module on the Rookery Eggs, right after Emberseer.")
	end)

	g:Step(function(s)
		s.only = "ready 4735"
		s:Goto(STEPPES, 65.2, 24.0)
		s:Talk(tinkee)
		s:Turnin(4735, "Egg Collection")
	end)

	-- Horde: Oculus Illusions, on the Onyxia chain
	if horde then
		g:Step(function(s)
			s.only = "ready 6569"
			s:Goto(WPL, 50.8, 77.8)
			s:Talk(g.Npc("Myranda the Hag", 11872))
			s:Turnin(6569, "Oculus Illusions")
			s:Note("On Sorrow Hill, in the south of Western Plaguelands. Her next quest, Emberstrife, goes on towards Onyxia's Lair.")
		end)
	end

	-- Kalimdor: Everlook and Azshara (and Orgrimmar)
	g:Step(function(s)
		s.only = "onquest 5047"
		s:Goto(WINTERSPRING, 61.0, 38.8)
		s:Talk(g.Npc("Malyfous Darkhammer", 10637))
		s:Turnin(5047, "Pip Quickwit, At Your Service!")
		s:Note("In Everlook.")
	end)

	g:Step(function(s)
		s.only = horde and "onquest 5160" or "onquest 5160 or ready 6502"
		s:Goto(WINTERSPRING, 54.5, 51.2)
		s:Talk(g.Npc("Haleh", 10929))
		s:Note("At the top of Mazthoril, south-west of Everlook: through the cave and up to the open ledge.")
		s:Turnin(5160, "The Matron Protectorate"):Only("onquest 5160")
		if not horde then
			s:Turnin(6502, "Drakefire Amulet"):Only("ready 6502")
			s:Note("The end of the Alliance chain to Onyxia's Lair, which starts with Jail Break! in Blackrock Depths.")
		end
	end)

	g:Step(function(s)
		s.only = "ready 5127"
		s:Goto(WINTERSPRING, 63.8, 73.8)
		s:Talk(g.Npc("Lorax", 10918))
		s:Turnin(5127, "The Demon Forge")
		s:Note("In the south of Winterspring. The Demon Forge comes from him after Lorax's Tale (Blacksmithing 270).")
	end)

	if horde then
		g:Step(function(s)
			s.only = "ready 4974"
			s:Goto(ORGRIMMAR, 31.7, 37.8)
			s:Talk(thrall)
			s:Turnin(4974, "For The Horde!")
			s:Note("In Grommash Hold. His next quest, What the Wind Carries, starts the road to Onyxia's Lair; this guide picks it up again at Oculus Illusions.")
		end)
	end

	g:Step(function(s)
		s.only = "ready 6821"
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6821, "Eye of the Emberseer")
	end)

	-- Horde: the end of the Onyxia chain
	if horde then
		g:Step(function(s)
			s.only = "ready 6602"
			s:Goto(DESOLACE, 54.0, 3.2)
			s:Talk(g.Npc("Rexxar", 10182))
			s:Turnin(6602, "Blood of the Black Dragon Champion")
			s:Note("He walks the roads of Desolace between the Stonetalon Mountains and Feralas. The end of the Horde chain to Onyxia's Lair, which starts with Thrall once For The Horde! is handed in.")
		end)
	end
end

ObviGuide.Guide(function(g)
	g.title = "Upper Blackrock Spire: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-upper-blackrock-spire"
	g.next  = "obvi-scholomance"
	g.only  = "Alliance"
	spire(g, false)
end)

ObviGuide.Guide(function(g)
	g.title = "Upper Blackrock Spire: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-upper-blackrock-spire-horde"
	g.next  = "obvi-scholomance-horde"
	g.only  = "Horde"
	spire(g, true)
end)
