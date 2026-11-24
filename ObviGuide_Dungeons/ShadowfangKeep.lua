-- Shadowfang Keep (Horde, 16-27): the three quests Attune lists for the Horde: The Book of Ur from the Undercity, and
-- Arugal Must Die and Deathstalkers in Shadowfang from the Sepulcher. Class quests, the part done here: the rogues'
-- Horn of Xelthos, the warlocks' Large Soran'ruk Fragment and the paladins' Enchanted Silver Ingot (Horde) or Jordan's
-- Smithing Hammer (Alliance, a short guide of its own). Quest, NPC and item ids and positions from Attune
-- (CixiDelmont) and QuestieDB's Forever data; the entrance and where things are inside from DungeonJournal (Exehn).

local UNDERCITY, SILVERPINE = 1458, 1421

-- rogues: C's Dead Drop beside Pyrewood Village, where The Horn of Xelthos starts and ends. Ids and where things are
-- from Attune (CixiDelmont) and DungeonJournal (Exehn).
local function deadDrop(g, s)
	s:Goto(SILVERPINE, 47.1, 71.1)
	s:Say("Click the ", g.Object("Dead Drop"), " in the hut beside Pyrewood Village.")
end

local function hornAccept(g)
	g:Step(function(s)
		s.only = "Rogue and level >= 20 and not done 78261"
		deadDrop(g, s)
		s:Accept(78261, "The Horn of Xelthos"):Optional()
		s:Note("Once C's letter has reached you in a capital city.")
	end)
end

local function horn(g, s)
	s.only = "onquest 78261"
	s:Use(g.Item("Breaching Charge", 210186))
	s:Note("Alone, outside a group. It blows open the courtyard gate.")
	s:Collect(g.Item("Twin Key", 210209)):Done("items 210183 >= 1 or ready 78261")
	s:Note("Pick pocket the Sister's Half-Key from the sister in the dining hall and the Brother's Half-Key from the brother upstairs, then combine them (that breaks stealth).")
	s:Collect(g.Item("Horn of Xelthos", 210183))
	s:Note("In the locked chest in the courtyard stables.")
end

local function hornTurnin(g)
	g:Step(function(s)
		s.only = "onquest 78261"
		deadDrop(g, s)
		s:Turnin(78261, "The Horn of Xelthos")
	end)
end

-- warlocks on The Orb of Soran'ruk: the large fragment (the small ones are in Blackfathom Deeps)
local function soranruk(g, s)
	s.only = "onquest 1740"
	s:Kill(g.Mob("Shadowfang Darksoul", 3855))
	s:Collect(g.Item("Large Soran'ruk Fragment", 6915))
end

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

	hornAccept(g)

	g:Step(function(s)
		s.skip = "done 1098 or ready 1013 or done 1013 or ready 1014 or done 1014"   -- (been inside already)
		s:Goto(SILVERPINE, 44.8, 67.8)
		s:Do("Enter Shadowfang Keep with your group.")
		s:Note("The keep stands on the hill north of Pyrewood Village.")
	end)

	g:Side("out", function(s) soranruk(g, s) end)
	g:Side("out", function(s) horn(g, s) end)

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

	-- Paladins on A Moon-Kissed Blade (Wolfsbane)
	g:Step(function(s)
		s.only = "onquest 95036"
		s:Collect(g.Item("Enchanted Silver Ingot", 267361))
		s:Note("On a table in Arugal's room.")
	end)

	hornTurnin(g)

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

-- Alliance: only class quests come here (Zygor's Alliance Paladin class guide for the hammer)
ObviGuide.Guide(function(g)
	g.title = "Shadowfang Keep: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-shadowfang-keep"
	g.only  = "Alliance and (Paladin/Warlock/Rogue)"

	hornAccept(g)

	g:Step(function(s)
		s.only = "onquest 1654 or onquest 1740 or onquest 78261"
		s:Goto(SILVERPINE, 44.8, 67.8)
		s:Do("Enter Shadowfang Keep.")
	end)

	-- Paladins on The Test of Righteousness (Verigan's Fist)
	g:Step(function(s)
		s.only = "onquest 1654"
		s:Collect(g.Item("Jordan's Smithing Hammer", 6895), { quest = 1654, objective = 3 })
		s:Note("Click ", g.Object("Jordan's Smithing Hammer"), " in the courtyard stables.")
	end)

	g:Step(function(s) horn(g, s) end)

	g:Step(function(s) soranruk(g, s) end)

	hornTurnin(g)
end)
