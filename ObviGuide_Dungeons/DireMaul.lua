-- Dire Maul (54-60): the quests Attune lists for each faction. Both: Shards of the Felvine (with A Reliquary of
-- Purity before it), Pusillin and the Elder Azj'Tordin, Lethtendris's Web, Elven Legends and The Madness Within.
-- Alliance: Feathermoon Stronghold; Horde: Camp Mojache. East first (Pusillin drops the Crescent Key that West
-- needs), then West. Quest, NPC, item and object ids and positions from Attune (CixiDelmont) and QuestieDB's Forever
-- data; where things are inside from DungeonJournal (Exehn). See README.md.

local STORMWIND, ORGRIMMAR, MOONGLADE, SILITHUS, FERALAS = 1453, 1454, 1450, 1451, 1444

-- Moonglade and Silithus: the reliquary that Shards of the Felvine needs
local function felvine(g)
	local rabine = g.Npc("Rabine Saturna", 11801)

	g:Step(function(s)
		s:Goto(MOONGLADE, 51.7, 45.1)
		s:Talk(rabine)
		s:Accept(5527, "A Reliquary of Purity")
		s:Note("In Nighthaven.")
	end)

	g:Step(function(s)
		s:Goto(SILITHUS, 63.2, 55.4)
		s:Collect(g.Item("Reliquary of Purity", 22201), { quest = 5527, objective = 1 })
		s:Note("Click the ", g.Object("Dusty Reliquary"), " in a ruined house of Southwind Village.")
	end)

	g:Step(function(s)
		s:Goto(MOONGLADE, 51.7, 45.1)
		s:Talk(rabine)
		s:Turnin(5527, "A Reliquary of Purity")
		s:Accept(5526, "Shards of the Felvine")
		s:Note("Then fly to Feralas.")
	end)
end

-- the east wing, then the west wing; elvenLegends is the faction's quest id
local function dungeon(g, web, elvenLegends)
	g:Step(function(s)
		s.skip = "ready 7441 or done 7441"   -- (been inside already)
		s:Goto(FERALAS, 64.8, 30.2)
		s:Do("Enter Dire Maul East with your group.")
		s:Note("The east wing of the ruins in northern Feralas.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Pusillin", 14354))
		s:Collect(g.Item("Book of Incantations", 18261), { quest = 7441, objective = 1 })
		s:Note("Talk to him each time he stops; he runs further each time, through the Warpwood Quarter and into the Hidden Reach, and fights at the end. Someone should take the ", g.Item("Crescent Key", 18249), " he drops: West needs it (or a rogue).")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lethtendris", 14327))
		s:Collect(g.Item("Lethtendris's Web", 18426), { quest = web, objective = 1 })
		s:Note("With her imp Pimgib, in the room before Alzzin.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Alzzin the Wildshaper", 11492))
		s:Use(g.Item("Reliquary of Purity", 18539))
		s:Collect(g.Item("Sealed Reliquary of Purity", 18540), { quest = 5526, objective = 1 })
		s:Note("The last boss. Once he's dead, pick up a ", g.Object("Felvine Shard"), " from the ground by the vine next to him and seal it in the reliquary there.")
	end)

	g:Step(function(s)
		s.skip = "ready 7461 or done 7461"   -- (been inside already)
		s:Goto(FERALAS, 60.3, 30.2)
		s:Do("Enter Dire Maul West with your group.")
		s:Note("The door needs the Crescent Key from Pusillin, or a rogue to pick it.")
	end)

	g:Step(function(s)
		s:Talk(g.Npc("Shen'dralar Ancient", 14358))
		s:Accept(7461, "The Madness Within")
		s:Note("She floats above the Court of the Highborne, past the second pylon.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Immol'thar", 11496), { quest = 7461, objective = 1 })
		s:Note("Kill the guardians at all five pylons first; that brings down the force field around his prison.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Prince Tortheldrin", 11486), { quest = 7461, objective = 2 })
		s:Note("Through the door in the north-east of the prison (the key again), down in the Athenaeum.")
	end)

	g:Step(function(s)
		s:Quest(elvenLegends, 1, "Find the remains of Telmius Dreamseeker.")
		s:Note("The skeleton lies beside Lorekeeper Lydros in the Athenaeum.")
	end)

	g:Step(function(s)
		s:Talk(g.Npc("Shen'dralar Ancient", 14358))
		s:Turnin(7461, "The Madness Within")
		s:Note("Back up in the Court of the Highborne. Her next quest, The Treasure of the Shen'dralar, is the chest under the Athenaeum stairs.")
	end)

	-- out: Azj'Tordin is on the way from the ruins to either camp
	g:Step(function(s)
		s.label = "out"
		s:Goto(FERALAS, 76.9, 37.4)
		s:Talk(g.Npc("Azj'Tordin", 14355))
		s:Turnin(7441, "Pusillin and the Elder Azj'Tordin")
		s:Note("On the Lariss Pavilion, east of Dire Maul.")
	end)
