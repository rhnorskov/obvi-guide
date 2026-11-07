-- Stratholme (55-60), one guide for each faction: the quests Attune lists for the dungeon. From Light's Hope Chapel:
-- Houses of the Holy, The Archivist and its follow-ups up to Baron Rivendare, The Flesh Does Not Lie and The Active
-- Agent, The Restless Souls and The Great Ezra Grimm. Tirion Fordring's chain from Redemption to Of Love and Family,
-- Ras Frostwhisper's chain up to Menethil's Gift, and Aurius' Reckoning from inside. The Horde guide adds Nathanos
-- Blightcaller's chain up to Ramstein. Two runs: the living side first (main gate), then the undead side (service
-- entrance), with Light's Hope in between.
-- Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the entrances from
-- DungeonJournal (Exehn). See README.md.

local EPL, WPL, ARATHI, UNDERCITY = 1423, 1422, 1417, 1458

-- Tirion's chain needs his three quests (Demon Dogs, Blood Tinged Skies, Carrion Grubbage); Ras Frostwhisper's chain
-- needs Kirtonos the Herald from Scholomance. Without them the guide passes those chains over.
local TIRION = "(done 5542 and done 5543 and done 5544)"
local RAS    = "done 5384"

---@param g ObviGuideGuideBuilder
---@param horde boolean
local function stratholme(g, horde)
	local smokey   = g.Npc("Smokey LaRue", 11033)
	local duke     = g.Npc("Duke Nicholas Zverenhoff", 11039)
	local betina   = g.Npc("Betina Bigglezink", 11035)
	local leonid   = g.Npc("Leonid Barthalomew the Revered", 11036)
	local alen     = g.Npc("Caretaker Alen", 11038)
	local egan     = g.Npc("Egan", 11140)
	local tirion   = g.Npc("Tirion Fordring", 1855)
	local renfray  = g.Npc("Artist Renfray", 11936)
	local marduke  = g.Npc("Magistrate Marduke", 11286)
	local aurius   = g.Npc("Aurius", 10917)
	local nathanos = g.Npc("Nathanos Blightcaller", 11878)
	local head     = g.Item("Head of Balnazzar", 13250)
	local blaster  = g.Item("Egan's Blaster", 13289)

	-- Horde: the Banshee Queen sends you to Nathanos, on the road into the Eastern Plaguelands
	if horde then
		g:Step(function(s)
			s:Goto(UNDERCITY, 58.0, 91.8)
			s:Talk(g.Npc("Lady Sylvanas Windrunner", 10181))
			s:Accept(5961, "The Champion of the Banshee Queen")
			s:Note("In the Royal Quarter.")
		end)

		g:Step(function(s)
			s:Goto(EPL, 22.2, 63.5)
			s:Talk(nathanos)
			s:Turnin(5961, "The Champion of the Banshee Queen")
			s:Accept(6042, "Un-Life's Little Annoyances")
			s:Accept(6022, "To Kill With Purpose")
			s:Accept(6133, "The Ranger Lord's Behest")
			s:Note("At Marris Stead: ride east from Western Plaguelands, it's just past the border.")
		end)

		g:Side("nathanos", function(s)
			s:Kill(g.Mob("Noxious Plaguebat", 8601), { quest = 6042, objective = 1 })
			s:Kill(g.Mob("Monstrous Plaguebat", 8602), { quest = 6042, objective = 2 })
			s:Note("Noxious ones fly around the middle of the zone, Monstrous ones further north.")
		end)

		g:Step(function(s)
			s:Goto(EPL, 52.5, 58.0)
			s:Kill(g.Mob("Gibbering Ghoul", 8531))
			s:Kill(g.Mob("Dark Caster", 8526))
			s:Collect(g.Item("Living Rot", 15447), { count = 7 }):Only("not ready 6022 and not done 6022")
			s:Use(g.Item("Mortar and Pestle", 15454))
			s:Collect(g.Item("Coagulated Rot", 15448), { quest = 6022, objective = 1 })
			s:Note("In Corin's Crossing. The rot only lasts ten minutes: get all seven, then grind them.")
		end)
	end

	-- Light's Hope Chapel: everything for the dungeon itself
	g:Step(function(s)
		s:Goto(EPL, 70.9, 48.4)
		s:Talk(smokey)
		s:Accept(5214, "The Great Ezra Grimm")
		s:Note("At Light's Hope Chapel, in the east of the Eastern Plaguelands.")
	end)

	g:Step(function(s)
		s:Goto(EPL, 71.6, 50.0)
		s:Talk(duke)
		s:Accept(5251, "The Archivist")
		s:Talk(betina)
		s:Accept(5212, "The Flesh Does Not Lie")
	end)

	g:Step(function(s)
		s:Goto(EPL, 71.9, 48.3)
		s:Talk(leonid)
		s:Accept(5243, "Houses of the Holy")
		s:Note("Inside the chapel.")
	end)

	g:Step(function(s)
		s:Goto(EPL, 69.9, 53.7)
		s:Talk(alen)
		s:Accept(5281, "The Restless Souls")
		s:Note("He walks around the chapel grounds.")
	end)

	-- Horde: the rest of Nathanos's first three, up north
	if horde then
		g:Step(function(s)
			s:Goto(EPL, 45.3, 12.7)
			s:Collect(g.Item("Quel'Thalas Registry", 15847), { quest = 6133, objective = 4 })
			s:Kill(g.Mob("Pathstrider", 8565), { quest = 6133, objective = 1 })
			s:Kill(g.Mob("Ranger", 8564), { quest = 6133, objective = 2 })
			s:Kill(g.Mob("Woodsman", 8563), { quest = 6133, objective = 3 })
			s:Note("At the Quel'Lithien lodge in the far north: the registry is inside, the elves all around.")
		end)

		g:Step(function(s)
			s.label = "nathanos"
			s:Goto(EPL, 22.2, 63.5)
			s:Talk(nathanos)
			s:Turnin(6042, "Un-Life's Little Annoyances")
			s:Turnin(6022, "To Kill With Purpose")
			s:Turnin(6133, "The Ranger Lord's Behest")
			s:Accept(6135, "Duskwing, Oh How I Hate Thee...")
			s:Accept(6136, "The Corpulent One")
		end)
	end

	-- Terrordale: Egan, then through to Tirion Fordring
	g:Step(function(s)
		s:Goto(EPL, 11.4, 26.6)
		s:Talk(egan)
		s:Turnin(5281, "The Restless Souls")
		s:Accept(5282, "The Restless Souls")
		s:Note("In a house in Terrordale, west of Stratholme. Keep ", blaster, ": you need it inside.")
	end)

	g:Step(function(s)
		s.only = "not " .. TIRION .. " and not done 5742"
		s:Say("Tirion Fordring's chain (Redemption to Of Love and Family) needs his three quests first: Demon Dogs, Blood Tinged Skies and Carrion Grubbage. The guide passes it over until you've done them.")
	end)

	g:Step(function(s)
		s.only = TIRION
		s:Goto(EPL, 5.2, 35.6)
		s:Talk(tirion)
		s:Accept(5742, "Redemption")
		s:Quest(5742, 1, "Listen to what Tirion Fordring has to say.")
		s:Turnin(5742, "Redemption")
		s:Accept(5781, "Of Forgotten Memories")
		s:Note("By his hut on the far west edge of the zone, reached through the cave on the north side of Terrordale.")
	end)

	g:Step(function(s)
		s.only = "onquest 5781 or done 5781"
		s:Goto(EPL, 23.8, 74.4)
		s:Kill(g.Mob("Mercutio Filthgorger", 11886))
		s:Collect(g.Item("Taelan's Hammer", 14613), { quest = 5781, objective = 1 })
		s:Note("In the Undercroft: search the Loose Dirt Mound and Mercutio comes with three guards. Pull him away from them if you can.")
	end)

	if horde then
		g:Step(function(s)
			s:Goto(EPL, 26.1, 59.0)
			s:Kill(g.Mob("Duskwing", 11897))
			s:Collect(g.Item("Patch of Duskwing's Fur", 15850), { quest = 6135, objective = 1 })
			s:Note("A rare bat that roams the fields north of Marris Stead.")
		end)
	end

	g:Step(function(s)
		s.only = "onquest 5781 or done 5781"
		s:Goto(EPL, 5.2, 35.6)
		s:Talk(tirion)
		s:Turnin(5781, "Of Forgotten Memories")
		s:Accept(5845, "Of Lost Honor")
	end)

	g:Step(function(s)
		s.only = "onquest 5845 or done 5845"
		s:Goto(EPL, 62.5, 26.8)
		s:Collect(g.Item("Symbol of Lost Honor", 14625), { quest = 5845, objective = 1 })
		s:Note("Under the water of the lake in Northdale.")
	end)

	if horde then
		g:Step(function(s)
			s:Goto(EPL, 47.7, 24.9)
			s:Kill(g.Mob("Borelgore", 11896), { quest = 6136, objective = 1 })
			s:Note("A big abomination that walks the northern wastes.")
		end)
	end

	g:Step(function(s)
		s.only = "onquest 5845 or done 5845"
		s:Goto(EPL, 5.2, 35.6)
		s:Talk(tirion)
		s:Turnin(5845, "Of Lost Honor")
		s:Accept(5846, "Of Love and Family")
	end)

	if horde then
		g:Step(function(s)
			s:Goto(EPL, 22.2, 63.5)
			s:Talk(nathanos)
			s:Turnin(6135, "Duskwing, Oh How I Hate Thee...")
			s:Turnin(6136, "The Corpulent One")
			s:Accept(6163, "Ramstein")
			s:Accept(6144, "The Call to Command")
			s:Note("On the way to Western Plaguelands. The Call to Command goes to Varimathras in the Undercity: it can wait until the end.")
		end)
	end

	-- Caer Darrow: the painter for Tirion, and Marduke for Ras Frostwhisper
	g:Step(function(s)
		s.only = "onquest 5846 or done 5846"
		s:Goto(WPL, 65.8, 75.4)
		s:Talk(renfray)
		s:Turnin(5846, "Of Love and Family")
		s:Accept(5848, "Of Love and Family")
		s:Note("On the island of Caer Darrow, in the lake in the south of Western Plaguelands.")
	end)

	g:Step(function(s)
		s.only = RAS
		s:Goto(WPL, 70.6, 74.1)
		s:Equip(g.Item("Spectral Essence", 13544))
		s:Talk(marduke)
		s:Accept(5461, "The Human, Ras Frostwhisper")
		s:Note("Only those wearing the Spectral Essence (from Kirtonos the Herald) can see him, on Caer Darrow.")
	end)

	g:Step(function(s)
		s.only = RAS
		s:Goto(ARATHI, 17.9, 69.4)
		s:Collect(g.Item("Keepsake of Remembrance", 13585), { quest = 5461, objective = 1 })
		s:Note("In the ruins of Stromgarde. It turns up in several places: also look around 18.5, 66.2, 20.8, 65.8 and 27.6, 66.0.")
	end)

	g:Step(function(s)
		s.only = RAS
		s:Goto(WPL, 70.6, 74.1)
		s:Equip(g.Item("Spectral Essence", 13544))
		s:Talk(marduke)
		s:Turnin(5461, "The Human, Ras Frostwhisper")
		s:Accept(5462, "The Dying, Ras Frostwhisper")
	end)

	g:Step(function(s)
		s.only = RAS
		s:Goto(EPL, 71.9, 48.3)
		s:Talk(leonid)
		s:Turnin(5462, "The Dying, Ras Frostwhisper")
		s:Accept(5463, "Menethil's Gift")
		s:Note("Back at Light's Hope Chapel.")
	end)

	-- the living side, through the main gate
	g:Step(function(s)
		s.skip = "ready 5214 or done 5214 or ready 5251 or done 5251"   -- (been inside already)
		s:Goto(EPL, 30.0, 15.0)
		s:Do("Enter Stratholme by the main gate with your group.")
	end)

	-- both runs, the whole way
	g:Side("out2", function(s)
		s:Collect(g.Item("Stratholme Holy Water", 13180), { count = 5, quest = 5243, objective = 1 })
		s:Note("From the Stratholme Supply Crates along the streets; some hold plagued insects instead.")
	end)

	g:Side("out2", function(s)
		s:Collect(g.Item("Plagued Flesh Sample", 13174), { count = 20, quest = 5212, objective = 1 })
		s:Note("Any creature in Stratholme can drop them.")
	end)

	g:Side("out2", function(s)
		s:Use(blaster)
		s:Quest(5282, 1, "Free 15 Restless Souls.")
		s:Note("Use the blaster on a Spectral or Ghostly Citizen, then again on the Restless Soul that breaks free.")
	end)

	g:Side("out", function(s)
		local medallion = g.Item("Medallion of Faith", 12845)
		s.only = "not done 5122"
		s:Collect(medallion)
		s:Note("In Malor's Strongbox, in the room with Malor the Zealous off the Hall of Lights. Take it to Aurius on the undead side: he helps against Baron Rivendare.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Ezra Grimm", 11058))
		s:Collect(g.Item("Grimm's Premium Tobacco", 13172), { quest = 5214, objective = 1 })
		s:Note("In the smoke shop on King's Square: open the box of tobacco and kill Ezra Grimm when he comes for it.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Archivist Galford", 10811), { quest = 5251, objective = 1 })
		s:Quest(5251, 2, "Burn the Scarlet Archive.")
		s:Note("In the Scarlet Bastion, near its end. The archive is the book on the table in his room.")
	end)

	g:Step(function(s)
		s.only = "onquest 5848 or done 5848"
		s:Collect(g.Item("Of Love and Family", 14679), { quest = 5848, objective = 1 })
		s:Note("In Galford's room, hidden behind the painting of the twin moons.")
	end)

	g:Step(function(s)
		s.skip = "onquest 5262 or done 5262"
		s:Kill(g.Mob("Grand Crusader Dathrohan", 10812))
		s:Collect(head)
		s:Note("The last boss of the living side, across from Galford; he turns into Balnazzar. Keep the head: its quest opens once The Archivist is handed in.")
	end)

	-- Light's Hope between the runs
	g:Step(function(s)
		s.label = "out"
		s:Goto(EPL, 70.9, 48.4)
		s:Talk(smokey)
		s:Turnin(5214, "The Great Ezra Grimm")
	end)

	g:Step(function(s)
		s:Goto(EPL, 71.6, 50.0)
		s:Talk(duke)
		s:Turnin(5251, "The Archivist")
		s:Use(head):Only("not onquest 5262 and not done 5262 and items 13250 >= 1")
		s:Accept(5262, "The Truth Comes Crashing Down"):Only("items 13250 >= 1 or onquest 5262 or done 5262")
		s:Turnin(5262, "The Truth Comes Crashing Down"):Only("items 13250 >= 1 or onquest 5262 or done 5262")
		s:Accept(5263, "Above and Beyond"):Only("done 5262")
		s:Note("Without the head, kill Balnazzar on another run of the living side before going on.")
	end)

	g:Step(function(s)
		s.only = "ready 5212 or done 5212"
		s:Goto(EPL, 71.7, 49.9)
		s:Talk(betina)
		s:Turnin(5212, "The Flesh Does Not Lie")
		s:Accept(5213, "The Active Agent")
	end)

	g:Step(function(s)
		s.only = "ready 5243"
		s:Goto(EPL, 71.9, 48.3)
		s:Talk(leonid)
		s:Turnin(5243, "Houses of the Holy")
	end)

	-- the undead side, through the service entrance
	g:Step(function(s)
		s.skip = "ready 5263 or done 5263"   -- (been inside already)
		s:Goto(EPL, 44.0, 19.0)
		s:Do("Enter Stratholme by the service entrance with your group.")
	end)

	g:Step(function(s)
		s.only = "items 12845 >= 1 or onquest 5122 or done 5122"
		s:Talk(aurius)
		s:Accept(5122, "The Medallion of Faith")
		s:Turnin(5122, "The Medallion of Faith")
		s:Note("In the chapel on the right just inside.")
	end)

	g:Step(function(s)
		s.only = "onquest 5213"
		s:Collect(g.Item("Scourge Data", 13176), { quest = 5213, objective = 1 })
		s:Note("A metal box in one of the three ziggurats along the Gauntlet.")
	end)

	if horde then
		g:Step(function(s)
			s.only = "onquest 6163"
			s:Kill(g.Mob("Ramstein the Gorger", 10439))
			s:Collect(g.Item("Head of Ramstein the Gorger", 15880), { quest = 6163, objective = 1 })
			s:Note("In Slaughter Square: he comes out once the abominations there are dead.")
		end)
	end

	g:Step(function(s)
		s:Kill(g.Mob("Baron Rivendare", 10440))
		s:Collect(g.Item("Head of Baron Rivendare", 13251), { quest = 5263, objective = 1 })
		s:Note("The last boss, in the building on Slaughter Square.")
	end)

	g:Step(function(s)
		s.only = "done 5122"
		s:Talk(aurius)
		s:Accept(5125, "Aurius' Reckoning")
		s:Turnin(5125, "Aurius' Reckoning")
		s:Note("He lies in Baron Rivendare's room after the fight.")
	end)

	g:Step(function(s)
		s.only = "onquest 5463"
		s:Turnin(5463, "Menethil's Gift")
		s:Note("Click Menethil's Gift, the symbol on the floor in Baron Rivendare's room, to lay the Keepsake on it.")
	end)

	-- the turn-ins
	g:Step(function(s)
		s.label = "out2"
		s:Goto(EPL, 71.6, 50.0)
		s:Talk(duke)
		s:Turnin(5263, "Above and Beyond")
	end)

	g:Step(function(s)
		s.only = "ready 5212 or done 5212"
		s:Goto(EPL, 71.7, 49.9)
		s:Talk(betina)
		s:Turnin(5212, "The Flesh Does Not Lie")
		s:Accept(5213, "The Active Agent")
		s:Turnin(5213, "The Active Agent"):Only("ready 5213")
	end)

	g:Step(function(s)
		s.only = "ready 5243"
		s:Goto(EPL, 71.9, 48.3)
		s:Talk(leonid)
		s:Turnin(5243, "Houses of the Holy")
	end)

	-- The Active Agent taken only now: one more trip to the undead side
	g:Step(function(s)
		s.only = "onquest 5213 and not ready 5213"
		s:Goto(EPL, 44.0, 19.0)
		s:Collect(g.Item("Scourge Data", 13176), { quest = 5213, objective = 1 })
		s:Note("Back in by the service entrance: a metal box in one of the three ziggurats along the Gauntlet.")
	end)

	g:Step(function(s)
		s.only = "ready 5213"
		s:Goto(EPL, 71.7, 49.9)
		s:Talk(betina)
		s:Turnin(5213, "The Active Agent")
	end)

	-- the west: Egan, Tirion (and Nathanos)
	g:Step(function(s)
		s.only = "ready 5282"
		s:Goto(EPL, 11.4, 26.6)
		s:Talk(egan)
		s:Turnin(5282, "The Restless Souls")
	end)

	g:Step(function(s)
		s.only = "ready 5848"
		s:Goto(EPL, 5.2, 35.6)
		s:Talk(tirion)
		s:Turnin(5848, "Of Love and Family")
	end)

	if horde then
		g:Step(function(s)
			s.only = "ready 6163"
			s:Goto(EPL, 22.2, 63.5)
			s:Talk(nathanos)
			s:Turnin(6163, "Ramstein")
		end)

		g:Step(function(s)
			s.only = "onquest 6144"
			s:Goto(UNDERCITY, 56.3, 92.2)
			s:Talk(g.Npc("Varimathras", 2425))
			s:Turnin(6144, "The Call to Command")
			s:Note("In the Royal Quarter.")
		end)
	end
end

ObviGuide.Guide(function(g)
	g.title = "Stratholme: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-stratholme"
	g.only  = "Alliance"
	stratholme(g, false)
end)

ObviGuide.Guide(function(g)
	g.title = "Stratholme: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-stratholme-horde"
	g.only  = "Horde"
	stratholme(g, true)
end)
