-- Uldaman (Alliance and Horde, 35-47): the quests Attune lists for the dungeon. Both factions: Power Stones, Solution
-- to Doom, the two Reagent Runs, Reclaimed Treasures and The Platinum Discs. Alliance: The Lost Dwarves and The Hidden
-- Chamber, The Lost Tablets of Will, A Sign of Hope and Amulet of Secrets (Hammertoe Grez), and The Shattered Necklace
-- that drops inside. Horde: the Necklace Recovery chain up to Find the Gems and Power Source, which takes three
-- visits: the necklace, the paladin's remains, then the gems. Quest, NPC, item and object ids and positions from
-- Attune (CixiDelmont) and QuestieDB's Forever data; the entrance and the outer caves from DungeonJournal (Exehn).
-- See README.md.

local BADLANDS, LOCH_MODAN, IRONFORGE, UNDERCITY, ORGRIMMAR = 1418, 1432, 1455, 1458, 1454

-- the Badlands, both factions
local function rigglefuzz(g, s, turnin)
	s:Goto(BADLANDS, 42.4, 52.9)
	s:Talk(g.Npc("Rigglefuzz", 2817))
	if turnin then s:Turnin(2418, "Power Stones") else s:Accept(2418, "Power Stones") end
end

local function theldurin(g, s, turnin)
	s:Goto(BADLANDS, 51.4, 76.9)
	s:Talk(g.Npc("Theldurin the Lost", 2785))
	if turnin then s:Turnin(709, "Solution to Doom") else s:Accept(709, "Solution to Doom") end
end

-- the Badlands Reagent Run: quest is the faction's id (both have the same three reagents)
local function coyotesAndBuzzards(g, s, quest)
	s:Goto(BADLANDS, 49.8, 46.2)
	s:Kill(g.Mob("Crag Coyote", 2727))
	s:Collect(g.Item("Crag Coyote Fang", 7846), { count = 10, quest = quest, objective = 2 })
	s:Kill(g.Mob("Buzzard", 2830))
	s:Collect(g.Item("Buzzard Gizzard", 7847), { count = 5, quest = quest, objective = 1 })
	s:Note("Coyotes all over the middle of the Badlands; buzzards a little further south, around 48.6, 55.5.")
end

-- the outer caves, before the instance portal: power stones and fungus caps all the way, the Tablet of Ryun'eh
local function outerSides(g, reagents)
	g:Side("out", function(s)
		s:Kill(g.Mob("Shadowforge Surveyor", 4844))
		s:Kill(g.Mob("Shadowforge Ruffian", 4845))
		s:Collect(g.Item("Dentrium Power Stone", 8009), { count = 8, quest = 2418, objective = 1 })
		s:Collect(g.Item("An'Alleum Power Stone", 8052), { count = 8, quest = 2418, objective = 2 })
		s:Note("From the Shadowforge dwarves, in the outer caves and inside.")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Magenta Fungus Cap", 8047), { count = 12, quest = reagents, objective = 1 })
		s:Note("Picked from the Magenta Cap Clusters, in the outer caves and inside.")
	end)
end

local function ryuneh(g, s)
	s:Goto(BADLANDS, 39.3, 18.8)
	s:Collect(g.Item("Tablet of Ryun'eh", 4631), { quest = 709, objective = 1 })
	s:Note("In an ", g.Object("Ancient Chest"), " in the outer caves.")
end

local function discs(g, s)
	s:Talk(g.Npc("Lore Keeper of Norgannon", 7172))
	s:Accept(2278, "The Platinum Discs")
	s:Quest(2278, 1, "Hear out the stone watcher, then click the Discs of Norgannon.")
	s:Turnin(2278, "The Platinum Discs")
	s:Note("In the chamber past Archaedas, the last boss. The discs then offer a follow-up to take to your capital.")
end

