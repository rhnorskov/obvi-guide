-- Wailing Caverns (Alliance, 15-22): the quests Attune lists for the Alliance (Raptor Horns and Smart Drinks, Trouble
-- at the Docks, Deviate Hides, Deviate Eradication, and The Glowing Shard from Mutanus), with In Nightmares after it.
-- Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data. Ratchet is the hub:
-- the route goes there first, out to the raptors and back, then to the caverns, and ends in Ratchet. See README.md.

local BARRENS, DARNASSUS = 1413, 1457

ObviGuide.Guide(function(g)
	g.title = "Wailing Caverns: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-wailing-caverns"
	g.only  = "Alliance"

	local mebok    = g.Npc("Mebok Mizzyrix", 3446)
	local crane    = g.Npc("Crane Operator Bigglefuzz", 3665)
	local nalpak   = g.Npc("Nalpak", 5767)
	local ebru     = g.Npc("Ebru", 5768)
	local falla    = g.Npc("Falla Sagewind", 8418)
	local shard    = g.Item("Glowing Shard", 10441)

	-- Ratchet: the two goblins by the docks
	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(mebok)
		s:Accept(865, "Raptor Horns")
		s:Note("In Ratchet. Smart Drinks, for the dungeon, comes after this one.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 63.1, 37.6)
		s:Talk(crane)
		s:Accept(959, "Trouble at the Docks")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 43.4, 15.6)
		s:Kill(g.Mob("Sunscale Scytheclaw", 3256))
		s:Collect(g.Item("Intact Raptor Horn", 5055), { count = 5, quest = 865, objective = 1 })
		s:Note("Purple raptors in the north-west of the Barrens; more around 45.3, 14.9.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(mebok)
		s:Turnin(865, "Raptor Horns")
		s:Accept(1491, "Smart Drinks")
		s:Note("Its Wailing Essence only drops while you have the quest, so take it before going in.")
	end)

	-- the caverns: up the hill west of the Crossroads road, then down into the oasis cave
	g:Step(function(s)
		s:Path(BARRENS, 50.3, 35.4)
		s:Path(BARRENS, 49.2, 34.1)
		s:Path(BARRENS, 48.1, 33.0)
		s:Path(BARRENS, 47.3, 33.6)
		s:Goto(BARRENS, 46.0, 35.7)
		s:Talk(nalpak)
		s:Accept(1486, "Deviate Hides")
		s:Talk(ebru)
		s:Accept(1487, "Deviate Eradication")
		s:Note("Jump down carefully into the cave mouth at 45.8, 36.2 (aim for the stone); they stand just inside.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 45.7, 33.6)
		s:Kill(g.Mob("Mad Magglish", 3655))
		s:Collect(g.Item("99-Year-Old Port", 5334), { quest = 959, objective = 1 })
		s:Note("He's stealthed in the cave before the dungeon; also look around 46.8, 34.6 and 46.5, 35.5.")
	end)

	g:Step(function(s)
		s.skip = "ready 1487 or done 1487"   -- (been inside already)
		s:Do("Enter Wailing Caverns with your group.")
	end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Evolving Ectoplasm", 3640))
		s:Collect(g.Item("Wailing Essence", 6464), { count = 6, quest = 1491, objective = 1 })
		s:Note("Throughout the dungeon.")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Deviate Hide", 6443), { count = 20, quest = 1486, objective = 1 })
		s:Note("From the Deviate beasts throughout the dungeon.")
	end)

	-- Mutanus only comes if the group kills the four Lords of the Fang and escorts the Disciple of Naralex
	g:Side("out", function(s)
		s:Use(shard):Only("not onquest 6981 and not done 6981")
		s:Accept(6981, "The Glowing Shard")
		s:Note("Only if you do the Naralex event: kill the four Lords of the Fang, then talk to the Disciple of Naralex at the entrance and keep him alive. Mutanus the Devourer drops the ", shard, ".")
	end)

	-- Deviate Eradication: each kind lives in its own part, in the order the Lords of the Fang are reached
	g:Step(function(s)
		s:Kill(g.Mob("Deviate Ravager", 3636), { quest = 1487, objective = 1 })
		s:Note("In the Screaming Gully, the first big cave, where Lady Anacondra is.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Deviate Viper", 5755), { quest = 1487, objective = 2 })
		s:Note("In the Pit of Fangs, west along the water from the Screaming Gully, where Lord Cobrahn is.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Deviate Shambler", 5761), { quest = 1487, objective = 3 })
		s:Kill(g.Mob("Deviate Dreadfang", 5056), { quest = 1487, objective = 4 })
		s:Note("Shamblers in the Crag of the Everliving, east from the Screaming Gully; Dreadfangs in the Winding Chasm past it, where Lord Pythas is. Lord Serpentis is back up in the Crag.")
	end)

	-- out of the dungeon: the two by the entrance first
	g:Step(function(s)
		s.label = "out"
		s:Goto(BARRENS, 46.0, 35.7)
		s:Talk(nalpak)
		s:Turnin(1486, "Deviate Hides")
		s:Talk(ebru)
		s:Turnin(1487, "Deviate Eradication")
		s:Note("Just outside the instance portal, in the cave.")
	end)

	-- Ratchet
	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(mebok)
		s:Turnin(1491, "Smart Drinks")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 63.1, 37.6)
		s:Talk(crane)
		s:Turnin(959, "Trouble at the Docks")
	end)

	g:Step(function(s)
		s.only = "onquest 6981 or done 6981"
		s:Goto(BARRENS, 63.0, 37.2)
		s:Talk(g.Npc("Sputtervalve", 3442))
		s:Quest(6981, 1, "Ask Sputtervalve about the glowing shard.")
	end)

	-- the shard goes back to the hill above the caverns, and on to Darnassus
	g:Step(function(s)
		s.only = "onquest 6981 or done 6981"
		s:Goto(BARRENS, 48.2, 32.8)
		s:Talk(falla)
		s:Turnin(6981, "The Glowing Shard")
		s:Accept(3370, "In Nightmares")
		s:Note("Inside the building on the hill above the caverns.")
	end)

	g:Step(function(s)
		s.only = "onquest 3370 or done 3370"
		s:Goto(DARNASSUS, 35.4, 8.4)
		s:Talk(g.Npc("Mathrengyl Bearwalker", 4217))
		s:Turnin(3370, "In Nightmares")
		s:Note("Upstairs in the Cenarion Enclave. It can wait for your next time in Darnassus.")
	end)
end)
