-- Scholomance (55-60): the dungeon quests Attune lists for each faction. Both: Leonid Barthalomew, Betina Bigglezink
-- and Dawn's Gambit, Plagued Hatchlings and Healthy Dragon Scale, Doctor Theolen Krastinov, Krastinov's Bag of Horrors
-- and Kirtonos the Herald, and The Lich, Ras Frostwhisper. Alliance: Barov Family Fortune and The Last Barov from
-- Weldon Barov; Horde: the same two from Alexi Barov. The way in needs the Skeleton Key, which has a guide of its own.
-- Quest, NPC and item ids from Attune (CixiDelmont) and QuestieDB's Forever data, the entrance from DungeonJournal
-- (Exehn). Eva Sarkhoff's three quests follow on from each other, and she stands just outside the door, so the route
-- steps out to her twice in the same run. See README.md.

local BURNING, WPL, EPL, TIRISFAL = 1428, 1422, 1423, 1420

local function npcs(g)
	return {
		leonid  = g.Npc("Leonid Barthalomew the Revered", 11036),
		betina  = g.Npc("Betina Bigglezink", 11035),
		eva     = g.Npc("Eva Sarkhoff", 11216),
		marduke = g.Npc("Magistrate Marduke", 11286),
	}
end

-- Burning Steppes and Light's Hope Chapel
local function lightsHope(g, n)
	g:Step(function(s)
		s.only = "not done 4735 and not onquest 5522 and not done 5522"
		s:Do("Leonid Barthalomew needs Tinkee Steamboil's egg chain first (up to Egg Collection, in Upper Blackrock Spire). Do it first, or tick this to leave it out.")
	end)

	g:Step(function(s)
		s.only = "done 4735 and not onquest 5522 and not done 5522"
		s:Goto(BURNING, 65.2, 24.0)
		s:Talk(g.Npc("Tinkee Steamboil", 10267))
		s:Accept(5522, "Leonid Barthalomew")
		s:Note("At Flame Crest.")
	end)

	g:Step(function(s)
		s.only = "onquest 5522 or done 5522"
		s:Goto(EPL, 71.9, 48.3)
		s:Talk(n.leonid)
		s:Turnin(5522, "Leonid Barthalomew")
		s:Accept(5531, "Betina Bigglezink")
		s:Note("Inside Light's Hope Chapel.")
	end)

	g:Step(function(s)
		s:Goto(EPL, 71.7, 49.9)
		s:Talk(n.betina)
		s:Turnin(5531, "Betina Bigglezink"):Only("onquest 5531")
		s:Accept(4771, "Dawn's Gambit"):Only("onquest 5531 or done 5531")
		s:Accept(5529, "Plagued Hatchlings")
		s:Note("Outside the chapel.")
	end)
end

-- Caer Darrow, by the door
local function caerDarrow(g, n)
	g:Step(function(s)
		s:Goto(WPL, 70.2, 73.7)
		s:Talk(n.eva)
		s:Accept(5382, "Doctor Theolen Krastinov, the Butcher")
		s:Note("A ghost on the island of Caer Darrow, by the keep.")
	end)

	g:Step(function(s)
		s.only = "done 5465 and not onquest 5466 and not done 5466"
		s:Goto(WPL, 70.6, 74.1)
		s:Talk(n.marduke)
		s:Accept(5466, "The Lich, Ras Frostwhisper")
		s:Note("Equip the Spectral Essence to see him.")
	end)
end

