-- Scarlet Monastery (28-40): the quests Attune and DungeonJournal (Exehn) list for each faction. Alliance: Brother
-- Anton and both Down the Scarlet Path quests up to In the Name of the Light, Mythology of the Titans, and Past Due
-- (Magus Olvek, Dalaran), and for paladins Katherine the Pure's chain from the Strange Orb to Aeonas the Vindicated. Horde: Into The Scarlet Monastery, Compendium of the Fallen, Vorrel's Revenge, Hearts of Zeal
-- (after Going, Going, Guano! from Razorfen Kraul), and the Test of Faith, Endurance, Strength and Lore chain that ends
-- in the Library, then Final Passage back to Dorn Plainstalker. Both: the parts done here of the rogues' Eye of
-- Bhossca and the mages' Rituals of Power (Zygor's Mage class guide). Quest,
-- NPC, item and object ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance and the
-- Forever quests from DungeonJournal (Exehn). See README.md.

local TIRISFAL, STORMWIND, IRONFORGE, DESOLACE, HILLSBRAD = 1420, 1453, 1455, 1443, 1424
local UNDERCITY, THUNDERBLUFF, BARRENS, NEEDLES, STONETALON, ASHENVALE, ALTERAC = 1458, 1456, 1413, 1441, 1442, 1440, 1416
local DARKSHORE, WETLANDS, STEPPES = 1439, 1437, 1428

-- the monastery has four wings, each its own instance behind its own door in the same building
local function wing(g, name, skip, note)
	g:Step(function(s)
		s:Goto(TIRISFAL, 82.6, 33.0)
		if skip then s.skip = skip end   -- (been inside already)
		s:Do("Enter the ", name, " with your group.")
		s:Note(note)
	end)
end

