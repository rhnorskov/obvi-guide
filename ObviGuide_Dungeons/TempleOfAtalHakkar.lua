-- The Temple of Atal'Hakkar (46-55): the quests Attune lists for each faction. Both: The Sunken Temple, The Stone
-- Circle, Into the Depths and Secret of the Circle (Marvon Rivetseeker), Yeh'kinya's chain from Screecher Spirits to
-- The God Hakkar (with the Mosh'aru tablets from Zul'Farrak), Jammal'an the Prophet and The Essence of Eranikus.
-- Alliance: Into The Temple of Atal'Hakkar (Brohann Caskbelly). Horde: Fel'Zerul's chain from Pool of Tears to The
-- Temple of Atal'Hakkar. Quest, NPC and item ids from Attune (CixiDelmont) and QuestieDB's Forever data, entrances
-- from DungeonJournal (Exehn). Yeh'kinya's Ancient Egg has to reach Tanaris before the temple, so the route crosses
-- between Kalimdor and the Eastern Kingdoms twice. See README.md.

local BARRENS, FERALAS, TANARIS = 1413, 1444, 1446
local STORMWIND, HINTERLANDS, SWAMP = 1453, 1425, 1435

-- the parts both factions share ---------------------------------------------------------------------------------

local function npcs(g)
	return {
		yeh     = g.Npc("Yeh'kinya", 8579),
		marvon  = g.Npc("Marvon Rivetseeker", 7771),
		exile   = g.Npc("Atal'ai Exile", 5598),
	}
end

