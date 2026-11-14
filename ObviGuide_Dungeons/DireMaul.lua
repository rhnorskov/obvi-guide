-- Dire Maul (54-60): the quests for each faction. Both: Shards of the Felvine (with A Reliquary of Purity before it),
-- Pusillin and the Elder Azj'Tordin, Lethtendris's Web, Elven Legends and The Madness Within; in the north wing Free
-- Knot! (and, optional, The Gordok Ogre Suit) and Unfinished Gordok Business; the Libram of Rapidity, Focus and
-- Protection, only when you have the libram. Alliance: Feathermoon Stronghold, and Fragments of the Past for those on
-- its chain (Starfall starts it); Horde: Camp Mojache. East first (Pusillin drops the Crescent Key that the other two
-- wings need), then North, then West. Quest list from Attune (CixiDelmont) and DungeonJournal (Exehn); quest, NPC,
-- item and object ids and positions from Attune and QuestieDB's Forever data; where things are inside from
-- DungeonJournal. See README.md.

local STORMWIND, ORGRIMMAR, MOONGLADE, SILITHUS, FERALAS = 1453, 1454, 1450, 1451, 1444
local EPL = 1423

-- the libram quests: quest, its libram (it drops in Dire Maul), and the rest Lydros wants with it (Pristine Black
-- Diamond, Large Brilliant Shards, and Blood of Heroes, Skin of Shadow or Frayed Abomination Stitching). Lines and
-- conditions for having the libram, or with `full` the libram and the rest.
local LIBRAMS = {
	{ 7483, "Libram of Rapidity",  18332, "items 18335 >= 1 and items 14344 >= 2 and items 12938 >= 2" },
	{ 7484, "Libram of Focus",     18333, "items 18335 >= 1 and items 14344 >= 4 and items 12753 >= 2" },
	{ 7485, "Libram of Protection", 18334, "items 18335 >= 1 and items 14344 >= 2 and items 12735 >= 1" },
}