ObviGuide.Guide(function(g)
	g.title = "Uldaman: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-uldaman"
	g.next  = "obvi-zul-farrak"
	g.only  = "Alliance"

	local stormpike = g.Npc("Prospector Stormpike", 1356)
	local krom      = g.Npc("Krom Stoutarm", 6294)
	local belgrum   = g.Npc("Advisor Belgrum", 2918)
	local ghak      = g.Npc("Ghak Healtouch", 1470)
	local ryedol    = g.Npc("Prospector Ryedol", 2910)
	local hammertoe = g.Npc("Hammertoe Grez", 2909)

	-- Ironforge: the Hall of Explorers
	g:Step(function(s)
		s:Goto(IRONFORGE, 74.6, 11.7)
		s:Talk(stormpike)
		s:Accept(2398, "The Lost Dwarves")
		s:Note("In the Hall of Explorers.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 74.2, 9.4)
		s:Talk(krom)
		s:Accept(1360, "Reclaimed Treasures")
		s:Talk(belgrum)
		s:Accept(1139, "The Lost Tablets of Will"):Only("done 762 or onquest 1139 or done 1139")
		s:Note(belgrum, " is close by, at 77.3, 9.7. He only offers his quest once you've done An Ambassador of Evil.")
	end)

	g:Step(function(s)
		s:Goto(LOCH_MODAN, 37.1, 49.4)
		s:Talk(ghak)
		s:Accept(2500, "Badlands Reagent Run")
		s:Note("In Thelsamar. Then south into the Badlands.")
	end)

	-- the Badlands: north to south, then back to Thelsamar
	g:Step(function(s)
		s:Goto(BADLANDS, 53.0, 33.9)
		s:Accept(720, "A Sign of Hope")
		s:Note("Click the ", g.Object("Crumpled Map"), " lying on the ground.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 53.4, 43.4)
		s:Talk(ryedol)
		s:Turnin(720, "A Sign of Hope")
		s:Accept(721, "A Sign of Hope")
	end)

	g:Step(function(s) coyotesAndBuzzards(g, s, 2500) end)
	g:Step(function(s) rigglefuzz(g, s) end)
	g:Step(function(s) theldurin(g, s) end)

	g:Step(function(s)
		s:Goto(BADLANDS, 44.3, 84.0)
		s:Kill(g.Mob("Rock Elemental", 92))
		s:Collect(g.Item("Rock Elemental Shard", 7848), { count = 5, quest = 2500, objective = 3 })
		s:Note("Below Theldurin, in the south of the Badlands.")
	end)

	g:Step(function(s)
		s:Goto(LOCH_MODAN, 37.1, 49.4)
		s:Talk(ghak)
		s:Turnin(2500, "Badlands Reagent Run")
		s:Accept(17, "Uldaman Reagent Run")
		s:Note("Back in Thelsamar; then south again to Uldaman, in the north of the Badlands.")
	end)

	-- the outer caves of Uldaman
	g:Step(function(s)
		s:Goto(BADLANDS, 37.9, 10.6)
		s:Talk(hammertoe)
		s:Turnin(721, "A Sign of Hope")
		s:Accept(722, "Amulet of Secrets")
		s:Note("In the outer caves of Uldaman, before the instance portal.")
	end)

	outerSides(g, 17)

	g:Step(function(s)
		s:Goto(BADLANDS, 39.0, 19.7)
		s:Kill(g.Mob("Magregan Deepshadow", 2932))
		s:Collect(g.Item("Hammertoe's Amulet", 4635), { quest = 722, objective = 1 })
	end)

	g:Step(function(s) ryuneh(g, s) end)

	g:Step(function(s)
		s:Goto(BADLANDS, 37.9, 10.6)
		s:Talk(hammertoe)
		s:Turnin(722, "Amulet of Secrets")
		s:Note("His next quest, Prospect of Faith, takes the amulet to Prospector Ryedol.")
	end)

	g:Step(function(s)
		s.skip = "done 2398 or ready 1360 or done 1360"   -- (been inside already)
		s:Goto(BADLANDS, 44.3, 12.0)
		s:Do("Enter Uldaman with your group.")
	end)

	-- inside
	g:Side("out", function(s)
		local necklace = g.Item("Shattered Necklace", 7666)
		s:Use(necklace):Only("not onquest 2198 and not done 2198")
		s:Accept(2198, "The Shattered Necklace")
		s:Note("The troggs and Shadowforge dwarves can drop the ", necklace, ": it starts the quest.")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Krom Stoutarm's Treasure", 8027), { quest = 1360, objective = 1 })
		s:Note("In ", g.Object("Krom Stoutarm's Chest"), ", in the North Common Hall.")
	end)

	g:Side("out", function(s)
		s.only = "onquest 1139"
		s:Collect(g.Item("Tablet of Will", 5824), { quest = 1139, objective = 1 })
		s:Note("Click the ", g.Object("Tablet of Will"), " in the dungeon.")
	end)

	g:Step(function(s)
		s:Talk(g.Npc("Baelog", 6906))
		s:Turnin(2398, "The Lost Dwarves")
		s:Accept(2240, "The Hidden Chamber")
		s:Note("With the other lost dwarves, near the start of the dungeon.")
	end)

	g:Step(function(s)
		s:Quest(2240, 1, "Read Baelog's Journal, then explore the hidden chamber.")
		s:Note("The hidden chamber is the vault where Ironaya waits.")
	end)

	g:Step(function(s) discs(g, s) end)

	-- the turn-ins: south through the Badlands, north to Thelsamar, and on to Ironforge
	g:Step(function(s)
		s.label = "out"
		rigglefuzz(g, s, true)
	end)

	g:Step(function(s) theldurin(g, s, true) end)

	g:Step(function(s)
		s:Goto(LOCH_MODAN, 37.1, 49.4)
		s:Talk(ghak)
		s:Turnin(17, "Uldaman Reagent Run")
		s:Note("Then fly to Ironforge.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 74.6, 11.7)
		s:Talk(stormpike)
		s:Turnin(2240, "The Hidden Chamber")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 74.2, 9.4)
		s:Talk(krom)
		s:Turnin(1360, "Reclaimed Treasures")
		s:Talk(belgrum)
		s:Turnin(1139, "The Lost Tablets of Will"):Only("onquest 1139 or done 1139")
	end)

	g:Step(function(s)
		s.only = "onquest 2198 or done 2198"
		s:Goto(IRONFORGE, 36.4, 3.6)
		s:Talk(g.Npc("Talvash del Kissel", 6826))
		s:Turnin(2198, "The Shattered Necklace")
		s:Note("In the Mystic Ward. His chain goes on, back into Uldaman for the necklace's gems.")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Uldaman: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-uldaman-horde"
	g.next  = "obvi-zul-farrak-horde"
	g.only  = "Horde"

	local dran    = g.Npc("Dran Droffers", 6986)
	local patrick = g.Npc("Patrick Garrett", 5651)
	local jarkal  = g.Npc("Jarkal Mossmeld", 6868)
	local remains = g.Npc("Remains of a Paladin", 6912)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 59.5, 36.6)
		s:Talk(dran)
		s:Accept(2283, "Necklace Recovery")
		s:Note("In the Drag. Then take the zeppelin to Tirisfal Glades.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 62.3, 48.6)
		s:Talk(patrick)
		s:Accept(2342, "Reclaimed Treasures")
		s:Note("Then fly to Kargath, in the Badlands.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 2.4, 46.1)
		s:Talk(jarkal)
		s:Accept(2258, "Badlands Reagent Run")
		s:Note("In Kargath.")
	end)

	-- the Badlands: a loop east and back to Kargath
	g:Step(function(s)
		s:Goto(BADLANDS, 15.1, 37.6)
		s:Kill(g.Mob("Lesser Rock Elemental", 2735))
		s:Collect(g.Item("Rock Elemental Shard", 7848), { count = 5, quest = 2258, objective = 3 })
		s:Note("East of Kargath.")
	end)

	g:Step(function(s) theldurin(g, s) end)
	g:Step(function(s) coyotesAndBuzzards(g, s, 2258) end)
	g:Step(function(s) rigglefuzz(g, s) end)

	g:Step(function(s)
		s:Goto(BADLANDS, 2.4, 46.1)
		s:Talk(jarkal)
		s:Turnin(2258, "Badlands Reagent Run")
		s:Accept(2202, "Uldaman Reagent Run")
		s:Note("Then to Uldaman, in the north of the Badlands.")
	end)

	-- first visit: the necklace, the treasure and the discs
	outerSides(g, 2202)

	g:Step(function(s) ryuneh(g, s) end)

	g:Step(function(s)
		s.skip = "done 2278 or ready 2283 or done 2283"   -- (been inside already)
		s:Goto(BADLANDS, 44.3, 12.0)
		s:Do("Enter Uldaman with your group.")
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Stonevault Rockchewer", 4851))
		s:Kill(g.Mob("Shadowforge Digger", 4846))
		s:Collect(g.Item("Shattered Necklace", 7666), { quest = 2283, objective = 1 })
		s:Note("The troggs and Shadowforge dwarves can drop it.")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Garrett Family Treasure", 8026), { quest = 2342, objective = 1 })
		s:Note("In the ", g.Object("Garrett Family Chest"), ", in the South Common Hall.")
	end)

	g:Step(function(s) discs(g, s) end)

	-- the turn-ins, and the necklace back to Orgrimmar by way of the Undercity
	g:Step(function(s)
		s.label = "out"
		rigglefuzz(g, s, true)
	end)

	g:Step(function(s) theldurin(g, s, true) end)

	g:Step(function(s)
		s:Goto(BADLANDS, 2.4, 46.1)
		s:Talk(jarkal)
		s:Turnin(2202, "Uldaman Reagent Run")
		s:Note("Then fly to the Undercity.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 62.3, 48.6)
		s:Talk(patrick)
		s:Turnin(2342, "Reclaimed Treasures")
		s:Note("Then take the zeppelin to Orgrimmar.")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 59.5, 36.6)
		s:Talk(dran)
		s:Turnin(2283, "Necklace Recovery")
		s:Accept(2284, "Necklace Recovery, Take 2")
		s:Note("Then back to Uldaman.")
	end)

	-- second visit: the paladin's remains
	g:Step(function(s)
		s.skip = "done 2284"
		s:Goto(BADLANDS, 44.3, 12.0)
		s:Do("Enter Uldaman with your group.")
		s:Note("Only the paladin's remains this time.")
	end)

	g:Step(function(s)
		s:Talk(remains)
		s:Turnin(2284, "Necklace Recovery, Take 2")
		s:Accept(2318, "Translating the Journal")
		s:Note("Inside the dungeon.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 2.4, 46.1)
		s:Talk(jarkal)
		s:Turnin(2318, "Translating the Journal")
		s:Accept(2338, "Translating the Journal")
		s:Turnin(2338, "Translating the Journal")
		s:Accept(2339, "Find the Gems and Power Source")
		s:Note("Back in Kargath: he borrows the necklace and reads the journal for you.")
	end)

	-- third visit: the gems and the power source
	g:Step(function(s)
		s.skip = "ready 2339 or done 2339"
		s:Goto(BADLANDS, 44.3, 12.0)
		s:Do("Enter Uldaman with your group.")
	end)

	g:Side("out2", function(s)
		s:Collect(g.Item("Shattered Necklace Ruby", 7669), { quest = 2339, objective = 1 })
		s:Note("In a ", g.Object("Shadowforge Cache"), ", in a barricaded Shadowforge area.")
	end)

	g:Side("out2", function(s)
		s:Collect(g.Item("Shattered Necklace Topaz", 7671), { quest = 2339, objective = 3 })
		s:Note("In a ", g.Object("Conspicuous Urn"), ", in the trogg area near the lost Alliance dwarves.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Grimlok", 4854))
		s:Collect(g.Item("Shattered Necklace Sapphire", 7670), { quest = 2339, objective = 2 })
		s:Note("The trogg chieftain.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Archaedas", 2748))
		s:Collect(g.Item("Shattered Necklace Power Source", 7672), { quest = 2339, objective = 4 })
		s:Note("The last boss.")
	end)

	g:Step(function(s)
		s.label = "out2"
		s:Goto(BADLANDS, 2.4, 46.1)
		s:Talk(jarkal)
		s:Turnin(2339, "Find the Gems and Power Source")
		s:Note("His next quest, Deliver the Gems, takes the necklace back to Dran Droffers in Orgrimmar.")
	end)
end)