local function inside(g, n, barov)
	g:Step(function(s)
		s.skip = "ready 5382 or done 5382"   -- (been inside already)
		s:Goto(WPL, 69.7, 73.2)
		s:Do("Enter Scholomance with your group.")
		s:Note("The crypt door at the back of the keep. You need the Skeleton Key.")
	end)

	g:Side("eva1", function(s)
		s:Kill(g.Mob("Plagued Hatchling", 10678), { quest = 5529, objective = 1 })
		s:Note("In the Great Ossuary, the big room ahead of the Chamber of Summoning.")
	end)

	g:Side("kirtonos", function(s)
		local scale = g.Item("Healthy Dragon Scale", 13920)
		s.only = "done 5529 and not onquest 5582 and not done 5582"
		s:Kill(g.Mob("Plagued Hatchling", 10678))
		s:Use(scale)
		s:Accept(5582, "Healthy Dragon Scale")
		s:Note("Once Plagued Hatchlings is turned in, the hatchlings can drop ", scale, ", which starts a quest.")
	end)

	g:Side("eva1", function(s)
		s:Collect(g.Item("The Deed to Southshore", 13450), { quest = barov, objective = 3 })
		s:Note("On a table in the north-east of the Reliquary, the first room.")
	end)

	g:Side("eva1", function(s)
		s:Collect(g.Item("The Deed to Tarren Mill", 13451), { quest = barov, objective = 4 })
		s:Note("On a table to the left as you come into the Great Ossuary.")
	end)

	g:Side("eva1", function(s)
		s:Collect(g.Item("The Deed to Brill", 13471), { quest = barov, objective = 1 })
		s:Note("On a ledge in the south-west of the Laboratory, below the Viewing Room.")
	end)

	g:Side("eva1", function(s)
		s:Collect(g.Item("The Deed to Caer Darrow", 13448), { quest = barov, objective = 2 })
		s:Note("On a table in the east of the Barov Family Vault, below the Headmaster's Study.")
	end)

	g:Step(function(s)
		s:Say(g.Warn("Leave Jandice Barov alive for now"), ": Krastinov's Bag of Horrors only drops from her once you have its quest from Eva. She's in the room right of the stairs past the Chamber of Summoning.")
		s:Kill(g.Mob("Rattlegore", 11622))
		s:Note("Downstairs in the Great Ossuary: drop through a hole in the floor. He drops the Viewing Room Key (one for the group is enough).")
	end)

	g:Step(function(s)
		s.only = "onquest 4771 or done 4771"
		s:Use(g.Item("Dawn's Gambit", 12368))
		s:Kill(g.Mob("Vectus", 10432), { quest = 4771, objective = 1 })
		s:Note("In the Viewing Room: clear it first, then use the Gambit there and kill Vectus.")
	end)

	g:Step(function(s)
		s.only = "onquest 5466"
		s:Use(g.Item("Soulbound Keepsake", 13752))
		s:Kill(g.Mob("Ras Frostwhisper", 10508))
		s:Collect(g.Item("Human Head of Ras Frostwhisper", 13626), { quest = 5466, objective = 1 })
		s:Note("In the Laboratory, below the Viewing Room. Use the Keepsake on him to make him mortal first.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Doctor Theolen Krastinov", 11261), { quest = 5382, objective = 1 })
		s:Quest(5382, 2, "Burn the Remains of Eva Sarkhoff.")
		s:Quest(5382, 3, "Burn the Remains of Lucien Sarkhoff.")
		s:Note("Off the upper level of the Headmaster's Study, in the room opposite the way in; the two piles of bones are in his room.")
	end)

	-- out to Eva, back in for Jandice, out again, back in for Kirtonos
	g:Step(function(s)
		s.label = "eva1"
		s:Goto(WPL, 70.2, 73.7)
		s:Talk(n.eva)
		s:Turnin(5382, "Doctor Theolen Krastinov, the Butcher")
		s:Accept(5515, "Krastinov's Bag of Horrors")
		s:Note("Step outside: she's by the door. The instance stays as it is.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Jandice Barov", 10503))
		s:Collect(g.Item("Krastinov's Bag of Horrors", 13725), { quest = 5515, objective = 1 })
		s:Note("Back in: right and down the stairs past the Chamber of Summoning. Kill the real one among her images.")
	end)

	g:Step(function(s)
		s:Goto(WPL, 70.2, 73.7)
		s:Talk(n.eva)
		s:Turnin(5515, "Krastinov's Bag of Horrors")
		s:Accept(5384, "Kirtonos the Herald")
		s:Note("She gives you the ", g.Item("Blood of Innocents", 13523), ".")
	end)

	g:Step(function(s)
		s.label = "kirtonos"
		s:Kill(g.Mob("Kirtonos the Herald", 10506), { quest = 5384, objective = 1 })
		s:Note("Back in: out on the porch off the Chamber of Summoning. Clear the room, then put the Blood in the ", g.Object("Brazier of the Herald"), " and pull him back through the gate.")
	end)
end

