-- Upper Blackrock Spire (55-60), one guide for each faction: the quests Attune lists for the dungeon. Egg Freezing and
-- Egg Collection for Tinkee Steamboil, Blackhand's Command (the Mark of Drakkisath), The Matron Protectorate from
-- Awbee, Eye of the Emberseer for Duke Hydraxis, Pip Quickwit's quest from The Beast, and General Drakkisath's Demise
-- with Doomrigger's Clasp (Alliance) or For The Horde! (Horde). Egg Collection needs a second run.
-- Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance from
-- DungeonJournal (Exehn). See README.md.

local STORMWIND, ORGRIMMAR, STEPPES, SEARING, AZSHARA, WINTERSPRING = 1453, 1454, 1428, 1427, 1447, 1452

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
		s.only = "onquest 5102 or onquest 7761"
		s:Kill(g.Mob("General Drakkisath", 10363), { quest = 5102, objective = 1 }):Only("onquest 5102")
		s:Turnin(7761, "Blackhand's Command"):Only("onquest 7761")
		s:Note("The last boss, past The Beast. After the fight, click Drakkisath's Brand behind him for the Mark of Drakkisath.")
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

	-- Kalimdor: Everlook and Azshara (and Orgrimmar)
	g:Step(function(s)
		s.only = "onquest 5047"
		s:Goto(WINTERSPRING, 61.0, 38.8)
		s:Talk(g.Npc("Malyfous Darkhammer", 10637))
		s:Turnin(5047, "Pip Quickwit, At Your Service!")
		s:Note("In Everlook.")
	end)

	g:Step(function(s)
		s.only = "onquest 5160"
		s:Goto(WINTERSPRING, 54.5, 51.2)
		s:Talk(g.Npc("Haleh", 10929))
		s:Turnin(5160, "The Matron Protectorate")
		s:Note("At the top of Mazthoril, south-west of Everlook: through the cave and up to the open ledge.")
	end)

	if horde then
		g:Step(function(s)
			s.only = "ready 4974"
			s:Goto(ORGRIMMAR, 31.7, 37.8)
			s:Talk(thrall)
			s:Turnin(4974, "For The Horde!")
			s:Note("In Grommash Hold.")
		end)
	end

	g:Step(function(s)
		s.only = "ready 6821"
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6821, "Eye of the Emberseer")
	end)
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
