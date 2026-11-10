-- City of Dalaran (28-32): the quests Attune lists for each faction. Alliance: A Green Sample and Power Overwhelming
-- from Stormwind, An Alarming Request from Southshore, Heart of Disruption, Starving Arcane and Friend of the Kirin
-- Tor. Horde: Source of Power from Undercity, The Grave Knight, Magus Voidglare's chain from Prison Break In to Blood
-- in the Streets, Heart of Disruption and Shrewd Negotiations, and Opportunistic Education inside. Quest, NPC and
-- item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the way in from DungeonJournal
-- (Exehn). See README.md.

local STORMWIND, HILLSBRAD, SILVERPINE, ALTERAC, UNDERCITY = 1453, 1424, 1421, 1416, 1458

-- the way in, as DungeonJournal describes it
local function enter(s, skip)
	s.skip = skip   -- (been inside already)
	s:Do("Enter the City of Dalaran with your group.")
	s:Note("Through the city's sewers: drop through a grate in the streets and follow the pipe to the portal.")
end

ObviGuide.Guide(function(g)
	g.title = "City of Dalaran: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-dalaran"
	g.next  = "obvi-razorfen-kraul"
	g.only  = "Alliance"

	local andromath = g.Npc("High Sorcerer Andromath", 5694)
	local shylamiir = g.Npc("Shylamiir", 5502)
	local modera    = g.Npc("Image of Archmage Modera", 269127)

	-- Stormwind
	g:Step(function(s)
		s:Goto(STORMWIND, 48.7, 87.6)
		s:Talk(andromath)
		s:Accept(92489, "Power Overwhelming")
		s:Note("At the top of the Wizard's Sanctum tower.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 31.5, 62.6)
		s:Talk(shylamiir)
		s:Accept(92456, "A Green Sample")
		s:Note("Inside the building. Then fly to Southshore.")
	end)

	-- Southshore, then north past the city to the lake shore
	g:Step(function(s)
		s:Goto(HILLSBRAD, 48.3, 60.0)
		s:Talk(g.Npc("Emissary Jacques", 247264))
		s:Accept(92432, "An Alarming Request")
		s:Note("In Southshore. From level 30.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 68.6, 45.1)
		s:Talk(modera)
		s:Turnin(92432, "An Alarming Request")
		s:Accept(92458, "Heart of Disruption")
		s:Accept(92457, "Starving Arcane")
		s:Note("On the Lordamere Lake shore just west of Dalaran: north from Southshore, round the city.")
	end)

	g:Step(function(s) enter(s, "ready 92489 or done 92489") end)

	-- inside, in the order the group meets them; the remnants and echoes all the way through
	g:Side("shade", function(s)
		s:Kill(g.Mob("Seeking Remnant", 247003), { count = 8, quest = 92457, objective = 1 })
		s:Kill(g.Mob("Saturated Remnant", 247001), { count = 8, quest = 92457, objective = 2 })
		s:Kill(g.Mob("Mana Echo", 246600), { count = 8, quest = 92457, objective = 3 })
		s:Note("There may not be enough of them for it in one run.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Arcanic Enigma", 246016), { quest = 92489, objective = 1 })
		s:Note("The fourth boss. Kill the Mana Phantoms around it first.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Fel Infused Blossom", 251983), { quest = 92456, objective = 1 })
		s:Note("Click the ", g.Object("Fel Infused Blossom"), " next to the Fel Ancient.")
	end)

	g:Step(function(s)
		s.label = "shade"
		s:Kill(g.Mob("Shade of the Archmage", 246020))
		s:Collect(g.Item("Arcane Mote", 251961), { quest = 92458, objective = 1 })
		s:Note("The last boss.")
	end)

	-- the turn-ins
	g:Step(function(s)
		s.label = "out"
		s:Goto(SILVERPINE, 68.6, 45.1)
		s:Talk(modera)
		s:Turnin(92458, "Heart of Disruption")
		s:Turnin(92457, "Starving Arcane")
		s:Accept(92459, "Friend of the Kirin Tor")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 14.2, 60.1)
		s:Talk(g.Npc("Archmage Celindra", 252085))
		s:Turnin(92459, "Friend of the Kirin Tor")
		s:Note("By Modera's image at the west edge of Dalaran. Then back to Southshore and fly to Stormwind.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 48.7, 87.6)
		s:Talk(andromath)
		s:Turnin(92489, "Power Overwhelming")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 31.5, 62.6)
		s:Talk(shylamiir)
		s:Turnin(92456, "A Green Sample")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "City of Dalaran: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-dalaran-horde"
	g.next  = "obvi-razorfen-kraul-horde"
	g.only  = "Horde"

	local felben    = g.Npc("Doctor Martin Felben", 11044)
	local voidglare = g.Npc("Magus Wordeen Voidglare", 2410)
	local melisara  = g.Npc("Melisara", 2278)
	local modera    = g.Npc("Image of Archmage Modera", 269127)
	local rexxie    = g.Npc("Rexxie Copperclutch", 268743)

	g:Step(function(s)
		s:Goto(UNDERCITY, 46.6, 74.1)
		s:Talk(felben)
		s:Accept(96988, "Source of Power")
		s:Note("In the Apothecarium. Then fly to Tarren Mill.")
	end)

	-- Tarren Mill
	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.8)
		s:Talk(voidglare)
		s:Accept(544, "Prison Break In")
		s:Accept(93680, "Key to the City")
		s:Note("Inside the building.")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 62.6, 20.6)
		s:Talk(melisara)
		s:Accept(96986, "The Grave Knight")
	end)

	-- the Dalaran internment camp in southern Alterac
	g:Step(function(s)
		s:Goto(ALTERAC, 20.2, 84.3)
		s:Kill(g.Mob("Ricter", 2411))
		s:Collect(g.Item("Bloodstone Marble", 3689), { quest = 544, objective = 2 })
		s:Note("He walks around.")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 20.3, 86.4)
		s:Kill(g.Mob("Alina", 2412))
		s:Collect(g.Item("Bloodstone Shard", 3690), { quest = 544, objective = 3 })
		s:Kill(g.Mob("Dermot", 2413))
		s:Collect(g.Item("Bloodstone Wedge", 3691), { quest = 544, objective = 1 })
		s:Note("Both walk around in and near the building; Dermot around 19.9, 86.0.")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 16.5, 89.7)
		s:Collect(g.Item("Grimy Key", 279469), { quest = 93680, objective = 1 })
		s:Note("In a ", g.Object("Warden's Footlocker"), " inside the building, on the way up to the second floor.")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 17.8, 83.2)
		s:Kill(g.Mob("Kegan Darkmar", 2414))
		s:Collect(g.Item("Bloodstone Oval", 3688), { quest = 544, objective = 4 })
		s:Note("Upstairs, guarded by Warden Belamoore: fight around doorways to break her line of sight.")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.8)
		s:Talk(voidglare)
		s:Turnin(544, "Prison Break In")
		s:Turnin(93680, "Key to the City")
		s:Accept(545, "Dalaran Patrols")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 22.4, 59.5)
		s:Kill(g.Mob("Dalaran Summoner", 2358), { quest = 545, objective = 1 })
		s:Kill(g.Mob("Elemental Slave", 2359), { quest = 545, objective = 2 })
		s:Note("Around the east side of Dalaran; more to the south, down to 18, 77.")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.8)
		s:Talk(voidglare)
		s:Turnin(545, "Dalaran Patrols")
		s:Accept(92434, "Blood in the Streets")
	end)

	-- round the north of the city to the lake shore
	g:Step(function(s)
		s:Goto(SILVERPINE, 68.3, 45.5)
		s:Quest(92434, 1, "Find a way into Dalaran along Lordamere Lake.")
		s:Note("Go round the north side of Dalaran to the Lordamere Lake shore west of it.")
	end)

	g:Step(function(s)
		s:Goto(SILVERPINE, 68.6, 45.1)
		s:Talk(modera)
		s:Turnin(92434, "Blood in the Streets")
		s:Accept(96984, "Heart of Disruption")
	end)

	g:Step(function(s) enter(s, "ready 96988 or done 96988") end)

	g:Step(function(s)
		s:Talk(rexxie)
		s:Accept(96987, "Opportunistic Education")
		s:Note("By the sewer entrance, at the start.")
	end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Fragmented Sentry", 246664))
		s:Collect(g.Item("Cracked Sentry Core", 275997), { count = 6, quest = 96988, objective = 1 })
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Founding of Dalaran", 275996), { quest = 96987, objective = 1 })
		s:Note("A ", g.Object("Dalaran Tome"), " on the second bookshelf from the right in the Tempered Tomes, in the Silver Enclave.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Atrexis the Grave Knight", 247126), { quest = 96986, objective = 1 })
		s:Note("The first boss. Kill the skeletons he summons first.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Shade of the Archmage", 246020))
		s:Collect(g.Item("Arcane Mote", 251961), { quest = 96984, objective = 1 })
		s:Note("The last boss.")
	end)

	g:Step(function(s)
		s.label = "out"
		s:Talk(rexxie)
		s:Turnin(96987, "Opportunistic Education")
		s:Note("Back by the sewer entrance.")
	end)

	-- Tarren Mill, back to the lake shore for Celindra, then Undercity
	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.6, 20.8)
		s:Talk(voidglare)
		s:Turnin(96984, "Heart of Disruption")
		s:Accept(97287, "Shrewd Negotiations")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 62.6, 20.6)
		s:Talk(melisara)
		s:Turnin(96986, "The Grave Knight")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 14.2, 60.1)
		s:Talk(g.Npc("Archmage Celindra", 252085))
		s:Turnin(97287, "Shrewd Negotiations")
		s:Note("By Modera's image at the west edge of Dalaran.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 46.6, 74.1)
		s:Talk(felben)
		s:Turnin(96988, "Source of Power")
	end)
end)
