-- Blackfathom Deeps (25-28): the quests Attune and DungeonJournal (Exehn) list for each faction. Alliance: Knowledge in
-- the Deeps, Researching the Corruption with The Corruption Abroad from Stormwind before it, Twilight Falls, and
-- Blackfathom Villainy with its lead-in from Darnassus. Horde: Trouble in the Deeps and The Essence of Aku'Mai, Amongst
-- the Ruins, Allegiance to the Old Gods from the Damp Note, Baron Aquanis, and Blackfathom Villainy. Quest, NPC and item
-- ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance from DungeonJournal. See
-- README.md.

local ASHENVALE, DARKSHORE, DARNASSUS, IRONFORGE = 1440, 1439, 1457, 1455
local STONETALON, THUNDER_BLUFF, STORMWIND = 1442, 1456, 1453

-- the entrance: dive into the water on the Zoram Strand and swim into the cave, through it to the portal
local function enter(s, skip)
	s.skip = skip   -- (been inside already)
	s:Goto(ASHENVALE, 14.5, 14.2)
	s:Do("Enter Blackfathom Deeps with your group.")
	s:Note("The entrance is under the water.")
end

-- inside: the parts both factions share
local function thaelrid(g, s)
	s:Talk(g.Npc("Argent Guard Thaelrid", 4787))
	s:Note("In an underwater cave off the Pool of Ask'ar.")
end

local function kelris(g, s, quest)
	s:Kill(g.Mob("Twilight Lord Kelris", 4832))
	s:Collect(g.Item("Head of Kelris", 5881), { quest = quest, objective = 1 })
end

-- paladins: the Corrupted Kor Gem, from the naga in the cave before the portal (the Sea Witches inside drop it too)
local function kor(g, s)
	s:Goto(ASHENVALE, 13.6, 13.1)
	s:Kill(g.Mob("Blackfathom Tide Priestess", 4802))
	s:Kill(g.Mob("Blackfathom Oracle"))
end

