-- Shadowfang Keep (Horde, 16-27): the three quests Attune lists for the Horde: The Book of Ur from the Undercity, and
-- Arugal Must Die and Deathstalkers in Shadowfang from the Sepulcher. Quest, NPC and item ids and positions from Attune
-- (CixiDelmont) and QuestieDB's Forever data; the entrance and where things are inside from DungeonJournal (Exehn).

local UNDERCITY, SILVERPINE = 1458, 1421

ObviGuide.Guide(function(g)
	g.title = "Shadowfang Keep: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-shadowfang-keep-horde"
	g.next  = "obvi-excavation-site-horde"
	g.only  = "Horde"

	local beldugur = g.Npc("Keeper Bel'dugur", 2934)
	local dalar    = g.Npc("Dalar Dawnweaver", 1938)

	-- the Undercity, then the Sepulcher on the way south
	g:Step(function(s)
		s:Goto(UNDERCITY, 53.7, 54.5)
		s:Talk(beldugur)
		s:Accept(1013, "The Book of Ur")
		s:Note("In the Apothecarium.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 44.2, 39.8)
		s:Talk(dalar)
		s:Accept(1014, "Arugal Must Die")
		s:Note("At the Sepulcher. This one and the next need level 18.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 43.4, 40.9)
		s:Talk(g.Npc("High Executor Hadrec", 1952))
		s:Accept(1098, "Deathstalkers in Shadowfang")
		s:Note("Inside the crypt; the door is at 43.1, 41.4.")
	end)

	g:Step(function(s)
		s.skip = "done 1098 or ready 1013 or done 1013 or ready 1014 or done 1014"   -- (been inside already)
		s:Goto(SILVERPINE, 44.8, 67.8)
		s:Do("Enter Shadowfang Keep with your group.")
		s:Note("The keep stands on the hill north of Pyrewood Village.")
	end)

	-- inside: the two deathstalkers come right after the first boss
	g:Step(function(s)
		s:Talk(g.Npc("Deathstalker Adamant", 3849))
		s:Talk(g.Npc("Deathstalker Vincent", 4444))
		s:Turnin(1098, "Deathstalkers in Shadowfang")
		s:Note("After Rethilgore, pull the lever to open the cells and ask Adamant to unlock the courtyard door. Follow him; Vincent is in the courtyard, down to the right of the stairs.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Fenrus the Devourer", 4274))
		s:Collect(g.Item("The Book of Ur", 6283), { quest = 1013, objective = 1 })
		s:Note("Past Baron Silverlaine, Commander Springvale and Odo the Blindwatcher. Click the blue book on a bookshelf on the left side of Fenrus's room.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Archmage Arugal", 4275))
		s:Collect(g.Item("Head of Arugal", 5442), { quest = 1014, objective = 1 })
		s:Note("The last boss, at the top of the keep.")
	end)

	-- out: the Sepulcher on the way back north, then the Undercity
	g:Step(function(s)
		s.label = "out"
		s:Goto(SILVERPINE, 44.2, 39.8)
		s:Talk(dalar)
		s:Turnin(1014, "Arugal Must Die")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 53.7, 54.5)
		s:Talk(beldugur)
		s:Turnin(1013, "The Book of Ur")
	end)
end)
