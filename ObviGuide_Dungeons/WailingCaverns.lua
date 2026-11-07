-- Wailing Caverns (Alliance, 15-22): the quests Attune lists for the Alliance (Raptor Horns and Smart Drinks, Trouble
-- at the Docks, Deviate Hides, Deviate Eradication, and The Glowing Shard from Mutanus), with In Nightmares after it.
-- Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data. Ratchet is the hub:
-- the route goes there first, out to the raptors and back, then to the caverns, and ends in Ratchet. See README.md.

local BARRENS, DARNASSUS = 1413, 1457

ObviGuide.Guide(function(g)
	g.title = "Wailing Caverns: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-wailing-caverns"
	g.next  = "obvi-excavation-site"
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
		s:Note("In Ratchet. Hand this in before the dungeon: it leads to Smart Drinks, which you need inside.")
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

-- Wailing Caverns (Horde, 10-22): the quests Attune lists for the Horde. Tonga Runetotem's oasis chain (The Barrens
-- Oases to Altered Beings) leads to Leaders of the Fang; with it Serpentbloom, Raptor Horns and Smart Drinks, Trouble at
-- the Docks, Deviate Hides, Deviate Eradication, and The Glowing Shard from Mutanus, with In Nightmares after it.
-- Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data. Thunder Bluff first,
-- then the Crossroads and Ratchet, the oasis chain, back to Thunder Bluff for Leaders of the Fang, the caverns, and
-- the turn-ins in Ratchet and Thunder Bluff.

local THUNDER_BLUFF = 1456

