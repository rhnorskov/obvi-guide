-- The Hall of Thanes (Alliance, 13-15): every quest for the dungeon, from the Dark Iron Map in Dun Morogh to the
-- turn-ins with King Magni. Quest, NPC and item ids from Attune (CixiDelmont) and QuestieDB's Forever data; the way
-- down to Old Ironforge from DungeonJournal (Exehn). See README.md.

local IRONFORGE, DUN_MOROGH = 1455, 1426

ObviGuide.Guide(function(g)
	g.title = "The Hall of Thanes: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-hall-of-thanes"
	g.next  = "obvi-ruins-of-lordaeron"
	g.only  = "Alliance"

	local farsen  = g.Npc("Earthseer Farsen", 264936)
	local afadra  = g.Npc("Afadra Dunwall", 264943)
	local thom    = g.Npc("Thom Filch", 265003)
	local ghost   = g.Npc("Ghostly Attendant", 265002)
	local magni   = g.Npc("King Magni Bronzebeard", 2784)
	local map     = g.Item("Dark Iron Map", 274268)
	local treaty  = g.Item("Treaty of Understanding", 281030)

	-- Old Ironforge Incursion needs Underground Map first, which starts from a drop in Dun Morogh
	g:Step(function(s)
		s.skip = "onquest 96391 or done 96391 or onquest 96393 or done 96393"
		s:Goto(DUN_MOROGH, 77.4, 61.3)
		s:Kill(g.Mob("Dark Iron Spy", 6123))
		s:Note("Until one drops a ", map, ".")
		s:Use(map)
		s:Accept(96391, "Underground Map")
	end)

	g:Step(function(s)
		s:Goto(DUN_MOROGH, 64.9, 58.5)
		s:Talk(farsen)
		s:Turnin(96391, "Underground Map")
		s:Accept(96393, "Old Ironforge Incursion")
	end)

	-- Old Ironforge lies under the city: from the High Seat, down the cobwebbed corridor and the stairs below it
	g:Step(function(s)
		s:Path(IRONFORGE, 43.5, 52.0)
		s:Goto(IRONFORGE, 32.8, 47.8)
		s:Note("Take the cobwebbed corridor on the left as you walk into the High Seat, and follow the stairs down.")
		s:Talk(afadra)
		s:Accept(96394, "The Restless Dead")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 32.2, 44.9)
		s:Talk(thom)
		s:Accept(96403, "Important Heirlooms")
		s:Note("He stands on the bridge over the lava, by the dungeon portal.")
	end)

	g:Step(function(s)
		s.skip = "ready 96393 or done 96393"   -- (been inside already)
		s:Do("Enter the Hall of Thanes through the portal next to ", thom, ".")
	end)

	-- inside: the trash and heirlooms are done along the way, up to the last boss
	g:Side("Durgen", function(s)
		s:Kill(g.Mob("Enraged Apparition", 263389), { quest = 96394, objective = 1 })
		s:Kill(g.Mob("Tormented Soul", 263390), { quest = 96394, objective = 2 })
		s:Collect(g.Item("Dwarven Heirloom", 274289), { count = 8, quest = 96403, objective = 1 })
		s:Note("Click the ", g.Object("Dwarven Heirloom"), " objects along the halls.")
	end)

	g:Step(function(s)
		s:Talk(ghost)
		s:Accept(96395, "An Ancient Grudge")
		s:Note("Past the first room.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Faldrim Anvilmar", 261306), { quest = 96395, objective = 1 })
		s:Note("He walks Anvilmar's Rest. Putting him to rest also counts for The Restless Dead.")
	end)

	g:Step(function(s)
		s:Talk(ghost)
		s:Turnin(96395, "An Ancient Grudge")
	end)

	g:Step(function(s)
		s.label = "Durgen"
		s:Kill(g.Mob("Durgen Dirgehammer", 261319))
		s:Collect(g.Item("Durgen Dirgehammer's Head", 274286), { quest = 96393, objective = 1 })
		s:Note("The last boss, in the Reliquary of Kings.")
	end)

	g:Step(function(s)
		s:Say("Open the vaults in the Reliquary of Kings and click the ", g.Object("Treaty of Understanding"), " tablet.")
		s:Use(treaty):Only("not onquest 98423 and not done 98423")
		s:Accept(98423, "The Treaty of Understanding")
		s:Note(g.Warn("Get it before you leave the dungeon."))
	end)

	-- back out through the portal: Thom on the bridge, Afadra above him, then up to the High Seat
	g:Step(function(s)
		s:Goto(IRONFORGE, 32.2, 44.9)
		s:Talk(thom)
		s:Turnin(96403, "Important Heirlooms")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 32.8, 47.8)
		s:Talk(afadra)
		s:Turnin(96394, "The Restless Dead")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 39.1, 56.2)
		s:Talk(magni)
		s:Turnin(96393, "Old Ironforge Incursion")
		s:Turnin(98423, "The Treaty of Understanding")
	end)
end)