local function after(g, n)
	g:Step(function(s)
		s.label = "out"
		s:Goto(WPL, 70.2, 73.7)
		s:Talk(n.eva)
		s:Turnin(5384, "Kirtonos the Herald")
		s:Note("Her next quest starts the chain for The Lich, Ras Frostwhisper.")
	end)

	g:Step(function(s)
		s.only = "onquest 5466"
		s:Goto(WPL, 70.6, 74.1)
		s:Talk(n.marduke)
		s:Turnin(5466, "The Lich, Ras Frostwhisper")
	end)
end

local function betinaTurnins(g, n)
	g:Step(function(s)
		s:Goto(EPL, 71.7, 49.9)
		s:Talk(n.betina)
		s:Turnin(5529, "Plagued Hatchlings")
		s:Turnin(4771, "Dawn's Gambit"):Only("onquest 4771")
		s:Turnin(5582, "Healthy Dragon Scale"):Only("onquest 5582")
		s:Note("Healthy Dragon Scale can only come on a later run, after Plagued Hatchlings is turned in.")
	end)

	g:Step(function(s)
		s.only = "not done 5465 and not onquest 5466 and not done 5466"
		s:Do("The Lich, Ras Frostwhisper comes at the end of Eva Sarkhoff's next chain (The Human, Ras Frostwhisper up to Soulbound Keepsake, which runs through Stratholme). Come back for it on a later run, or tick this to leave it out.")
	end)
end

-- Alliance -------------------------------------------------------------------------------------------------------

ObviGuide.Guide(function(g)
	g.title = "Scholomance: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-scholomance"
	g.next  = "obvi-stratholme"
	g.only  = "Alliance"
	local BAROV = 5343

	local n = npcs(g)
	local weldon = g.Npc("Weldon Barov", 11023)

	lightsHope(g, n)

	g:Step(function(s)
		s:Goto(WPL, 43.5, 83.7)
		s:Talk(weldon)
		s:Accept(5343, "Barov Family Fortune")
		s:Note("At Chillwind Camp.")
	end)

	caerDarrow(g, n)
	inside(g, n, BAROV)
	after(g, n)

	g:Step(function(s)
		s:Goto(WPL, 43.5, 83.7)
		s:Talk(weldon)
		s:Turnin(5343, "Barov Family Fortune")
		s:Accept(5344, "The Last Barov")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 71.6)
		s:Kill(g.Mob("Alexi Barov", 11022))
		s:Collect(g.Item("Head of Alexi Barov", 13470), { quest = 5344, objective = 1 })
		s:Note(g.Warn("Horde territory"), ": he's in the Bulwark, on the Tirisfal side of the border, among its guards. Bring friends.")
	end)

	g:Step(function(s)
		s:Goto(WPL, 43.5, 83.7)
		s:Talk(weldon)
		s:Turnin(5344, "The Last Barov")
	end)

	betinaTurnins(g, n)
end)

-- Horde ----------------------------------------------------------------------------------------------------------

ObviGuide.Guide(function(g)
	g.title = "Scholomance: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-scholomance-horde"
	g.next  = "obvi-stratholme-horde"
	g.only  = "Horde"
	local BAROV = 5341

	local n = npcs(g)
	local alexi = g.Npc("Alexi Barov", 11022)

	lightsHope(g, n)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 71.6)
		s:Talk(alexi)
		s:Accept(5341, "Barov Family Fortune")
		s:Note("At the Bulwark, on the border with the Western Plaguelands.")
	end)

	caerDarrow(g, n)
	inside(g, n, BAROV)
	after(g, n)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 71.6)
		s:Talk(alexi)
		s:Turnin(5341, "Barov Family Fortune")
		s:Accept(5342, "The Last Barov")
	end)

	g:Step(function(s)
		s:Goto(WPL, 43.5, 83.7)
		s:Kill(g.Mob("Weldon Barov", 11023))
		s:Collect(g.Item("Head of Weldon Barov", 13469), { quest = 5342, objective = 1 })
		s:Note(g.Warn("Alliance territory"), ": he's in Chillwind Camp, among its guards. Bring friends.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 71.6)
		s:Talk(alexi)
		s:Turnin(5342, "The Last Barov")
	end)

	betinaTurnins(g, n)
end)
