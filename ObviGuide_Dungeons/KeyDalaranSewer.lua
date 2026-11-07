-- Dalaran Sewer Key (Alliance and Horde, 24-30+): the key into the City of Dalaran. It comes with Heart of
-- Disruption, which the Image of Archmage Modera on Lordamere Lake gives once you have reached her: for the Alliance
-- through An Alarming Request from Southshore, for the Horde through Magus Voidglare's chain in Tarren Mill (the
-- traitors and the Grimy Key at the internment camp, the Dalaran patrols, and the way in along the lake).
-- Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the City of Dalaran
-- bosses from DungeonJournal (Exehn). See README.md.

local SILVERPINE, ALTERAC, HILLSBRAD = 1421, 1416, 1424

-- Alliance: Southshore, then Modera; Attune counts the whole of Heart of Disruption
ObviGuide.Guide(function(g)
	g.title = "Dalaran Sewer Key"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-dalaran-sewer"
	g.only  = "Alliance"

	local modera = g.Npc("Image of Archmage Modera", 269127)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 48.3, 60.0)
		s:Talk(g.Npc("Emissary Jacques", 247264))
		s:Accept(92432, "An Alarming Request")
		s:Note("In Southshore.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 68.6, 45.1)
		s:Talk(modera)
		s:Turnin(92432, "An Alarming Request")
		s:Accept(92458, "Heart of Disruption")
		s:Collect(g.Item("Dalaran Sewer Key", 277507))
		s:Note("On the shore of Lordamere Lake below Dalaran's walls. The key comes with the quest; only one person in the group needs it.")
	end)

	g:Step(function(s)
		s.skip = "ready 92458 or done 92458"   -- (been inside already)
		s:Do("Enter the City of Dalaran with your group.")
		s:Note("Through the sewers close to Modera.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Shade of the Archmage", 246020))
		s:Collect(g.Item("Arcane Mote", 251961), { quest = 92458, objective = 1 })
		s:Note("The last boss, in the Violet Citadel.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 68.6, 45.1)
		s:Talk(modera)
		s:Turnin(92458, "Heart of Disruption")
	end)
end)

-- Horde: Magus Voidglare in Tarren Mill, the internment camp in Alterac, then Modera
ObviGuide.Guide(function(g)
	g.title = "Dalaran Sewer Key"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-dalaran-sewer-horde"
	g.only  = "Horde"

	local voidglare = g.Npc("Magus Wordeen Voidglare", 2410)
	local modera    = g.Npc("Image of Archmage Modera", 269127)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.9)
		s:Talk(voidglare)
		s:Accept(544, "Prison Break In")
		s:Accept(93680, "Key to the City")
		s:Note("Inside the building in Tarren Mill.")
	end)

	-- the internment camp in the south-west of Alterac
	g:Step(function(s)
		s:Goto(ALTERAC, 20.2, 85.5)
		s:Kill(g.Mob("Ricter", 2411))
		s:Collect(g.Item("Bloodstone Marble", 3689), { quest = 544, objective = 2 })
		s:Kill(g.Mob("Alina", 2412))
		s:Collect(g.Item("Bloodstone Shard", 3690), { quest = 544, objective = 3 })
		s:Kill(g.Mob("Dermot", 2413))
		s:Collect(g.Item("Bloodstone Wedge", 3691), { quest = 544, objective = 1 })
		s:Note("Ricter walks around outside at 20.2, 84.3; Alina and Dermot are in the building at 20.3, 86.4.")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 16.5, 89.7)
		s:Say("Open the ", g.Object("Warden's Footlocker"), ".")
		s:Collect(g.Item("Grimy Key", 279469), { quest = 93680, objective = 1 })
		s:Note("Inside the building, on the way up to the second floor.")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 17.8, 83.2)
		s:Kill(g.Mob("Kegan Darkmar", 2414))
		s:Collect(g.Item("Bloodstone Oval", 3688), { quest = 544, objective = 4 })
		s:Note("Upstairs, with a warden beside her. She is a caster: pull her round a corner so she has to come to you.")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.9)
		s:Talk(voidglare)
		s:Turnin(544, "Prison Break In")
		s:Turnin(93680, "Key to the City")
		s:Accept(545, "Dalaran Patrols")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 22.4, 59.5)
		s:Kill(g.Mob("Dalaran Summoner", 2358), { quest = 545, objective = 1 })
		s:Kill(g.Mob("Elemental Slave", 2359), { quest = 545, objective = 2 })
		s:Note("Around the walls of Dalaran; more to the south, around 18.8, 77.1.")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.9)
		s:Talk(voidglare)
		s:Turnin(545, "Dalaran Patrols")
		s:Accept(92434, "Blood in the Streets")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 68.3, 45.5)
		s:Quest(92434, 1, "Find a way into Dalaran along Lordamere Lake.")
		s:Note("Round the north side of the city, along the lake shore.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 68.6, 45.1)
		s:Talk(modera)
		s:Turnin(92434, "Blood in the Streets")
		s:Accept(96984, "Heart of Disruption")
		s:Collect(g.Item("Dalaran Sewer Key", 277507))
		s:Note("The key comes with the quest; only one person in the group needs it. The Arcane Mote for Heart of Disruption is in the City of Dalaran, and the quest goes back to Tarren Mill.")
	end)
end)
