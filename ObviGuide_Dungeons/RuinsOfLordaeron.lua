-- Ruins of Lordaeron (Alliance, 15-17): the four Alliance quests, all started inside, the turn-ins in Stormwind, and
-- the letter's follow-up in Duskwood.
-- Quest, NPC and item ids from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance, the way there and
-- where things are inside from DungeonJournal (Exehn). See README.md.

local TIRISFAL, STORMWIND, DUSKWOOD = 1420, 1453, 1431

ObviGuide.Guide(function(g)
	g.title = "Ruins of Lordaeron: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-ruins-of-lordaeron"
	g.next  = "obvi-deadmines"
	g.only  = "Alliance"

	local truman = g.Npc("Captain Truman", 265701)

	-- a long way for the Alliance: by boat to Southshore, then north past Dalaran and across the lake
	g:Step(function(s)
		s:Goto(TIRISFAL, 63.4, 67.4)
		s:Say("From Stormwind Harbor take the boat to Auberdine, then the ship that sails on via Menethil Harbor to Southshore.")
		s:Say("From Southshore go north past Dalaran, swim north across Lordamere Lake into Tirisfal Glades and follow the road to the ruins.")
		s:Note(g.Warn("Horde land: watch out for guards near Brill and the Undercity."))
	end)

	g:Step(function(s)
		s:Talk(truman)
		s:Accept(95250, "Abominable Creatures")
		s:Note("Just inside the entrance, on the left.")
	end)

	-- the quests that start from things found inside, done along the way up to The Baron and beyond
	g:Side("end", function(s)
		local insignia = g.Item("Bloodied Insignia", 268535)
		s:Use(insignia):Only("not onquest 95195 and not done 95195")
		s:Accept(95195, "Bloodied Insignia")
		s:Collect(g.Item("Bloodied Insignia", 268540), { count = 10, quest = 95195, objective = 1 })
		s:Note("The undead inside drop them; the first one starts the quest.")
	end)

	g:Side("end", function(s)
		local letter = g.Item("Blood-Stained Letter", 251522)
		s:Use(letter):Only("not onquest 92415 and not done 92415")
		s:Accept(92415, "Remember That I Love You")
		s:Note("The letter is found in the graveyard inside.")
	end)

	g:Side("end", function(s)
		local crest = g.Item("Crest of Lordaeron", 268579)
		s:Use(crest):Only("not onquest 95189 and not done 95189")
		s:Accept(95189, "Crest of Lordaeron")
		s:Note("It turns up in one of several spots: the upper floors of towers, side rooms near The Baron, or around Bjork.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("The Baron", 250660))
		s:Collect(g.Item("Head of the Baron", 268518), { quest = 95250, objective = 1 })
		s:Note("The second boss, in the indoor courtyard past Witherfang's hallway.")
	end)

	g:Step(function(s)
		s.label = "end"
		s:Talk(truman)
		s:Turnin(95250, "Abominable Creatures")
		s:Note("Back at the entrance.")
	end)

	-- Stormwind
	g:Step(function(s)
		s:Goto(STORMWIND, 69.2, 82.7)
		s:Talk(g.Npc("General Marcus Jonathan", 466))
		s:Turnin(95195, "Bloodied Insignia")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 56.3, 54.0)
		s:Talk(g.Npc("Orphan Matron Nightingale", 14450))
		s:Turnin(92415, "Remember That I Love You")
		s:Accept(95161, "Remember That I Love You")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 73.7, 46.5)
		s:Talk(g.Npc("Lady Dena Kennedy", 15991))
		s:Turnin(95189, "Crest of Lordaeron")
		s:Note("About here: her spot comes from another guide's map of Stormwind, converted to this one.")
	end)

	-- the letter goes on to Duskwood
	g:Step(function(s)
		s:Goto(DUSKWOOD, 73.0, 44.4)
		s:Talk(g.Npc("Avette Fellwood", 228))
		s:Turnin(95161, "Remember That I Love You")
		s:Note("In Darkshire.")
	end)
end)

-- Ruins of Lordaeron (Horde, 15-22): the quests Attune lists for the Horde. The New Plague and The Wrath of Rath'mael
-- are only offered after A Recipe For Death and Rear Guard Patrol, so both chains come first; then Light's Justice,
-- A Frightened Request, and Crest of Lordaeron and Unending Torment from drops inside, with the rest of Unending
-- Torment after it. Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data;
-- the entrance, Riptear's den and where things are inside from DungeonJournal (Exehn).

