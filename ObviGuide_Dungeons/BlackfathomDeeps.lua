-- Blackfathom Deeps (25-28): the quests Attune lists for each faction. Alliance: Knowledge in the Deeps, Researching
-- the Corruption, Twilight Falls, and Blackfathom Villainy with its lead-in from Darnassus. Horde: Trouble in the
-- Deeps and The Essence of Aku'Mai, Amongst the Ruins, Allegiance to the Old Gods from the Damp Note, Baron Aquanis,
-- and Blackfathom Villainy. Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever
-- data; the entrance from DungeonJournal (Exehn). See README.md.

local ASHENVALE, DARKSHORE, DARNASSUS, IRONFORGE = 1440, 1439, 1457, 1455
local STONETALON, THUNDER_BLUFF = 1442, 1456

-- the entrance: dive into the water on the Zoram Strand and swim into the cave, through it to the portal
local function enter(s, skip)
	s.skip = skip   -- (been inside already)
	s:Goto(ASHENVALE, 14.5, 14.2)
	s:Do("Enter Blackfathom Deeps with your group.")
	s:Note("On the Zoram Strand: dive into the water by the ruined temple, swim into the underwater cave and follow it to the portal.")
end

-- inside: the parts both factions share
local function thaelrid(g, s)
	s:Talk(g.Npc("Argent Guard Thaelrid", 4787))
	s:Note("Lying in an underwater cave off the south-west of the Pool of Ask'ar, the big cavern past Gamoo-ra.")
end

local function kelris(g, s, quest)
	s:Kill(g.Mob("Twilight Lord Kelris", 4832))
	s:Collect(g.Item("Head of Kelris", 5881), { quest = quest, objective = 1 })
	s:Note("Past the Moonshrine Ruins, in the Moonshrine Sanctum.")
end

