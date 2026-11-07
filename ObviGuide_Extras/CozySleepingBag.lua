-- Cozy Sleeping Bag (Alliance and Horde, 14+): a trail of notes across both continents, each left at the next spot:
-- the Burned-Out Remains (Westfall or the Barrens, the other faction's side first), the Nailed Plank, Stonetalon
-- Mountains, Loch Modan and the Arathi Highlands. Quest and object ids and positions from Attune (CixiDelmont) and
-- QuestieDB's Forever data. See README.md.

local BARRENS, WESTFALL, STONETALON, LOCH_MODAN, ARATHI = 1413, 1436, 1442, 1432, 1417

-- the trail after the plank is the same for both factions
---@param g ObviGuideGuideBuilder
local function trail(g)
	g:Step(function(s)
		s:Goto(STONETALON, 40.8, 52.6)
		s:Say("Click the ", g.Object("Pocket Litter"), ".")
		s:Turnin(79192, "Stepping Stones")
		s:Accept(79980, "Scramble")
	end)

	g:Step(function(s)
		s:Goto(STONETALON, 39.6, 49.9)
		s:Say("Click the ", g.Object("Mound of Dirt"), ".")
		s:Turnin(79980, "Scramble")
		s:Accept(79974, "Wet Job")
		s:Note("Just north of the litter.")
	end)

	g:Step(function(s)
		s:Goto(LOCH_MODAN, 49.4, 12.9)
		s:Say("Click the ", g.Object("Carved Figurine"), ".")
		s:Turnin(79974, "Wet Job")
		s:Accept(79975, "Eagle's Fist")
		s:Note("Up on the dam at the north end of Loch Modan.")
	end)

	g:Step(function(s)
		s:Goto(ARATHI, 22.5, 24.2)
		s:Say("Click the ", g.Object("Messenger Bag"), ", then the ", g.Object("Hastily Rolled-Up Satchel"), " beside it.")
		s:Turnin(79975, "Eagle's Fist")
		s:Accept(79976, "This Must Be The Place")
		s:Turnin(79976, "This Must Be The Place")
		s:Note("The ", g.Item("Cozy Sleeping Bag", 211527), " is in the satchel.")
	end)
end

-- Alliance: the remains in Westfall send you to the Barrens
ObviGuide.Guide(function(g)
	g.title = "Cozy Sleeping Bag"
	g.group = "Extras"
	g.id    = "obvi-cozy-sleeping-bag"
	g.only  = "Alliance"

	g:Step(function(s)
		s:Goto(WESTFALL, 37.4, 50.7)
		s:Say("Click the ", g.Object("Burned-Out Remains"), ".")
		s:Accept(79008, "... and that note you found")
		s:Note("West of the road through Westfall.")
	end)

	g:Step(function(s)
		s:Goto(BARRENS, 46.4, 73.8)
		s:Say("Click the ", g.Object("Nailed Plank"), ".")
		s:Turnin(79008, "... and that note you found")
		s:Accept(79192, "Stepping Stones")
		s:Note("In the southern Barrens.")
	end)

	trail(g)
end)

-- Horde: the remains in the Barrens send you to Westfall
ObviGuide.Guide(function(g)
	g.title = "Cozy Sleeping Bag"
	g.group = "Extras"
	g.id    = "obvi-cozy-sleeping-bag-horde"
	g.only  = "Horde"

	g:Step(function(s)
		s:Goto(BARRENS, 46.4, 73.9)
		s:Say("Click the ", g.Object("Burned-Out Remains"), ".")
		s:Accept(79007, "... and that note you found")
		s:Note("In the southern Barrens.")
	end)

	g:Step(function(s)
		s:Goto(WESTFALL, 37.4, 50.9)
		s:Say("Click the ", g.Object("Nailed Plank"), ".")
		s:Turnin(79007, "... and that note you found")
		s:Accept(79192, "Stepping Stones")
		s:Note("West of the road through Westfall, Alliance land.")
	end)

	trail(g)
end)