end

ObviGuide.Guide(function(g)
	g.title = "Dire Maul: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-dire-maul"
	g.next  = "obvi-lower-blackrock-spire"
	g.only  = "Alliance"

	local latronicus = g.Npc("Latronicus Moonspear", 7877)
	local runethorn  = g.Npc("Scholar Runethorn", 14374)

	g:Step(function(s)
		s:Goto(STORMWIND, 56.4, 74.1)
		s:Talk(g.Npc("Crier Goodman", 2198))
		s:Accept(7494, "Feathermoon Stronghold")
		s:Note("Also offered by Courier Hammerfall in Ironforge and Herald Moonstalker in Darnassus.")
	end)

	felvine(g)

	g:Step(function(s)
		s:Goto(FERALAS, 30.4, 46.2)
		s:Talk(latronicus)
		s:Turnin(7494, "Feathermoon Stronghold")
		s:Accept(7488, "Lethtendris's Web")
		s:Note("In Feathermoon Stronghold, on the island off the west coast.")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 31.7, 43.5)
		s:Talk(runethorn)
		s:Accept(7482, "Elven Legends")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 76.9, 37.4)
		s:Talk(g.Npc("Azj'Tordin", 14355))
		s:Accept(7441, "Pusillin and the Elder Azj'Tordin")
		s:Note("On the Lariss Pavilion, east of Dire Maul. Thalanaar is the nearest flight path.")
	end)

	dungeon(g, 7488, 7482)

	g:Step(function(s)
		s:Goto(FERALAS, 30.4, 46.2)
		s:Talk(latronicus)
		s:Turnin(7488, "Lethtendris's Web")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 31.7, 43.5)
		s:Talk(runethorn)
		s:Turnin(7482, "Elven Legends")
	end)

	g:Step(function(s)
		s:Goto(MOONGLADE, 51.7, 45.1)
		s:Talk(g.Npc("Rabine Saturna", 11801))
		s:Turnin(5526, "Shards of the Felvine")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Dire Maul: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-dire-maul-horde"
	g.next  = "obvi-lower-blackrock-spire-horde"
	g.only  = "Horde"

	local talo     = g.Npc("Talo Thornhoof", 7776)
	local korolusk = g.Npc("Sage Korolusk", 14373)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 63.9, 44.1)
		s:Talk(g.Npc("Harbinger Balthazad", 10879))
		s:Accept(7492, "Camp Mojache")
		s:Note("Also offered by Bluff Runner Windstrider in Thunder Bluff and Warcaller Gorlach in the Undercity.")
	end)

	felvine(g)

	g:Step(function(s)
		s:Goto(FERALAS, 76.2, 43.8)
		s:Talk(talo)
		s:Turnin(7492, "Camp Mojache")
		s:Accept(7489, "Lethtendris's Web")
		s:Note("In Camp Mojache.")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 74.4, 44.0)
		s:Talk(korolusk)
		s:Accept(7481, "Elven Legends")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 76.9, 37.4)
		s:Talk(g.Npc("Azj'Tordin", 14355))
		s:Accept(7441, "Pusillin and the Elder Azj'Tordin")
		s:Note("On the Lariss Pavilion, just north of Camp Mojache.")
	end)

	dungeon(g, 7489, 7481)

	g:Step(function(s)
		s:Goto(FERALAS, 76.2, 43.8)
		s:Talk(talo)
		s:Turnin(7489, "Lethtendris's Web")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 74.4, 44.0)
		s:Talk(korolusk)
		s:Turnin(7481, "Elven Legends")
	end)

	g:Step(function(s)
		s:Goto(MOONGLADE, 51.7, 45.1)
		s:Talk(g.Npc("Rabine Saturna", 11801))
		s:Turnin(5526, "Shards of the Felvine")
	end)
end)