ObviGuide.Guide(function(g)
	g.title = "Wailing Caverns: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-wailing-caverns-horde"
	g.next  = "obvi-shadowfang-keep-horde"
	g.only  = "Horde"

	local hamuul = g.Npc("Arch Druid Hamuul Runetotem", 5769)
	local nara   = g.Npc("Nara Wildmane", 5770)
	local zamah  = g.Npc("Apothecary Zamah", 3419)
	local tonga  = g.Npc("Tonga Runetotem", 3448)
	local mebok  = g.Npc("Mebok Mizzyrix", 3446)
	local crane  = g.Npc("Crane Operator Bigglefuzz", 3665)
	local nalpak = g.Npc("Nalpak", 5767)
	local ebru   = g.Npc("Ebru", 5768)
	local falla  = g.Npc("Falla Sagewind", 8418)
	local shard  = g.Item("Glowing Shard", 10441)

	-- Thunder Bluff: Elder Rise and the Pools of Vision
	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 78.6, 28.6)
		s:Talk(hamuul)
		s:Accept(886, "The Barrens Oases")
		s:Note("On Elder Rise.")
	end)

	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 22.8, 20.9)
		s:Talk(zamah)
		s:Accept(962, "Serpentbloom")
		s:Note("In the Pools of Vision, the cave under Spirit Rise; the way in is at 29.9, 29.8.")
	end)

	-- the Crossroads and Ratchet
	g:Step(function(s)
		s:Goto(BARRENS, 52.3, 31.9)
		s:Talk(tonga)
		s:Turnin(886, "The Barrens Oases")
		s:Accept(870, "The Forgotten Pools")
		s:Note("At the Crossroads. Fly from Thunder Bluff.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(mebok)
		s:Accept(865, "Raptor Horns")
		s:Talk(crane)
		s:Accept(959, "Trouble at the Docks")
		s:Note("In Ratchet, by the docks.")
	end)

	-- the north-west: the raptors and the Forgotten Pools lie close together
	g:Step(function(s)
		s:Goto(BARRENS, 43.4, 15.6)
		s:Kill(g.Mob("Sunscale Scytheclaw", 3256))
		s:Collect(g.Item("Intact Raptor Horn", 5055), { count = 5, quest = 865, objective = 1 })
		s:Note("Purple raptors in the north-west of the Barrens; more around 45.3, 14.9.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 45.1, 22.5)
		s:Quest(870, 1, "Swim down into the water of the Forgotten Pools.")
	end)

	-- Tonga's chain: the Stagnant Oasis twice
	g:Step(function(s)
		s:Goto(BARRENS, 52.3, 31.9)
		s:Talk(tonga)
		s:Turnin(870, "The Forgotten Pools")
		s:Accept(877, "The Stagnant Oasis")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 55.6, 42.7)
		s:Quest(877, 1, "Click the ", g.Object("Bubbling Fissure"), " under the water.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 52.3, 31.9)
		s:Talk(tonga)
		s:Turnin(877, "The Stagnant Oasis")
		s:Accept(880, "Altered Beings")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 55.5, 42.7)
		s:Kill(g.Mob("Oasis Snapjaw", 3461))
		s:Collect(g.Item("Altered Snapjaw Shell", 5098), { count = 8, quest = 880, objective = 1 })
		s:Note("In and around the water of the Stagnant Oasis.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 52.3, 31.9)
		s:Talk(tonga)
		s:Turnin(880, "Altered Beings")
		s:Accept(1489, "Hamuul Runetotem")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(mebok)
		s:Turnin(865, "Raptor Horns")
		s:Accept(1491, "Smart Drinks")
		s:Note("Its Wailing Essence only drops while you have the quest, so take it before going in.")
	end)

	-- back to Thunder Bluff for Leaders of the Fang: the gems only count with it in your log
	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 78.6, 28.6)
		s:Talk(hamuul)
		s:Turnin(1489, "Hamuul Runetotem")
		s:Accept(1490, "Nara Wildmane")
		s:Note("Fly from Ratchet.")
	end)

	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 75.7, 31.6)
		s:Talk(nara)
		s:Turnin(1490, "Nara Wildmane")
		s:Accept(914, "Leaders of the Fang")
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
		s:Note("Fly to the Crossroads. Jump down carefully into the cave mouth at 45.8, 36.2 (aim for the stone); they stand just inside.")
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
		s:Collect(g.Item("Serpentbloom", 5339), { count = 10, quest = 962, objective = 1 })
		s:Note("Click the small green and purple ", g.Object("Serpentbloom"), " plants along the walls; they grow in the caves outside the portal too.")
	end)

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
		s:Note("Only if you do the Naralex event: after the four Lords of the Fang, talk to the Disciple of Naralex at the entrance and keep him alive. Mutanus the Devourer drops the ", shard, ".")
	end)

	-- the Lords of the Fang, each with the Deviate kind that lives in the same part
	g:Step(function(s)
		s:Kill(g.Mob("Deviate Ravager", 3636), { quest = 1487, objective = 1 })
		s:Kill(g.Mob("Lady Anacondra", 3671))
		s:Collect(g.Item("Gem of Anacondra", 9739), { quest = 914, objective = 2 })
		s:Note("In the Screaming Gully, the first big cave. Lady Anacondra can be in several spots there.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Deviate Viper", 5755), { quest = 1487, objective = 2 })
		s:Kill(g.Mob("Lord Cobrahn", 3669))
		s:Collect(g.Item("Gem of Cobrahn", 9738), { quest = 914, objective = 1 })
		s:Note("In the Pit of Fangs, west along the water from the Screaming Gully; Cobrahn is up and around the path.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Deviate Shambler", 5761), { quest = 1487, objective = 3 })
		s:Kill(g.Mob("Deviate Dreadfang", 5056), { quest = 1487, objective = 4 })
		s:Kill(g.Mob("Lord Pythas", 3670))
		s:Collect(g.Item("Gem of Pythas", 9740), { quest = 914, objective = 3 })
		s:Note("Shamblers in the Crag of the Everliving, east from the Screaming Gully; Dreadfangs in the Winding Chasm past it, with Lord Pythas in its northern part.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lord Serpentis", 3673))
		s:Collect(g.Item("Gem of Serpentis", 9741), { quest = 914, objective = 4 })
		s:Note("Back up in the Crag of the Everliving, on the upper path past the small waterfall.")
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
		s:Talk(crane)
		s:Turnin(959, "Trouble at the Docks")
	end)

	g:Step(function(s)
		s.only = "onquest 6981 or done 6981"
		s:Goto(BARRENS, 63.0, 37.2)
		s:Talk(g.Npc("Sputtervalve", 3442))
		s:Quest(6981, 1, "Ask Sputtervalve about the glowing shard.")
	end)

	-- the shard goes back to the hill above the caverns
	g:Step(function(s)
		s.only = "onquest 6981 or done 6981"
		s:Goto(BARRENS, 48.2, 32.8)
		s:Talk(falla)
		s:Turnin(6981, "The Glowing Shard")
		s:Accept(3369, "In Nightmares")
		s:Note("Inside the building on the hill above the caverns.")
	end)

	-- Thunder Bluff
	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 75.7, 31.6)
		s:Talk(nara)
		s:Turnin(914, "Leaders of the Fang")
	end)

	g:Step(function(s)
		s.only = "onquest 3369 or done 3369"
		s:Goto(THUNDER_BLUFF, 78.6, 28.6)
		s:Talk(hamuul)
		s:Turnin(3369, "In Nightmares")
	end)

	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 22.8, 20.9)
		s:Talk(zamah)
		s:Turnin(962, "Serpentbloom")
		s:Note("Back in the Pools of Vision.")
	end)
end)
