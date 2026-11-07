-- Tome of Dalaran (both factions, 23+): summons Lyn the Ignored, a rare boss in the City of Dalaran. The Black Tome
-- lies behind Archmage Arugal in Shadowfang Keep; read it at the leyline focus in Ambermill. Ids and the order from
-- Attune (CixiDelmont) and QuestieDB's Forever data; the entrance from DungeonJournal (Exehn). See README.md.

local SILVERPINE = 1421

ObviGuide.Guide(function(g)
	g.title = "Tome of Dalaran"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-tome-of-dalaran"

	local blackTome = g.Item("Black Tome", 276561)

	g:Step(function(s)
		s.skip = "items 276561 >= 1 or items 275989 >= 1"   -- (been inside already)
		s:Goto(SILVERPINE, 44.8, 67.8)
		s:Do("Enter Shadowfang Keep with your group.")
		s:Note("The keep north of Pyrewood Village.")
	end)

	g:Step(function(s)
		s.skip = "items 275989 >= 1"   -- (read it already)
		s:Kill(g.Mob("Archmage Arugal", 4275))
		s:Collect(blackTome)
		s:Note("The last boss. The ", blackTome, " lies on the table behind him.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 63.4, 64.3)
		s:Use(blackTome)
		s:Collect(g.Item("Tome of Dalaran", 275989))
		s:Note("At the ", g.Object("Ambermill Leyline Focus"), " in Ambermill. One Tome is enough for the group to summon Lyn the Ignored.")
	end)
end)