-- warlocks on The Orb of Soran'ruk: the small fragments (the large one is in Shadowfang Keep)
local function soranruk(g)
	g:Side("out", function(s)
		s.only = "onquest 1740"
		s:Kill(g.Mob("Twilight Acolyte", 4809))
		s:Collect(g.Item("Soran'ruk Fragment", 6914), { count = 3, quest = 1740, objective = 1 })
	end)
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
	local thundris = g.Npc("Thundris Windweaver", 3649)

	-- Ironforge and Stormwind, then the boat from Menethil to Auberdine, and Darnassus
	g:Step(function(s)
		s:Goto(IRONFORGE, 50.8, 5.6)
		s:Talk(gerrig)
		s:Accept(971, "Knowledge in the Deeps")
	end)

	-- The Corruption Abroad only leads to Gershala, who gives her quest without it
	g:Step(function(s)
		s.skip = "onquest 1275 or done 1275"
		s:Goto(STORMWIND, 36.2, 67.6)
		s:Talk(g.Npc("Argos Nightwhisper", 4984))
		s:Accept(3765, "The Corruption Abroad")
	end)

	g:Step(function(s)
		s:Goto(DARKSHORE, 38.3, 43.0)
		s:Talk(gershala)
		s:Turnin(3765, "The Corruption Abroad"):Only("onquest 3765")
		s:Accept(1275, "Researching the Corruption")
	end)

	-- Paladins on The Test of Righteousness (Verigan's Fist): the Kor Gem
	g:Step(function(s)
		s.only = "Paladin and onquest 1654"
		s:Goto(DARKSHORE, 37.4, 40.1)
		s:Talk(thundris)
		s:Accept(1442, "Seeking the Kor Gem")
	end)

	g:Step(function(s)
		s:Goto(DARNASSUS, 55.2, 24.0)
		s:Talk(manados)
		s:Accept(1199, "Twilight Falls")
		s:Talk(g.Npc("Dawnwatcher Shaedlass", 4786))
		s:Accept(1198, "In Search of Thaelrid")
	end)

	g:Step(function(s)
		s.only = "onquest 1442"
		kor(g, s)
		s:Collect(g.Item("Corrupted Kor Gem", 6995), { quest = 1442, objective = 1 })
	end)

	g:Step(function(s) enter(s, "ready 1275 or done 1275") end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Twilight Acolyte", 4809))
		s:Kill(g.Mob("Twilight Reaver", 4810))
		s:Collect(g.Item("Twilight Pendant", 5879), { count = 10, quest = 1199, objective = 1 })
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Blackfathom Myrmidon", 4807))
		s:Kill(g.Mob("Fallenroot Shadowstalker", 4798))
		s:Collect(g.Item("Corrupted Brain Stem", 5952), { count = 8, quest = 1275, objective = 1 })
	end)

	soranruk(g)

	g:Step(function(s)
		s:Collect(g.Item("Lorgalis Manuscript", 5359), { quest = 971, objective = 1 })
		s:Note("In a ", g.Object("Pitted Iron Chest"), " under the water in the Pool of Ask'ar.")
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
		s.only = "onquest 1442"
		s:Goto(DARKSHORE, 37.4, 40.1)
		s:Talk(thundris)
		s:Turnin(1442, "Seeking the Kor Gem")
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
	local ulric = g.Npc("Ulric Frostveil")

	g:Step(function(s)
		s:Goto(STONETALON, 47.4, 64.3)
		s:Talk(g.Npc("Tsunaman", 11862))
		s:Accept(6562, "Trouble in the Deeps")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 11.6, 34.3)
		s:Talk(jeneu)
		s:Turnin(6562, "Trouble in the Deeps")
		s:Accept(6563, "The Essence of Aku'Mai")
		s:Accept(6921, "Amongst the Ruins")
	end)

	-- Paladins on A Moon-Kissed Blade (Wolfsbane): the Kor Gem
	g:Step(function(s)
		s.only = "Paladin and onquest 95036"
		s:Goto(ASHENVALE, 11.8, 34.6)
		s:Talk(ulric)
		s:Accept(95042, "Seeking the Kor Gem")
	end)

	-- the cave before the portal: the sapphires and the Damp Note
	g:Step(function(s)
		s:Goto(ASHENVALE, 13.6, 13.1)
		s:Collect(g.Item("Sapphire of Aku'Mai", 16784), { count = 20, quest = 6563, objective = 1 })
		s:Note("Blue crystals on the cave walls.")
	end)

	g:Step(function(s)
		s.skip = "onquest 6564 or done 6564"
		s:Goto(ASHENVALE, 13.6, 12.1)
		s:Kill(g.Mob("Blackfathom Tide Priestess", 4802))
		s:Note("Until one drops a ", note, ".")
		s:Use(note)
		s:Accept(6564, "Allegiance to the Old Gods")
	end)

	g:Step(function(s)
		s.only = "onquest 95042"
		kor(g, s)
		s:Quest(95042, 1, "Get a Corrupted Kor Gem.")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 11.6, 34.3)
		s:Talk(jeneu)
		s:Turnin(6564, "Allegiance to the Old Gods")
		s:Accept(6565, "Allegiance to the Old Gods")
	end)

	g:Step(function(s) enter(s, "ready 6565 or done 6565") end)

	soranruk(g)

	g:Step(function(s)
		thaelrid(g, s)
		s:Accept(6561, "Blackfathom Villainy")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lorgus Jett", 12902), { quest = 6565, objective = 1 })
		s:Note("Walks around south of the Pool of Ask'ar.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Fathom Core", 16762), { quest = 6921, objective = 1 })
		s:Note("From the ", g.Object("Fathom Stone"), " under the water in the Moonshrine Ruins. Clicking it brings out Baron Aquanis.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Baron Aquanis", 12876))
		s:Use(globe):Only("not onquest 6922 and not done 6922")
		s:Accept(6922, "Baron Aquanis")
	end)

	g:Step(function(s)
		kelris(g, s, 6561)
	end)

	-- the turn-ins
	g:Step(function(s)
		s.label = "out"
		s:Goto(ASHENVALE, 11.6, 34.3)
		s:Talk(jeneu)
		s:Turnin(6563, "The Essence of Aku'Mai")
		s:Turnin(6565, "Allegiance to the Old Gods")
		s:Turnin(6921, "Amongst the Ruins")
		s:Turnin(6922, "Baron Aquanis"):Only("onquest 6922")
	end)

	g:Step(function(s)
		s.only = "onquest 95042"
		s:Goto(ASHENVALE, 11.8, 34.6)
		s:Talk(ulric)
		s:Turnin(95042, "Seeking the Kor Gem")
	end)

	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 71.1, 34.2)
		s:Talk(g.Npc("Bashana Runetotem", 9087))
		s:Turnin(6561, "Blackfathom Villainy")
	end)
end)