-- Tanaris, Feralas, Ratchet and Zul'Farrak: everything up to The Ancient Egg. `sunken` is the faction's Sunken
-- Temple quest, `giver` the step that picks it up in Feralas.
local function kalimdor(g, n, sunken, giver)
	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(n.yeh)
		s:Accept(3520, "Screecher Spirits")
		s:Note("In Steamwheedle Port, north-east of Gadgetzan.")
	end)

	g:Step(giver)

	g:Step(function(s)
		s:Goto(FERALAS, 58.2, 57.8)
		s:Kill(g.Mob("Vale Screecher", 5307))
		s:Kill(g.Mob("Rogue Vale Screecher", 5308))
		s:Use(g.Item("Yeh'kinya's Bramble", 10699))
		s:Quest(3520, 1, "Capture 3 screecher spirits.")
		s:Note("Use the bramble on a fresh corpse, then talk to the spirit that rises. Few spawn here; Rogue Vale Screechers also count, around 43.5, 36.5.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 52.7, 45.9)
		s:Talk(n.marvon)
		s:Turnin(sunken, "The Sunken Temple")
		s:Accept(3444, "The Stone Circle")
		s:Note("In Gadgetzan.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(n.yeh)
		s:Turnin(3520, "Screecher Spirits")
		s:Accept(3527, "The Prophecy of Mosh'aru")
		s:Note("Then fly from Gadgetzan to Ratchet.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 62.5, 38.5)
		s:Collect(g.Item("Stone Circle", 10556), { quest = 3444, objective = 1 })
		s:Note("In ", g.Object("Marvon's Chest"), ", in his workshop in Ratchet. Then fly back to Gadgetzan.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 52.7, 45.9)
		s:Talk(n.marvon)
		s:Turnin(3444, "The Stone Circle")
		s:Accept(3446, "Into the Depths")
		s:Accept(3447, "Secret of the Circle")
	end)

	-- the Mosh'aru tablets come from Zul'Farrak, just north-west of Gadgetzan
	g:Step(function(s)
		s.skip = "ready 3527 or done 3527"
		s:Goto(TANARIS, 38.7, 20.0)
		s:Do("Enter Zul'Farrak with your group.")
		s:Note("At the gate of the troll city in north-west Tanaris.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Theka the Martyr", 7272))
		s:Collect(g.Item("First Mosh'aru Tablet", 10660), { quest = 3527, objective = 1 })
		s:Note("The second boss, along the right-hand path.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Hydromancer Velratha", 7795))
		s:Collect(g.Item("Second Mosh'aru Tablet", 10661), { quest = 3527, objective = 2 })
		s:Note("Around the pool beyond the pyramid.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(n.yeh)
		s:Turnin(3527, "The Prophecy of Mosh'aru")
		s:Accept(4787, "The Ancient Egg")
		s:Note("The egg is in the Hinterlands, in the Eastern Kingdoms.")
	end)
end

local function egg(g)
	g:Step(function(s)
		s:Goto(HINTERLANDS, 57.6, 86.8)
		s:Collect(g.Item("Ancient Egg", 12402), { quest = 4787, objective = 1 })
		s:Note("In a cave below Jintha'Alor: the mouth is around 58.6, 79.2; follow the tunnel down to the egg. Trolls all the way.")
	end)
end

local function hakkar(g, n)
	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(n.yeh)
		s:Turnin(4787, "The Ancient Egg")
		s:Accept(3528, "The God Hakkar")
		s:Note("She gives you the ", g.Item("Egg of Hakkar", 10465), " for the temple.")
	end)
end

local function exileStep(s, n)
	s:Path(HINTERLANDS, 35.8, 64.1)
	s:Path(HINTERLANDS, 33.1, 73.8)
	s:Goto(HINTERLANDS, 33.8, 75.2)
	s:Talk(n.exile)
end

-- the temple itself; `extra` adds the faction's own side tasks inside
local function temple(g, extra)
	g:Step(function(s)
		s.skip = "done 3446 or done 3447 or ready 3528 or done 3528"   -- (been inside already)
		s:Goto(SWAMP, 69.5, 53.5)
		s:Do("Enter the Temple of Atal'Hakkar with your group.")
		s:Note("Dive into the Pool of Tears and follow the stairs down to the temple door.")
	end)

	if extra then extra() end

	g:Step(function(s)
		s:Kill(g.Mob("Atal'alarion", 8580))
		s:Turnin(3446, "Into the Depths")
		s:Turnin(3447, "Secret of the Circle")
		s:Note("Left and down to the Hall of Serpents. Click the six serpent statues in the side rooms in this order: south, north, south-west, south-east, north-west, north-east. Atal'alarion rises in the pit; the ", g.Object("Altar of Hakkar"), " is at the top of its stairs and the ", g.Object("Idol of Hakkar"), " in its middle.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Jammal'an the Prophet", 5710))
		s:Collect(g.Item("Head of Jammal'an", 6212), { quest = 1446, objective = 1 })
		s:Note("Up the stairs to the balconies around the Pit of Sacrifice: kill the six troll champions there to open his barrier, then drop into the pit and go south-east.")
	end)

	g:Step(function(s)
		local essence = g.Item("Essence of Eranikus", 10454)
		s:Kill(g.Mob("Shade of Eranikus", 5709))
		s:Use(essence):Only("not onquest 3373 and not done 3373")
		s:Accept(3373, "The Essence of Eranikus")
		s:Turnin(3373, "The Essence of Eranikus")
		s:Note("South of the Pit of Sacrifice, after the dragonkin on the ledge. He drops the ", essence, ": place it in the ", g.Object("Essence Font"), " in the north-east corner of his room.")
	end)

	g:Step(function(s)
		s:Use(g.Item("Egg of Hakkar", 10465))
		s:Kill(g.Mob("Hakkari Bloodkeeper", 8438))
		s:Kill(g.Mob("Avatar of Hakkar", 8443))
		s:Collect(g.Item("Filled Egg of Hakkar", 10662), { quest = 3528, objective = 1 })
		s:Note("In the Sanctum of the Fallen God, south-west of the Pit of Sacrifice: use the egg by the skeleton, kill the Bloodkeepers and use their ", g.Item("Hakkari Blood", 10460), " on the four Eternal Flames. The Avatar then comes; fill the egg with his essence.")
	end)
end

-- Alliance -------------------------------------------------------------------------------------------------------

ObviGuide.Guide(function(g)
	g.title = "The Temple of Atal'Hakkar: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-temple-of-atal-hakkar"
	g.next  = "obvi-blackrock-depths"
	g.only  = "Alliance"

	local n = npcs(g)
	local brohann = g.Npc("Brohann Caskbelly", 5384)

	kalimdor(g, n, 3445, function(s)
		s:Goto(FERALAS, 31.8, 45.6)
		s:Talk(g.Npc("Angelas Moonbreeze", 7900))
		s:Accept(3445, "The Sunken Temple")
		s:Note("In Feathermoon Stronghold, inside the building. The screechers are on the mainland.")
	end)

	-- the Eastern Kingdoms: Stormwind on the way to the Hinterlands
	g:Step(function(s)
		s.only = "not done 1469 and not onquest 1475 and not done 1475"
		s:Do("Into The Temple of Atal'Hakkar needs Brohann Caskbelly's earlier chain (In Search of The Temple up to Rhapsody's Tale). Do that first, or tick this to leave it out.")
	end)

	g:Step(function(s)
		s.only = "done 1469 or onquest 1475 or done 1475"
		s:Goto(STORMWIND, 69.4, 40.4)
		s:Talk(brohann)
		s:Accept(1475, "Into The Temple of Atal'Hakkar")
		s:Note("In the Explorers' League building in the Dwarven District. Then fly to Aerie Peak.")
	end)

	g:Step(function(s)
		exileStep(s, n)
		s:Accept(1446, "Jammal'an the Prophet")
		s:Note("Up the stairs west of Jintha'Alor and down onto his ledge.")
	end)

	egg(g)
	hakkar(g, n)

	-- the tablets lie in the sunken ruins, before the instance door
	g:Step(function(s)
		s.only = "onquest 1475 or done 1475"
		s:Goto(SWAMP, 74.7, 46.7)
		s:Collect(g.Item("Atal'ai Tablet", 6288), { count = 10, quest = 1475, objective = 1 })
		s:Note("The silver ", g.Object("Atal'ai Tablet"), " slabs against the walls of the sunken ruins, on the way down to the instance.")
	end)

	temple(g)

	-- the turn-ins: Stormwind, the Hinterlands, Tanaris
	g:Step(function(s)
		s.label = "out"
		s.only = "onquest 1475 or done 1475"
		s:Goto(STORMWIND, 69.4, 40.4)
		s:Talk(brohann)
		s:Turnin(1475, "Into The Temple of Atal'Hakkar")
	end)

	g:Step(function(s)
		exileStep(s, n)
		s:Turnin(1446, "Jammal'an the Prophet")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(n.yeh)
		s:Turnin(3528, "The God Hakkar")
	end)
end)

-- Horde ----------------------------------------------------------------------------------------------------------

ObviGuide.Guide(function(g)
	g.title = "The Temple of Atal'Hakkar: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-temple-of-atal-hakkar-horde"
	g.next  = "obvi-blackrock-depths-horde"
	g.only  = "Horde"

	local n = npcs(g)
	local felzerul = g.Npc("Fel'zerul", 1443)

	kalimdor(g, n, 3380, function(s)
		s:Goto(FERALAS, 74.4, 43.4)
		s:Talk(g.Npc("Witch Doctor Uzer'i", 8115))
		s:Accept(3380, "The Sunken Temple")
		s:Note("In Camp Mojache.")
	end)

	-- the Eastern Kingdoms: Stonard and the Pool of Tears, then the Hinterlands
	g:Step(function(s)
		s:Goto(SWAMP, 47.9, 54.8)
		s:Talk(felzerul)
		s:Accept(1424, "Pool of Tears")
		s:Note("Inside the big hall in Stonard.")
	end)

	g:Step(function(s)
		s:Goto(SWAMP, 70.6, 56.6)
		s:Collect(g.Item("Atal'ai Artifact", 6175), { count = 10, quest = 1424, objective = 1 })
		s:Note("Small objects on the bottom of the Pool of Tears, all around the sunken temple. Water breathing helps.")
	end)

	g:Step(function(s)
		s:Goto(SWAMP, 47.9, 54.8)
		s:Talk(felzerul)
		s:Turnin(1424, "Pool of Tears")
		s:Accept(1429, "The Atal'ai Exile")
		s:Note("Then fly to Revantusk Village.")
	end)

	g:Step(function(s)
		exileStep(s, n)
		s:Turnin(1429, "The Atal'ai Exile")
		s:Accept(1444, "Return to Fel'Zerul")
		s:Accept(1446, "Jammal'an the Prophet")
		s:Note("Up the stairs west of Jintha'Alor and down onto his ledge.")
	end)

	egg(g)
	hakkar(g, n)

	g:Step(function(s)
		s:Goto(SWAMP, 47.9, 54.8)
		s:Talk(felzerul)
		s:Turnin(1444, "Return to Fel'Zerul")
		s:Accept(1445, "The Temple of Atal'Hakkar")
	end)

	temple(g, function()
		g:Side("out", function(s)
			s:Kill(g.Mob("Atal'ai Warrior", 5256))
			s:Kill(g.Mob("Atal'ai Priest", 5269))
			s:Collect(g.Item("Fetish of Hakkar", 6181), { count = 20, quest = 1445, objective = 1 })
			s:Note("From the Atal'ai trolls throughout the temple.")
		end)
	end)

	-- the turn-ins: Stonard, the Hinterlands, Tanaris
	g:Step(function(s)
		s.label = "out"
		s:Goto(SWAMP, 47.9, 54.8)
		s:Talk(felzerul)
		s:Turnin(1445, "The Temple of Atal'Hakkar")
	end)

	g:Step(function(s)
		exileStep(s, n)
		s:Turnin(1446, "Jammal'an the Prophet")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(n.yeh)
		s:Turnin(3528, "The God Hakkar")
	end)
end)