local UNDERCITY, SILVERPINE = 1458, 1421

ObviGuide.Guide(function(g)
	g.title = "Ruins of Lordaeron: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-ruins-of-lordaeron-horde"
	g.next  = "obvi-wailing-caverns-horde"
	g.only  = "Horde"

	local morbin    = g.Npc("Morbin Lightbane", 266484)
	local renferrel = g.Npc("Apothecary Renferrel", 1937)
	local faranell  = g.Npc("Master Apothecary Faranell", 2055)
	local tabitha   = g.Npc("Tabitha Heartweaver", 250686)
	local griffs    = g.Npc("Theodore Griffs", 11835)
	local linnea    = g.Npc("Deathguard Linnea", 1495)
	local kristof   = g.Npc("Deathguard Kristof", 251001)

	-- the Undercity: Light's Justice first, from the Royal Quarter
	g:Step(function(s)
		s:Goto(UNDERCITY, 58.1, 89.5)
		s:Talk(morbin)
		s:Accept(92421, "Light's Justice")
		s:Note("In the Royal Quarter.")
	end)

	-- the Sepulcher in Silverpine: the start of A Recipe For Death, and Tabitha's request
	g:Step(function(s)
		s:Goto(SILVERPINE, 42.8, 40.9)
		s:Talk(renferrel)
		s:Accept(447, "A Recipe For Death")
		s:Note("At the Sepulcher. Pick up the flight path here if you haven't got it.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 44.5, 43.0)
		s:Talk(tabitha)
		s:Accept(92401, "A Frightened Request")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 45.5, 50.0)
		s:Kill(g.Mob("Ferocious Grizzled Bear", 1778))
		s:Kill(g.Mob("Giant Grizzled Bear", 1797))
		s:Collect(g.Item("Grizzled Bear Heart", 3253), { count = 6, quest = 447, objective = 1 })
		s:Note("Bears roam all over Silverpine; there are plenty south of the Sepulcher.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 35.2, 11.0)
		s:Kill(g.Mob("Moss Stalker", 1780))
		s:Kill(g.Mob("Mist Creeper", 1781))
		s:Collect(g.Item("Skittering Blood", 3254), { count = 6, quest = 447, objective = 2 })
		s:Note("The spiders of the Skittering Dark, in the north-west of Silverpine.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(447, "A Recipe For Death")
		s:Accept(450, "A Recipe For Death")
		s:Note("In the Apothecarium. Fly from the Sepulcher.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 43.0, 73.2)
		s:Collect(g.Item("Berard's Journal", 3255), { quest = 450, objective = 1 })
		s:Note("On ", g.Object("Berard's Bookshelf"), " upstairs in the Pyrewood Village inn. ", g.Warn("The villagers are hostile: bring a friend."))
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 42.8, 40.9)
		s:Talk(renferrel)
		s:Turnin(450, "A Recipe For Death")
		s:Accept(451, "A Recipe For Death")
	end)

	-- Lordamere Lake: the mosses on the Dawning Isles, and the tumor from the murlocs
	g:Step(function(s)
		s:Goto(SILVERPINE, 71.5, 35.5)
		s:Kill(g.Mob("Lake Skulker", 1953))
		s:Collect(g.Item("Lake Skulker Moss", 3256), { count = 6, quest = 451, objective = 1 })
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 77.0, 27.5)
		s:Kill(g.Mob("Lake Creeper", 1955))
		s:Kill(g.Mob("Elder Lake Creeper", 1956))
		s:Collect(g.Item("Lake Creeper Moss", 3257), { count = 6, quest = 451, objective = 2 })
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 78.2, 31.1)
		s:Kill(g.Mob("Vile Fin Shorecreeper", 1957))
		s:Kill(g.Mob("Vile Fin Tidecaller", 1958))
		s:Collect(g.Item("Hardened Tumor", 3258), { quest = 451, objective = 3 })
		s:Note("A rare drop from the Vile Fin murlocs around the lake.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(451, "A Recipe For Death")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 46.3, 71.9)
		s:Talk(griffs)
		s:Accept(95216, "The New Plague")
		s:Note("Close by in the Apothecarium.")
	end)

	-- Tirisfal: Rear Guard Patrol at Linnea's camp south-east of Brill, close to the ruins
	g:Step(function(s)
		s:Goto(TIRISFAL, 65.5, 60.3)
		s:Talk(linnea)
		s:Accept(356, "Rear Guard Patrol")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 77.0, 59.8)
		s:Kill(g.Mob("Bleeding Horror", 1529), { quest = 356, objective = 1 })
		s:Kill(g.Mob("Wandering Spirit", 1532), { quest = 356, objective = 2 })
		s:Note("At the Balnir Farmstead, east of the camp.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 65.5, 60.3)
		s:Talk(linnea)
		s:Turnin(356, "Rear Guard Patrol")
		s:Accept(99156, "Rear Guard Patrol")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.9, 44.0)
		s:Kill(g.Mob("Riptear", 276020))
		s:Collect(g.Item("Riptear's Heart", 286326), { quest = 99156, objective = 1 })
		s:Note("In Venomweb Vale. ", g.Warn("Riptear is a level 13 elite: bring a group."))
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 65.5, 60.3)
		s:Talk(linnea)
		s:Turnin(99156, "Rear Guard Patrol")
		s:Talk(kristof)
		s:Accept(92422, "The Wrath of Rath'mael")
		s:Note("Kristof stands right next to her.")
	end)

	g:Step(function(s)
		s.skip = "ready 92422 or done 92422"   -- (been inside already)
		s:Goto(TIRISFAL, 63.4, 67.4)
		s:Do("Enter the Ruins of Lordaeron with your group.")
		s:Note("South of Linnea's camp.")
	end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Collect(g.Item("Intact Limbs", 268580), { count = 25, quest = 92421, objective = 1 })
		s:Note("Any of the undead inside can drop them.")
	end)

	g:Side("out", function(s)
		local crest = g.Item("Crest of Lordaeron", 275521)
		s:Use(crest):Only("not onquest 95204 and not done 95204")
		s:Accept(95204, "Crest of Lordaeron")
		s:Note("It turns up in one of several spots: the bottom or top of the towers, the ramparts, or the crypts.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Witherfang", 250483))
		s:Collect(g.Item("Highly Toxic Strain", 275443), { quest = 95216, objective = 1 })
		s:Note("The first boss: straight ahead from the entrance, then south.")
	end)

	g:Step(function(s)
		local head = g.Item("Abominable Head", 280438)
		s:Kill(g.Mob("The Baron", 250660))
		s:Use(head):Only("not onquest 97288 and not done 97288")
		s:Accept(97288, "Unending Torment")
		s:Note("The second boss, further south along the east side. He drops the ", head, ".")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Rath'mael", 250657), { quest = 92422, objective = 1 })
		s:Note("On the west side of the ruins.")
	end)

	g:Step(function(s)
		s:Quest(92401, 1, "Search the graveyard near Rath'mael for signs of Edward Heartweaver.")
	end)

	-- out: Kristof is just up the road
	g:Step(function(s)
		s.label = "out"
		s:Goto(TIRISFAL, 65.3, 60.2)
		s:Talk(kristof)
		s:Turnin(92422, "The Wrath of Rath'mael")
	end)

	-- the Undercity: the Magic Quarter, the Royal Quarter, then the Apothecarium
	g:Step(function(s)
		s.only = "onquest 95204 or done 95204"
		s:Goto(UNDERCITY, 73.1, 32.9)
		s:Talk(g.Npc("Oran Snakewrithe", 7825))
		s:Turnin(95204, "Crest of Lordaeron")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 58.1, 89.5)
		s:Talk(morbin)
		s:Turnin(92421, "Light's Justice")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 46.3, 71.9)
		s:Talk(griffs)
		s:Turnin(95216, "The New Plague")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(97288, "Unending Torment")
		s:Accept(97289, "Unending Torment")
	end)

	g:Step(function(s)
		s.only = "onquest 97289 or done 97289"
		s:Goto(UNDERCITY, 45.9, 61.7)
		s:Talk(g.Npc("Unfinished Abomination", 271613))
		s:Turnin(97289, "Unending Torment")
		s:Accept(97290, "Unending Torment")
		s:Note("In the room next to Faranell.")
	end)

	g:Step(function(s)
		s.only = "onquest 97290 or done 97290"
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(97290, "Unending Torment")
	end)

	-- Silverpine
	g:Step(function(s)
		s:Goto(SILVERPINE, 44.5, 43.0)
		s:Talk(tabitha)
		s:Turnin(92401, "A Frightened Request")
		s:Note("At the Sepulcher.")
	end)
end)
