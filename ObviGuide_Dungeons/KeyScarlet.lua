-- The Scarlet Key (both factions, 25+): opens the Scarlet Monastery Armory and Cathedral, from Arcanist Doan's
-- strongbox at the end of the Library. Ids from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance from
-- DungeonJournal (Exehn). See README.md.

local TIRISFAL = 1420

ObviGuide.Guide(function(g)
	g.title = "The Scarlet Key"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-scarlet"

	g:Step(function(s)
		s.skip = "items 7146 >= 1"   -- (got it already)
		s:Goto(TIRISFAL, 82.6, 33.8)
		s:Do("Enter the Scarlet Monastery Library with your group.")
		s:Note("In the monastery courtyard in north-east Tirisfal; the Library has its own door.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Arcanist Doan", 6487))
		s:Say("Open ", g.Object("Doan's Strongbox"), " behind him.")
		s:Collect(g.Item("The Scarlet Key", 7146))
		s:Note("Doan is the last boss of the Library. The key opens the Armory and the Cathedral; only one person in the group needs it.")
	end)
end)