ObviGuide.Guide(function(g)
	g.title = "Blackfathom Deeps: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-blackfathom-deeps"
	g.next  = "obvi-stockade"
	g.only  = "Alliance"

	local gerrig   = g.Npc("Gerrig Bonegrip", 2786)
	local gershala = g.Npc("Gershala Nightwhisper", 8997)
	local manados  = g.Npc("Argent Guard Manados", 4784)

	-- Ironforge, then the boat from Menethil to Auberdine, and Darnassus
	g:Step(function(s)
		s:Goto(IRONFORGE, 50.8, 5.6)
		s:Talk(gerrig)
		s:Accept(971, "Knowledge in the Deeps")
		s:Note("In the Forlorn Cavern, inside the building up the stairs. Then fly to Menethil Harbor and take the boat to Auberdine.")
	end)

	g:Step(function(s)
		s:Goto(DARKSHORE, 38.3, 43.0)
		s:Talk(gershala)
		s:Accept(1275, "Researching the Corruption")
		s:Note("In Auberdine. Then the boat to Rut'theran Village and the portal up to Darnassus.")
	end)

	g:Step(function(s)
		s:Goto(DARNASSUS, 55.2, 24.0)
		s:Talk(manados)
		s:Accept(1199, "Twilight Falls")
		s:Talk(g.Npc("Dawnwatcher Shaedlass", 4786))
		s:Accept(1198, "In Search of Thaelrid")
		s:Note("Both up the ramp, inside the Argent Dawn building on the Terrace of Warriors. In Search of Thaelrid leads to Blackfathom Villainy.")
	end)

	g:Step(function(s) enter(s, "ready 1275 or done 1275") end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Twilight Acolyte", 4809))
		s:Kill(g.Mob("Twilight Reaver", 4810))
		s:Collect(g.Item("Twilight Pendant", 5879), { count = 10, quest = 1199, objective = 1 })
		s:Note("From the Twilight cultists.")
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Blackfathom Myrmidon", 4807))
		s:Kill(g.Mob("Fallenroot Shadowstalker", 4798))
		s:Collect(g.Item("Corrupted Brain Stem", 5952), { count = 8, quest = 1275, objective = 1 })
		s:Note("From the naga and the Fallenroot satyrs.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Lorgalis Manuscript", 5359), { quest = 971, objective = 1 })
		s:Note("In a ", g.Object("Pitted Iron Chest"), " under the water at the north end of the Pool of Ask'ar, the cavern where Gamoo-ra is.")
	end)

	g:Step(function(s)
		thaelrid(g, s)
		s:Turnin(1198, "In Search of Thaelrid"):Only("onquest 1198")
		s:Accept(1200, "Blackfathom Villainy")
	end)

	g:Step(function(s)
		kelris(g, s, 1200)
	end)

	-- the turn-ins, the way you came: Auberdine, Darnassus, Ironforge
	g:Step(function(s)
		s.label = "out"
		s:Goto(DARKSHORE, 38.3, 43.0)
		s:Talk(gershala)
		s:Turnin(1275, "Researching the Corruption")
	end)

	g:Step(function(s)
		s:Goto(DARNASSUS, 55.2, 24.0)
		s:Talk(manados)
		s:Turnin(1199, "Twilight Falls")
	end)

	g:Step(function(s)
		s.only = "onquest 1200 or done 1200"
		s:Goto(DARNASSUS, 56.2, 24.4)
		s:Talk(g.Npc("Dawnwatcher Selgorm", 4783))
		s:Turnin(1200, "Blackfathom Villainy")
		s:Note("In the same building.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 50.8, 5.6)
		s:Talk(gerrig)
		s:Turnin(971, "Knowledge in the Deeps")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Blackfathom Deeps: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-blackfathom-deeps-horde"
	g.next  = "obvi-dalaran-horde"
	g.only  = "Horde"

	local jeneu = g.Npc("Je'neu Sancrea", 12736)
	local note  = g.Item("Damp Note", 16790)
	local globe = g.Item("Strange Water Globe", 16782)

	g:Step(function(s)
		s:Goto(STONETALON, 47.4, 64.3)
		s:Talk(g.Npc("Tsunaman", 11862))
		s:Accept(6562, "Trouble in the Deeps")
		s:Note("At Sun Rock Retreat. The Damp Note's quest needs this one done first.")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 11.6, 34.3)
		s:Talk(jeneu)
		s:Turnin(6562, "Trouble in the Deeps")
		s:Accept(6563, "The Essence of Aku'Mai")
		s:Accept(6921, "Amongst the Ruins")
		s:Note("Inside the building at Zoram'gar Outpost.")
	end)

	-- the cave before the portal: the sapphires and the Damp Note
	g:Step(function(s)
		s:Goto(ASHENVALE, 13.6, 13.1)
		s:Collect(g.Item("Sapphire of Aku'Mai", 16784), { count = 20, quest = 6563, objective = 1 })
		s:Note("Blue crystals on the walls of the underwater cave leading to the dungeon.")
	end)

	g:Step(function(s)
		s.skip = "onquest 6564 or done 6564"
		s:Goto(ASHENVALE, 13.6, 12.1)
		s:Kill(g.Mob("Blackfathom Tide Priestess", 4802))
		s:Note("In the same cave, until one drops a ", note, "; it doesn't always drop.")
		s:Use(note)
		s:Accept(6564, "Allegiance to the Old Gods")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 11.6, 34.3)
		s:Talk(jeneu)
		s:Turnin(6564, "Allegiance to the Old Gods")
		s:Accept(6565, "Allegiance to the Old Gods")
		s:Note("Back to Zoram'gar; the dungeon is a short ride north again.")
	end)

	g:Step(function(s) enter(s, "ready 6565 or done 6565") end)

	g:Step(function(s)
		thaelrid(g, s)
		s:Accept(6561, "Blackfathom Villainy")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lorgus Jett", 12902), { quest = 6565, objective = 1 })
		s:Note("South from the Pool of Ask'ar, then left: he's in one of the nooks on the west side, or further south along the path.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Fathom Core", 16762), { quest = 6921, objective = 1 })
		s:Note("From the ", g.Object("Fathom Stone"), " under the water in the middle of the Moonshrine Ruins, below the walkway before Kelris. Clicking it brings out Baron Aquanis.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Baron Aquanis", 12876))
		s:Use(globe):Only("not onquest 6922 and not done 6922")
		s:Accept(6922, "Baron Aquanis")
		s:Note("He drops the ", globe, ": it starts the quest.")
	end)

	g:Step(function(s)
		kelris(g, s, 6561)
	end)

	-- the turn-ins
	g:Step(function(s)
		s:Goto(ASHENVALE, 11.6, 34.3)
		s:Talk(jeneu)
		s:Turnin(6563, "The Essence of Aku'Mai")
		s:Turnin(6565, "Allegiance to the Old Gods")
		s:Turnin(6921, "Amongst the Ruins")
		s:Turnin(6922, "Baron Aquanis"):Only("onquest 6922")
	end)

	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 71.1, 34.2)
		s:Talk(g.Npc("Bashana Runetotem", 9087))
		s:Turnin(6561, "Blackfathom Villainy")
		s:Note("On the Elder Rise.")
	end)
end)