-- rogues on The Eye of Bhossca (C's job, done alone): the Graveyard, then the Library. From DungeonJournal (Exehn).
local function bhossca(g)
	g:Side("out", function(s)
		s.only = "onquest 78676"
		local later = "items 210953 >= 1 or ready 78676"
		s:Collect(g.Item("Scarlet Initiate's Uniform", 210955))
		s:Note("Alone, outside a group. In the ", g.Object("Supply Locker"), " in the stables behind the monastery. Wear it in every wing: stealth or attacking takes it off.")
		s:Collect(g.Item("Scryer's Key", 210963)):Done("items 210967 >= 1 or " .. later)
		s:Note("Pick pocket a Scarlet Scryer in the Graveyard's first big room.")
		s:Collect(g.Item("Reliquary Key", 210968)):Done(later)
		s:Note("In the ", g.Object("Stone Coffer"), " in the mausoleum on the Graveyard's north side: sit on both benches between the two statues first.")
		s:Collect(g.Item("Confidential Message", 210967)):Done(later)
		s:Note("In the ", g.Object("Personal Letterbox"), " in Arcanist Doan's room in the Library.")
		s:Collect(g.Item("Eye of Bhossca", 210953))
		s:Note("In the ", g.Object("Padlocked Reliquary"), " in the Library's first small room on the left.")
	end)
end

-- mages on Rituals of Power, in the Library
local function rituals(g)
	g:Step(function(s)
		s.only = "onquest 1951"
		s:Collect(g.Item("Rituals of Power", 7274), { quest = 1951, objective = 1 })
		s:Note("Click the book on the bookshelf left of the Athenaeum's doorway.")
	end)
end

ObviGuide.Guide(function(g)
	g.title = "Scarlet Monastery: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-scarlet-monastery"
	g.next  = "obvi-razorfen-downs"
	g.only  = "Alliance"

	local mae     = g.Npc("Librarian Mae Paledust", 3979)
	local anton   = g.Npc("Brother Anton", 1182)
	local raleigh = g.Npc("Raleigh the Devout", 3980)
	local olvek   = g.Npc("Magus Olvek", 264265)
	local aeonas  = g.Npc("Aeonas")

	-- Stormwind and Ironforge
	g:Step(function(s)
		s:Goto(STORMWIND, 52.6, 43.2)
		s:Talk(g.Npc("Brother Crowley", 12336))
		s:Accept(6141, "Brother Anton")
		s:Note("In the Cathedral of Light. The Scarlet Path chain needs level 34.")
	end)

	-- Paladins: Katherine the Pure's chain, from the Strange Orb in Darkshore to A Brother In Need, which leads to
	-- Aeonas in the Cathedral. Each step goes once its quest is done. From DungeonJournal (Exehn); NPC ids and Stormwind
	-- positions from QuestieDB's Forever data.
	local delgren   = g.Npc("Delgren the Purifier", 3663)
	local katherine = g.Npc("Katherine the Pure", 5492)
	local ursula    = g.Npc("Ursula Deline", 5495)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(DARKSHORE, 56.2, 26.4)
		s:Say("Click the ", g.Object("Strange Orb"), ".")
		s:Accept(78088, "A Strange Artifact")
		s:Note("On top of the Tower of Althalaxx.")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(ASHENVALE, 26.2, 38.7)
		s:Talk(delgren)
		s:Turnin(78088, "A Strange Artifact")
		s:Accept(78089, "Advice From Stormwind")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Turnin(78089, "Advice From Stormwind")
		s:Accept(78090, "A Second Opinion")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(STORMWIND, 39.3, 84.9)
		s:Talk(ursula)
		s:Turnin(78090, "A Second Opinion")
		s:Accept(78091, "Earning Your Salt")
		s:Note("In the Slaughtered Lamb's cellar.")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(STEPPES, 71.9, 85.7)
		s:Kill(g.Mob("Blackrock Summoner", 4463))
		s:Kill(g.Mob("Blackrock Champion", 435))
		s:Collect(g.Item("Summoner's Salt"), { count = 14, quest = 78091, objective = 1 })
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(STORMWIND, 39.3, 84.9)
		s:Talk(ursula)
		s:Turnin(78091, "Earning Your Salt")
		s:Accept(78092, "It Must Be Destroyed")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(ASHENVALE, 89.0, 77.0)
		s:Kill(g.Mob("Mannoroc Lasher", 11697))
		s:Kill(g.Mob("Searing Infernal"))
		s:Collect(g.Item("Mote of Mannoroth"), { count = 12, quest = 78092, objective = 1 })
		s:Note("From the demons in Demon Fall Canyon.")
	end)

	-- the spear takes the motes and the orb; the orb's fragments stay behind
	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(ASHENVALE, 89.0, 77.0)
		s:Say("Click the ", g.Object("Spear of Mannoroth"), ".")
		s:Turnin(78092, "It Must Be Destroyed")
		s:Say("Click the ", g.Object("Shattered Orb"), ".")
		s:Accept(78093, "Return to Delgren")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(ASHENVALE, 26.2, 38.7)
		s:Talk(delgren)
		s:Turnin(78093, "Return to Delgren")
	end)

	-- level 35 from here
	g:Step(function(s)
		s.only = "Paladin and not done 79939"
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Accept(96438, "Battle at the Mannoroc Coven")
		s:Note("Needs level 35.")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(DESOLACE, 52.7, 84.8)
		s:Say("Click the ", g.Object("Broken Warhammer"), ".")
		s:Turnin(96438, "Battle at the Mannoroc Coven"):Only("not done 79939")
		s:Accept(79939, "The Broken Hammer")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(DESOLACE, 52.7, 84.8)
		s:Kill(g.Mob("Burning Blade Summoner", 4668))
		s:Collect(g.Item("Torn Letter"), { quest = 79939, objective = 1 })
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Turnin(79939, "The Broken Hammer")
		s:Accept(79940, "A Lost Brother")
		s:Turnin(79940, "A Lost Brother")
		s:Note("Let her finish talking.")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(WETLANDS, 8.1, 58.5)
		s:Do("Inspect the fallen Scarlet Crusader, then kill the assassin."):Done("onquest 79945 or done 79945")
		s:Note("At Aeonas's hut: the small boat south of Menethil's docks. The assassin is a level 40 elite.")
		s:Accept(79945, "Orders from the Grand Crusader")
		s:Note("Use the orders it drops.")
	end)

	g:Step(function(s)
		s.only = "Paladin"
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Turnin(79945, "Orders from the Grand Crusader")
		s:Accept(79946, "A Brother In Need")
		s:Note("Let her finish talking about Aeonas.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 75.0, 12.5)
		s:Talk(mae)
		s:Accept(1050, "Mythology of the Titans")
		s:Note("In the Hall of Explorers.")
	end)

	-- Desolace: Nijel's Point, and the Valley of Bones in the south
	g:Step(function(s)
		s:Goto(DESOLACE, 66.5, 7.9)
		s:Talk(anton)
		s:Turnin(6141, "Brother Anton")
		s:Accept(261, "Down the Scarlet Path")
		s:Note("At Nijel's Point, in the north of Desolace; it has a flight path.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 59.6, 88.2)
		s:Kill(g.Mob("Undead Ravager", 11561), { quest = 261, objective = 1 })
		s:Note("All over the Valley of Bones, in the far south of Desolace.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 66.5, 7.9)
		s:Talk(anton)
		s:Turnin(261, "Down the Scarlet Path")
		s:Accept(1052, "Down the Scarlet Path")
	end)

	-- Southshore
	g:Step(function(s)
		s:Goto(HILLSBRAD, 51.5, 58.4)
		s:Talk(raleigh)
		s:Turnin(1052, "Down the Scarlet Path")
		s:Accept(1053, "In the Name of the Light")
		s:Note("In Southshore. Then north to Dalaran.")
	end)

	-- Dalaran, on the way north
	g:Step(function(s)
		s:Goto(ALTERAC, 9.5, 62.3)
		s:Talk(olvek)
		s:Accept(96800, "Past Due")
		s:Note("At Dalaran. Then the long ride north to the monastery, in the far north-east of Tirisfal Glades.")
	end)

	bhossca(g)

	-- the Library first: Loksey, the book, and the Scarlet Key for the last two wings
	wing(g, "Library", "items 5536 >= 1 or done 1050", "The monastery building is in north-east Tirisfal; each wing has its own door inside.")

	g:Step(function(s)
		s:Kill(g.Mob("Houndmaster Loksey", 3974), { quest = 1053, objective = 4 })
		s:Note("The first boss, in the Huntsman's Cloister.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Mythology of the Titans", 5536), { quest = 1050, objective = 1 })
		s:Note("A book lying in the Library wing, on the way to Arcanist Doan: watch the floor.")
	end)

	rituals(g)

	g:Step(function(s)
		s.skip = "items 7146 >= 1"
		s:Kill(g.Mob("Arcanist Doan", 6487))
		s:Collect(g.Item("Scarlet Key", 7146))
		s:Note("In the strongbox behind him.")
		s:Note("The last boss of the Library. The key opens the Armory and the Cathedral: one in the group is enough.")
	end)

	g:Step(function(s)
		s.only = "onquest 96800"
		s:Collect(g.Item("The Lost Magic of the Runemasters", 273169), { quest = 96800, objective = 1 })
		s:Note("Arcanist Doan holds the book.")
	end)

	wing(g, "Armory", "ready 1053 or done 1053", "Its door needs the Scarlet Key.")

	g:Step(function(s)
		s:Kill(g.Mob("Herod", 3975), { quest = 1053, objective = 3 })
		s:Note("The last boss of the Armory, in the big hall at the end.")
	end)

	wing(g, "Cathedral", "(ready 1053 or done 1053) and not onquest 79946 and not onquest 79963",
		"Its door needs the Scarlet Key too.")

	g:Step(function(s)
		s:Kill(g.Mob("Scarlet Commander Mograine", 3976), { quest = 1053, objective = 2 })
		s:Kill(g.Mob("High Inquisitor Whitemane", 3977), { quest = 1053, objective = 1 })
		s:Note("At the far end of the Cathedral. Whitemane comes in when Mograine falls, and raises him once.")
	end)

	-- Paladins: Aeonas waits in the Cathedral's rear chamber
	g:Step(function(s)
		s.only = "Paladin and (onquest 79946 or onquest 79963 or done 79946)"
		s:Talk(aeonas)
		s:Turnin(79946, "A Brother In Need")
		s:Accept(79963, "By The Light's Grace")
		s:Quest(79963, 1, "Heal ", aeonas, " to full health.")
		s:Turnin(79963, "By The Light's Grace")
		s:Accept(79970, "Aeonas the Vindicated")
		s:Note("In the rear chamber of the Cathedral.")
	end)

	-- out: Dalaran on the way back to Southshore
	g:Step(function(s)
		s.only = "onquest 96800 or done 96800"
		s:Goto(ALTERAC, 9.5, 62.3)
		s:Talk(olvek)
		s:Turnin(96800, "Past Due")
	end)

	g:Step(function(s)
		s.label = "out"
		s:Goto(HILLSBRAD, 51.5, 58.4)
		s:Talk(raleigh)
		s:Turnin(1053, "In the Name of the Light")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 75.0, 12.5)
		s:Talk(mae)
		s:Turnin(1050, "Mythology of the Titans")
	end)

	g:Step(function(s)
		s.only = "Paladin and (onquest 79970 or done 79970)"
		s:Goto(STORMWIND, 48.6, 49.2)
		s:Talk(g.Npc("Aeonas the Vindicated"))
		s:Turnin(79970, "Aeonas the Vindicated")
		s:Note("Back in the Cathedral of Light: Pauldrons of Vindication. The chain goes on from him with Some Good News at level 45.")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Scarlet Monastery: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-scarlet-monastery-horde"
	g.next  = "obvi-razorfen-downs-horde"
	g.only  = "Horde"

	local faranell = g.Npc("Master Apothecary Faranell", 2055)
	local vari     = g.Npc("Varimathras", 2425)
	local parqual  = g.Npc("Parqual Fintallas", 4488)
	local sage     = g.Npc("Sage Truthseeker", 3978)
	local dorn     = g.Npc("Dorn Plainstalker", 2986)
	local braug    = g.Npc("Braug Dimspirit", 4489)

	---------------------------------------------------------------------------------------------------------------
	-- Undercity: Going, Going, Guano! comes before Hearts of Zeal (skip this if you did it in Razorfen Kraul)
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s.only = "not done 1109"
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Accept(1109, "Going, Going, Guano!")
		s:Note("In the Apothecarium. Then take the zeppelin to Orgrimmar and fly to Thunder Bluff.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- Thunder Bluff
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s.only = "not Undead"
		s:Goto(THUNDERBLUFF, 34.4, 46.9)
		s:Talk(sage)
		s:Accept(1049, "Compendium of the Fallen")
		s:Note("Inside a building. Forsaken can't take this one.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- Razorfen Kraul: the guano, from the bats (fly to Camp Taurajo and ride south)
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s.only = "onquest 1109"
		s:Goto(BARRENS, 42.9, 90.2)
		s:Kill(g.Mob("Kraul Bat", 4538))
		s:Kill(g.Mob("Greater Kraul Bat", 4539))
		s:Collect(g.Item("Kraul Guano", 5801), { quest = 1109, objective = 1 })
		s:Note("Inside Razorfen Kraul, with a group: the bats there drop it. The Razorfen Kraul guide covers the rest of the dungeon.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- Thousand Needles: Dorn's Tests of Faith, Endurance and Strength
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s:Goto(NEEDLES, 53.9, 41.5)
		s:Talk(dorn)
		s:Accept(1149, "Test of Faith")
		s:Note("In a cave up the path on the mesa. Ask him to send you to the test.")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 26.4, 32.4)
		s:Quest(1149, 1, "Leap from the planks.")
		s:Note("He sends you up to a high plateau. Walk off the end of the planks: you won't die, and you land back with him.")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 53.9, 41.5)
		s:Talk(dorn)
		s:Turnin(1149, "Test of Faith")
		s:Accept(1150, "Test of Endurance")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 25.9, 54.8)
		s:Kill(g.Mob("Grenka Bloodscreech", 4490))
		s:Collect(g.Item("Grenka's Claw", 5843), { quest = 1150, objective = 1 })
		s:Note("In the harpy cave up the path around 27.3, 51.3. Click the ", g.Object("Harpy Foodstuffs"), " inside to call her out.")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 53.9, 41.5)
		s:Talk(dorn)
		s:Turnin(1150, "Test of Endurance")
		s:Accept(1151, "Test of Strength")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 17.1, 38.1)
		s:Kill(g.Mob("Rok'Alim the Pounder", 4499))
		s:Collect(g.Item("Fragments of Rok'Alim", 5844), { quest = 1151, objective = 1 })
		s:Note("He walks the canyon in the west, between about 26, 47 and 13, 26. He hits hard: bring a friend.")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 53.9, 41.5)
		s:Talk(dorn)
		s:Turnin(1151, "Test of Strength")
		s:Accept(1152, "Test of Lore")
		s:Note("Then on to Stonetalon: the Talondeep Path runs from there to Ashenvale.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- Stonetalon and Ashenvale: the Test of Lore, at both ends of the Talondeep Path
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s:Goto(STONETALON, 78.8, 45.7)
		s:Talk(braug)
		s:Turnin(1152, "Test of Lore")
		s:Accept(1154, "Test of Lore")
		s:Note("In a tent by the Stonetalon end of the Talondeep Path.")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 75.6, 74.4)
		s:Collect(g.Item("Legacy of the Aspects", 5860), { quest = 1154, objective = 1 })
		s:Note("Through the building around 76.0, 75.4 and down the path into the cave below; the book is inside, across a bridge.")
	end)

	g:Step(function(s)
		s:Goto(STONETALON, 78.8, 45.7)
		s:Talk(braug)
		s:Turnin(1154, "Test of Lore")
		s:Accept(6627, "Test of Lore")
		s:Quest(6627, 1, "Answer Braug's question.")
		s:Turnin(6627, "Test of Lore")
		s:Accept(1159, "Test of Lore")
		s:Note("If you get the answer wrong, take the quest from him again. Then head back to Undercity.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- Undercity: everything for the monastery itself
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s:Goto(UNDERCITY, 57.8, 65.4)
		s:Talk(parqual)
		s:Turnin(1159, "Test of Lore")
		s:Accept(1160, "Test of Lore")
		s:Note("On the bridge over the canal.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(1109, "Going, Going, Guano!")
		s:Accept(1113, "Hearts of Zeal")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 56.3, 92.2)
		s:Talk(vari)
		s:Accept(1048, "Into The Scarlet Monastery")
		s:Note("In the Royal Quarter. Then out to the monastery, in the far north-east of Tirisfal Glades.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- the monastery, wing by wing; the hearts drop all the way through
	---------------------------------------------------------------------------------------------------------------
	g:Side("out", function(s)
		s:Collect(g.Item("Heart of Zeal", 5805), { count = 20, quest = 1113, objective = 1 })
		s:Note("From the Scarlet Crusade in all four wings, and in the camps outside.")
	end)

	bhossca(g)

	wing(g, "Graveyard", "onquest 1051 or done 1051", "The monastery building is in north-east Tirisfal; each wing has its own door inside.")

	g:Step(function(s)
		s:Talk(g.Npc("Vorrel Sengutz", 3981))
		s:Accept(1051, "Vorrel's Revenge")
		s:Note("He lies on a table in the Chamber of Atonement, next to Interrogator Vishas. His ring is out in Alterac, not in here.")
	end)

	wing(g, "Library", "ready 1160 or done 1160", "Its door is next to the Graveyard's.")

	g:Step(function(s)
		s:Kill(g.Mob("Houndmaster Loksey", 3974), { quest = 1048, objective = 4 })
		s:Note("The first boss, in the Huntsman's Cloister.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Beginnings of the Undead Threat", 5861), { quest = 1160, objective = 1 })
		s:Note("An open book on a table, in the first room on the left in the Gallery of Treasures.")
	end)

	g:Step(function(s)
		s.only = "onquest 1049"
		s:Collect(g.Item("Compendium of the Fallen", 5535), { quest = 1049, objective = 1 })
		s:Note("On a bookcase along the left wall as you come into the Athenaeum.")
	end)

	rituals(g)

	g:Step(function(s)
		s.skip = "items 7146 >= 1"
		s:Kill(g.Mob("Arcanist Doan", 6487))
		s:Collect(g.Item("Scarlet Key", 7146))
		s:Note("In the strongbox behind him.")
		s:Note("The last boss of the Library. The key opens the Armory and the Cathedral: one in the group is enough.")
	end)

	wing(g, "Armory", "ready 1048 or done 1048", "Its door needs the Scarlet Key.")

	g:Step(function(s)
		s:Kill(g.Mob("Herod", 3975), { quest = 1048, objective = 3 })
		s:Note("The last boss of the Armory, in the big hall at the end.")
	end)

	wing(g, "Cathedral", "ready 1048 or done 1048", "Its door needs the Scarlet Key too.")

	g:Step(function(s)
		s:Kill(g.Mob("Scarlet Commander Mograine", 3976), { quest = 1048, objective = 2 })
		s:Kill(g.Mob("High Inquisitor Whitemane", 3977), { quest = 1048, objective = 1 })
		s:Note("At the far end of the Cathedral. Whitemane comes in when Mograine falls, and raises him once.")
	end)

	---------------------------------------------------------------------------------------------------------------
	-- out: Undercity, then Vorrel's ring in Alterac and Tarren Mill, then Thunder Bluff and Thousand Needles
	---------------------------------------------------------------------------------------------------------------
	g:Step(function(s)
		s.label = "out"
		s:Goto(UNDERCITY, 56.3, 92.2)
		s:Talk(vari)
		s:Turnin(1048, "Into The Scarlet Monastery")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(1113, "Hearts of Zeal")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 57.8, 65.4)
		s:Talk(parqual)
		s:Turnin(1160, "Test of Lore")
		s:Accept(6628, "Test of Lore")
		s:Quest(6628, 1, "Answer Parqual's question.")
		s:Turnin(6628, "Test of Lore")
		s:Accept(1394, "Final Passage")
		s:Note("If you get the answer wrong, take the quest from him again. Final Passage takes you back to Dorn in Thousand Needles for your reward. Then fly to Tarren Mill.")
	end)

	g:Step(function(s)
		s.only = "onquest 1051 or done 1051"
		s:Goto(ALTERAC, 32.3, 32.8)
		s:Kill(g.Mob("Nancy Vishas", 3984))
		s:Collect(g.Item("Vorrel's Wedding Ring", 5538), { quest = 1051, objective = 1 })
		s:Note("Inside the house. She may need a friend.")
	end)

	g:Step(function(s)
		s.only = "onquest 1051 or done 1051"
		s:Goto(HILLSBRAD, 62.7, 18.9)
		s:Talk(g.Npc("Monika Sengutz", 3982))
		s:Turnin(1051, "Vorrel's Revenge")
		s:Note("Inside a building in Tarren Mill.")
	end)

	g:Step(function(s)
		s.only = "onquest 1049 or done 1049"
		s:Goto(THUNDERBLUFF, 34.4, 46.9)
		s:Talk(sage)
		s:Turnin(1049, "Compendium of the Fallen")
		s:Note("It can wait for your next time in Thunder Bluff.")
	end)

	g:Step(function(s)
		s.only = "onquest 1394 or done 1394"
		s:Goto(NEEDLES, 53.9, 41.5)
		s:Talk(dorn)
		s:Turnin(1394, "Final Passage")
		s:Note("In his cave up the path on the mesa. It can wait too.")
	end)
end)
