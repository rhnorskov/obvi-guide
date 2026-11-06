-- The Deadmines quests (Alliance): The Defias Brotherhood chain from Sentinel Hill to VanCleef, Red Silk Bandanas,
-- Oh Brother... and Collecting Memories, Underground Assault, and The Unsent Letter that VanCleef carries. Quest, NPC
-- and item ids and positions from QuestieDB's Forever data. See README.md.

local STORMWIND, WESTFALL, REDRIDGE = 1453, 1436, 1433

ObviGuide.Guide(function(g)
	g.title = "The Deadmines Quests"
	g.group = "Dungeons"
	g.id    = "obvi-deadmines"
	g.only  = "Alliance"

	local wilder = g.Npc("Wilder Thistlenettle", 656)
	local shoni  = g.Npc("Shoni the Shilent", 6579)
	local gryan  = g.Npc("Gryan Stoutmantle", 234)
	local riell  = g.Npc("Scout Riell", 820)

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

	-- The Defias Brotherhood: back and forth between Sentinel Hill, Lakeshire and Stormwind
	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Accept(65, "The Defias Brotherhood")
		s:Note("At Sentinel Hill.")
	end)

	g:Step(function(s)
		s:Goto(REDRIDGE, 21.4, 45.4)
		s:Talk(g.Npc("Wiley the Black", 266))
		s:Turnin(65, "The Defias Brotherhood")
		s:Accept(132, "The Defias Brotherhood")
		s:Note("Upstairs in the Lakeshire inn.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 56.3, 47.5)
		s:Talk(gryan)
		s:Turnin(132, "The Defias Brotherhood")
		s:Accept(135, "The Defias Brotherhood")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 78.3, 70.7)
		s:Talk(g.Npc("Master Mathias Shaw", 332))
		s:Turnin(135, "The Defias Brotherhood")
		s:Accept(141, "The Defias Brotherhood")
		s:Note("Upstairs in SI:7, in Old Town.")
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

	-- the mine below Moonbrook, on the way to the instance: done with the group, on the way in
	g:Step(function(s)
		s:Goto(WESTFALL, 42.2, 82.6)
		s:Kill(g.Mob("Foreman Thistlenettle", 626))
		s:Collect(g.Item("Thistlenettle's Badge", 1875), { quest = 167, objective = 1 })
		s:Collect(g.Item("Miners' Union Card", 1894), { count = 4, quest = 168, objective = 1 })
		s:Note("With your group, on the way to the instance: into the building in Moonbrook and down the mine. The foreman walks the tunnels past the bridge, near the instance portal; the undead miners there drop the cards.")
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
