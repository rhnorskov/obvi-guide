-- Ruins of Lordaeron (Alliance, 15-17): the four Alliance quests, all started inside, the turn-ins in Stormwind, and
-- the letter's follow-up in Duskwood.
-- Quest, NPC and item ids from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance, the way there and
-- where things are inside from DungeonJournal (Exehn). See README.md.

local TIRISFAL, STORMWIND, DUSKWOOD = 1420, 1453, 1431

ObviGuide.Guide(function(g)
	g.title = "Ruins of Lordaeron (15-17)"
	g.group = "Dungeons"
	g.id    = "obvi-ruins-of-lordaeron"
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
		s:Kill(g.Mob("Witherfang", 250483))
		s:Note("In the long hallway east of the entrance.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("The Baron", 250660))
		s:Collect(g.Item("Head of the Baron", 268518), { quest = 95250, objective = 1 })
		s:Note("In the indoor courtyard after Witherfang.")
	end)

	g:Step(function(s)
		s.label = "end"
		s:Do("Clear on through The Abandoned, Bjork and Rath'mael.")
	end)

	g:Step(function(s)
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
