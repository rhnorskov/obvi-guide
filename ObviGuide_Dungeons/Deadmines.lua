-- The Deadmines quests (Alliance): The Defias Brotherhood chain from Sentinel Hill to VanCleef, Red Silk Bandanas,
-- Oh Brother... and Collecting Memories, Underground Assault, Alba Fairmoon's chain up to Destruction in Deadmines,
-- and The Unsent Letter that VanCleef carries. Quest, NPC and item ids and positions from QuestieDB's Forever data,
-- the order of Alba's chain from Attune (CixiDelmont). See README.md.

local STORMWIND, WESTFALL, REDRIDGE = 1453, 1436, 1433

ObviGuide.Guide(function(g)
	g.title = "The Deadmines: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-deadmines"
	g.next  = "obvi-wailing-caverns"
	g.only  = "Alliance"

	local wilder = g.Npc("Wilder Thistlenettle", 656)
	local shoni  = g.Npc("Shoni the Shilent", 6579)
	local gryan  = g.Npc("Gryan Stoutmantle", 234)
	local riell  = g.Npc("Scout Riell", 820)
	local alba   = g.Npc("Alba Fairmoon", 253092)
	local sprite = g.Npc("Sprite Jumpsprocket", 11026)

	-- Stormwind: the two quests from the Dwarven District, and the gnome's
	g:Step(function(s)
		s:Goto(STORMWIND, 70.3, 40.8)
		s:Talk(wilder)
		s:Accept(167, "Oh Brother...")
		s:Accept(168, "Collecting Memories")
		s:Note("Inside the building.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 62.6, 34.1)
		s:Talk(shoni)
		s:Accept(2040, "Underground Assault")
	end)

	-- Alba Fairmoon's chain (the Toxic Soil storyline), which ends in Destruction in Deadmines; it starts at level 9,
	-- so it comes before the Defias Brotherhood (level 14)
	g:Step(function(s)
		s:Goto(WESTFALL, 52.5, 53.0)
		s:Talk(alba)
		s:Accept(92742, "Testing the Wells")
		s:Accept(92744, "Murloc Gills")
		s:Note("Just south-west of Sentinel Hill.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 46.1, 38.2)
		s:Use(g.Item("Well Water Sample Kit", 254545))
		s:Collect(g.Item("Molsen Farm Water Sample", 254547), { quest = 92742, objective = 2 })
		s:Note("At the well of the Molsen Farm.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.6, 18.6)
		s:Use(g.Item("Well Water Sample Kit", 254545))
		s:Collect(g.Item("Jansen Stead Water Sample", 254546), { quest = 92742, objective = 1 })
		s:Note("At the well of the Jansen Stead.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 54.4, 9.3)
		s:Kill(g.Mob("Murloc Raider", 515))
		s:Kill(g.Mob("Murloc Coastrunner", 126))
		s:Collect(g.Item("Longshore Murloc Gill", 254548), { count = 7, quest = 92744, objective = 1 })
		s:Note("Along the north coast.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 52.5, 53.0)
		s:Talk(alba)
		s:Turnin(92742, "Testing the Wells")
		s:Turnin(92744, "Murloc Gills")
		s:Accept(92745, "The State of the Mines")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 44.8, 21.0)
		s:Kill(g.Mob("Kobold Digger", 1236), { quest = 92745, objective = 1 })
		s:Note("In the Jangolode Mine.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 30.0, 46.5)
		s:Kill(g.Mob("Riverpaw Miner", 1426), { quest = 92745, objective = 2 })
		s:Note("In the Gold Coast Quarry.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 52.5, 53.0)
		s:Talk(alba)
		s:Turnin(92745, "The State of the Mines")
		s:Accept(92747, "Moonbrook Espionage")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 43.4, 68.8)
		s:Collect(g.Item("Suspicious Industrial Supplies", 254676), { count = 8, quest = 92747, objective = 1 })
		s:Note("From the Suspicious Crates around Moonbrook.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 52.5, 53.0)
		s:Talk(alba)
		s:Turnin(92747, "Moonbrook Espionage")
		s:Accept(92748, "Explosive Consultation")
	end)

	-- The Defias Brotherhood: back and forth between Sentinel Hill, Lakeshire and Stormwind
	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Accept(65, "The Defias Brotherhood")
		s:Note("At Sentinel Hill. Then fly to Stormwind: Alba's engineer is there, and Redridge is on from it.")
	end)

	-- Stormwind on the way to Redridge: Explosive Consultation
	g:Step(function(s)
		s:Goto(STORMWIND, 61.9, 30.6)
		s:Talk(sprite)
		s:Turnin(92748, "Explosive Consultation")
		s:Accept(92749, "A Dynamite Plan")
		s:Accept(92750, "Detonation at a Distance")
		s:Note("In the Dwarven District. Get the 10 dynamite before you're back in Stormwind.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 80.3, 70.1)
		s:Talk(g.Npc("Jasper Fel", 1325))
		s:Turnin(92750, "Detonation at a Distance")
		s:Accept(92751, "Detonation at a Distance")
		s:Note("In Old Town, near SI:7.")
	end)

	-- Redridge, then fly back to Sentinel Hill from Lakeshire
	g:Step(function(s)
		s:Goto(REDRIDGE, 21.4, 45.4)
		s:Talk(g.Npc("Wiley the Black", 266))
		s:Turnin(65, "The Defias Brotherhood")
		s:Accept(132, "The Defias Brotherhood")
		s:Note("Upstairs in the Lakeshire inn. Then take the flight from Lakeshire to Sentinel Hill.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Turnin(132, "The Defias Brotherhood")
		s:Accept(135, "The Defias Brotherhood")
		s:Note("Then fly to Stormwind.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 78.3, 70.7)
		s:Talk(g.Npc("Master Mathias Shaw", 332))
		s:Turnin(135, "The Defias Brotherhood")
		s:Accept(141, "The Defias Brotherhood")
		s:Note("Upstairs in SI:7, in Old Town.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Rough Dynamite", 4358), { count = 10, quest = 92749, objective = 1 })
		s:Note("Engineers make it: craft it, buy it on the auction house or ask for it in trade.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 61.9, 30.6)
		s:Talk(sprite)
		s:Turnin(92749, "A Dynamite Plan")
		s:Turnin(92751, "Detonation at a Distance")
		s:Accept(92752, "Explosive Consultation")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Turnin(141, "The Defias Brotherhood")
		s:Accept(142, "The Defias Brotherhood")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 45.1, 69.3)
		s:Kill(g.Mob("Defias Messenger", 550))
		s:Collect(g.Item("A Mysterious Message", 1381), { quest = 142, objective = 1 })
		s:Note("He walks the road between Jangolode Mine and Moonbrook, by way of the Gold Coast Quarry.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Turnin(142, "The Defias Brotherhood")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 55.7, 47.5)
		s:Talk(g.Npc("The Defias Traitor", 467))
		s:Accept(155, "The Defias Brotherhood")
		s:Note("If he isn't here, someone is escorting him: wait for him to come back.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 42.5, 71.5)
		s:Quest(155, 1, "Follow the Defias Traitor to Moonbrook and keep him alive.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Turnin(155, "The Defias Brotherhood")
		s:Accept(166, "The Defias Brotherhood")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.7, 47.4)
		s:Talk(riell)
		s:Accept(214, "Red Silk Bandanas")
		s:Note("At the top of the tower.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 52.5, 53.0)
		s:Talk(alba)
		s:Turnin(92752, "Explosive Consultation")
		s:Accept(92753, "Destruction in Deadmines")
	end)

	-- the mine below Moonbrook, on the way to the instance: done with the group, on the way in. The cards come from the
	-- undead miners on the way to the foreman: a side task while looking for him, and a step of their own if he dies
	-- before there are four.
	local function cards(s)
		s:Kill(g.Mob("Skeletal Miner", 623))
		s:Kill(g.Mob("Undead Excavator", 624))
		s:Kill(g.Mob("Undead Dynamiter", 625))
		s:Collect(g.Item("Miners' Union Card", 1894), { count = 4, quest = 168, objective = 1 })
	end

	g:Side("foreman", cards)

	g:Step(function(s)
		s.label = "foreman"
		s:Goto(WESTFALL, 42.2, 82.6)
		s:Kill(g.Mob("Foreman Thistlenettle", 626))
		s:Collect(g.Item("Thistlenettle's Badge", 1875), { quest = 167, objective = 1 })
		s:Note("With your group, on the way to the instance: into the building in Moonbrook and down the mine. He walks the tunnels past the bridge, near the instance portal.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 41.1, 81.8)
		cards(s)
		s:Note("In the mine tunnels.")
	end)

	g:Step(function(s)
		s.skip = "ready 166 or done 166"   -- (been inside already)
		s:Do("Enter the Deadmines with your group.")
	end)

	-- inside
	g:Side("ship", function(s)
		s:Collect(g.Item("Red Silk Bandana", 915), { count = 10, quest = 214, objective = 1 })
		s:Note("The Defias inside drop them.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Sneed's Shredder", 642))
		s:Collect(g.Item("Gnoam Sprecklesprocket", 7365), { quest = 2040, objective = 1 })
		s:Note("The second boss, in the lumber mill.")
	end)

	g:Step(function(s)
		s.only = "onquest 92753 or done 92753"
		s:Use(g.Item("Extra-Destructive Explosives", 254553))
		s:Quest(92753, 1, "Plant the explosives near the forge.")
		s:Note("In the goblin foundry, where Gilnid is.")
	end)

	g:Step(function(s)
		s.label = "ship"
		s:Kill(g.Mob("Edwin VanCleef", 639))
		s:Collect(g.Item("Head of VanCleef", 3637), { quest = 166, objective = 1 })
		s:Note("The last boss, on the ship.")
	end)

	g:Step(function(s)
		local letter = g.Item("An Unsent Letter", 2874)
		s:Use(letter):Only("not onquest 373 and not done 373")
		s:Accept(373, "The Unsent Letter")
		s:Note("VanCleef drops ", letter, ": it starts the quest.")
	end)

	-- the turn-ins
	g:Step(function(s)
		s.only = "onquest 92753 or done 92753"
		s:Goto(WESTFALL, 38.7, 83.7)
		local alba = g.Npc("Alba Fairmoon", 253279)
		s:Talk(alba)
		s:Turnin(92753, "Destruction in Deadmines")
		s:Accept(92819, "Destruction in Deadmines")
		s:Quest(92819, 1, "Use the detonator.")
		s:Turnin(92819, "Destruction in Deadmines")
		s:Note("She waits by the Deadmines exit, in Moonbrook.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Turnin(166, "The Defias Brotherhood")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.7, 47.4)
		s:Talk(riell)
		s:Turnin(214, "Red Silk Bandanas")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 57.7, 47.9)
		s:Talk(g.Npc("Baros Alexston", 1646))
		s:Turnin(373, "The Unsent Letter")
		s:Note("In the Cathedral Square building. His next quest, Bazil Thredd, leads to the Stockade.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 62.6, 34.1)
		s:Talk(shoni)
		s:Turnin(2040, "Underground Assault")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 70.3, 40.8)
		s:Talk(wilder)
		s:Turnin(167, "Oh Brother...")
		s:Turnin(168, "Collecting Memories")
	end)
end)