---@param full boolean
local function libramCondition(full)
	local any = {}
	for _, l in ipairs(LIBRAMS) do
		any[#any + 1] = full and ("(items " .. l[3] .. " >= 1 and " .. l[4] .. ")") or ("items " .. l[3] .. " >= 1")
	end
	return "(" .. table.concat(any, " or ") .. ")"
end

---@param s ObviGuideLinesBuilder
---@param full boolean
local function libramLines(s, full)
	for _, l in ipairs(LIBRAMS) do
		local have = full and ("items " .. l[3] .. " >= 1 and " .. l[4]) or ("items " .. l[3] .. " >= 1")
		s:Accept(l[1], l[2]):Only(have)
		s:Turnin(l[1], l[2]):Only(have)
	end
end

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

-- the east wing, then the north wing, then the west wing; elvenLegends is the faction's quest id
local function dungeon(g, web, elvenLegends)
	local knot      = g.Npc("Knot Thimblejack", 14338)
	local kromcrush = g.Npc("Captain Kromcrush", 14325)
	local lydros    = g.Npc("Lorekeeper Lydros", 14368)

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

	-- the north wing: Knot, and Captain Kromcrush once King Gordok is dead
	g:Step(function(s)
		s.skip = "onquest 7703 or done 7703"   -- (been inside already)
		s:Goto(FERALAS, 62.5, 24.9)
		s:Do("Enter Dire Maul North with your group.")
		s:Note("The Gordok wing, north in the ruins. Its door needs the Crescent Key too, or a rogue.")
	end)

	g:Step(function(s)
		local suit = "onquest 5518 or (items 14048 >= 4 and items 8170 >= 8 and items 14341 >= 2)"
		s:Talk(knot)
		s:Note("Chained up in the Gordok wing. Optional, before you free him (he leaves then): The Gordok Ogre Suit, for 4 Bolts of Runecloth, 8 Rugged Leather, 2 Rune Threads and the Ogre Tannin from the basket on the upper level beyond him.")
		s:Accept(5518, "The Gordok Ogre Suit"):Only(suit):Optional()
		s:Collect(g.Item("Ogre Tannin", 18240), { quest = 5518, objective = 4 }):Only("onquest 5518"):Optional()
		s:Turnin(5518, "The Gordok Ogre Suit"):Only("onquest 5518"):Optional()
		s:Accept(5525, "Free Knot!")
		s:Collect(g.Item("Gordok Shackle Key", 18250), { quest = 5525, objective = 1 })
		s:Note("The ogres of the wing drop it.")
		s:Turnin(5525, "Free Knot!")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("King Gordok", 11501))
		s:Talk(kromcrush)
		s:Accept(7703, "Unfinished Gordok Business")
		s:Note("At the end of the wing, with Cho'Rush the Observer. Spare Captain Kromcrush on the way if you can (with the Ogre Suit you can talk to him instead of fighting): once King Gordok is dead you are the Gordok king, and Kromcrush is friendly and gives the quest.")
	end)

	-- Fragments of the Past (Alliance): the vial is filled outside, on the way to the west wing
	g:Step(function(s)
		s.only = "onquest 5247"
		s:Goto(FERALAS, 58.9, 36.0)
		s:Use(g.Item("Empty Water Vial", 16974))
		s:Collect(g.Item("Vial of Dire Water", 16973), { quest = 5247, objective = 3 })
		s:Note("Fill it at the ", g.Object("Dire Pool"), " on Eldreth Row, the street in the ruins that leads to the West wing.")
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
		s:Collect(g.Item("Gauntlet of Gordok Might", 18336), { quest = 7703, objective = 1 }):Only("onquest 7703")
		s:Note("In ", g.Object("The Prince's Chest"), ", near him.")
	end)

	-- only on a later run: Lydros wants Elven Legends handed in first
	g:Side("out", function(s)
		s.only = "done " .. elvenLegends .. " and " .. libramCondition(false)
		s:Talk(lydros)
		libramLines(s, false)
		s:Note("Optional, with a libram from Dire Maul: he makes it into an arcanum for a Pristine Black Diamond and 2 Large Brilliant Shards, plus 2 Blood of Heroes (Rapidity), 2 Skin of Shadow and 2 more shards (Focus) or a Frayed Abomination Stitching (Protection).")
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

	g:Step(function(s)
		s.only = "ready 7703"
		s:Goto(FERALAS, 62.5, 24.9)
		s:Talk(kromcrush)
		s:Turnin(7703, "Unfinished Gordok Business")
		s:Note("Back in Dire Maul North, where he is friendly to the Gordok king.")
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

-- back to Lydros once Elven Legends is handed in, only with a libram and everything that goes with it
local function libramRun(g)
	g:Step(function(s)
		s.only = libramCondition(true)
		s:Goto(FERALAS, 60.3, 30.2)
		s:Talk(g.Npc("Lorekeeper Lydros", 14368))
		libramLines(s, true)
		s:Note("Back in Dire Maul West, down in the Athenaeum: he makes your libram into an arcanum.")
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
	local aurora     = g.Npc("Aurora Skycaller", 10304)

	g:Step(function(s)
		s:Goto(STORMWIND, 56.4, 74.1)
		s:Talk(g.Npc("Crier Goodman", 2198))
		s:Accept(7494, "Feathermoon Stronghold")
		s:Note("Also offered by Courier Hammerfall in Ironforge and Herald Moonstalker in Darnassus.")
	end)

	-- Fragments of the Past ends a chain that starts in Rut'theran Village; Attune doesn't count it, so it's only
	-- pointed at
	g:Step(function(s)
		local daryn = g.Npc("Daryn Lightwind", 7907)
		s.skip = "onquest 5250 or done 5250 or onquest 5249 or done 5249 or onquest 5244 or done 5244"
		s:Talk(daryn)
		s:Accept(5250, "Starfall"):Optional()
		s:Do("Optional: take Starfall from ", daryn, " in Rut'theran Village (Teldrassil 55.4, 92.2), or tick this off to skip it.")
		s:Note("It starts a chain through Winterspring, Azshara and the Eastern Plaguelands that ends with Fragments of the Past, a Dire Maul quest; without it you just skip that one.")
	end)

	-- Fragments of the Past: only for those at the end of that chain
	g:Step(function(s)
		s.only = "ready 5246 or done 5246"
		s:Goto(EPL, 46.5, 16.0)
		s:Talk(aurora)
		s:Turnin(5246, "Fragments of the Past")
		s:Accept(5247, "Fragments of the Past")
		s:Note("Near the Northpass Tower. She also wants an Enchanted Thorium Bar and 5 Crystal Restore (from an enchanter and an alchemist); the vial is filled at Dire Maul.")
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

	libramRun(g)

	g:Step(function(s)
		s:Goto(MOONGLADE, 51.7, 45.1)
		s:Talk(g.Npc("Rabine Saturna", 11801))
		s:Turnin(5526, "Shards of the Felvine")
	end)

	g:Step(function(s)
		s.only = "ready 5247"
		s:Goto(EPL, 46.5, 16.0)
		s:Talk(aurora)
		s:Turnin(5247, "Fragments of the Past")
		s:Note("Near the Northpass Tower in the Eastern Plaguelands.")
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

	libramRun(g)

	g:Step(function(s)
		s:Goto(MOONGLADE, 51.7, 45.1)
		s:Talk(g.Npc("Rabine Saturna", 11801))
		s:Turnin(5526, "Shards of the Felvine")
	end)
end)
