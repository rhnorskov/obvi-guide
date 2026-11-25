-- A Brother In Need (Alliance paladins): Katherine the Pure's chain up to Orders from the Grand Crusader, the start of
-- the Aeonas quests in Scarlet Monastery. The Strange Orb (Darkshore) to Delgren the Purifier, Ursula Deline's
-- Summoner's Salt and the Spear of Mannoroth, then the Broken Warhammer at the Mannoroc Coven, and the orders from
-- Aeonas's hut on the Wetlands coast. Quests and places from DungeonJournal (Exehn), NPC ids and Stormwind positions
-- from QuestieDB's Forever data. Quest Catchup takes its steps from here. See README.md.

local STORMWIND, DARKSHORE, ASHENVALE, DESOLACE, WETLANDS = 1453, 1439, 1440, 1443, 1437

ObviGuide.Guide(function(g)
	g.title = "A Brother In Need"
	g.group = "Extras"
	g.id    = "obvi-brother-in-need"
	g.only  = "Alliance and Paladin"
	g.next  = "obvi-scarlet-monastery"

	local delgren   = g.Npc("Delgren the Purifier", 3663)
	local katherine = g.Npc("Katherine the Pure", 5492)
	local ursula    = g.Npc("Ursula Deline", 5495)

	g:Step(function(s)
		s:Goto(DARKSHORE, 56.2, 26.4)
		s:Say("Click the ", g.Object("Strange Orb"), ".")
		s:Accept(78088, "A Strange Artifact")
		s:Note("On top of the Tower of Althalaxx.")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 26.2, 38.7)
		s:Talk(delgren)
		s:Turnin(78088, "A Strange Artifact")
		s:Accept(78089, "Advice From Stormwind")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Turnin(78089, "Advice From Stormwind")
		s:Accept(78090, "A Second Opinion")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 39.3, 84.9)
		s:Talk(ursula)
		s:Turnin(78090, "A Second Opinion")
		s:Accept(78091, "Earning Your Salt")
		s:Note("In the Slaughtered Lamb's cellar.")
	end)

	g:Step(function(s)
		s:Quest(78091, 1, "Collect 14 Summoner's Salt from the Blackrock orcs in Redridge Mountains.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 39.3, 84.9)
		s:Talk(ursula)
		s:Turnin(78091, "Earning Your Salt")
		s:Accept(78092, "It Must Be Destroyed")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 89.0, 77.0)
		s:Quest(78092, 1, "Collect 12 Motes of Mannoroth from the demons.")
		s:Say("Use the ", g.Object("Spear of Mannoroth"), ".")
		s:Turnin(78092, "It Must Be Destroyed")
		s:Say("Click the ", g.Object("Shattered Orb"), ".")
		s:Accept(78093, "Return to Delgren")
		s:Note("Demon Fall Canyon.")
	end)

	g:Step(function(s)
		s:Goto(ASHENVALE, 26.2, 38.7)
		s:Talk(delgren)
		s:Turnin(78093, "Return to Delgren")
	end)

	-- level 35 from here
	g:Step(function(s)
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Accept(96438, "Battle at the Mannoroc Coven")
		s:Note("Needs level 35.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 52.7, 84.8)
		s:Say("Click the ", g.Object("Broken Warhammer"), ".")
		s:Turnin(96438, "Battle at the Mannoroc Coven")
		s:Accept(79939, "The Broken Hammer")
		s:Quest(79939, 1, "Find the Torn Letter.")
		s:Note("From a ", g.Mob("Burning Blade Summoner"), ".")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Turnin(79939, "The Broken Hammer")
		s:Accept(79940, "A Lost Brother")
		s:Turnin(79940, "A Lost Brother")
		s:Note("Let her finish talking.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 8.1, 58.5)
		s:Do("Take the small boat south of the docks to Aeonas's hut, inspect the fallen Scarlet Crusader and kill the assassin.")
		s:Accept(79945, "Orders from the Grand Crusader")
		s:Note("The assassin is a level 40 elite. Use the orders it drops.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 48.5, 49.1)
		s:Talk(katherine)
		s:Turnin(79945, "Orders from the Grand Crusader")
		s:Accept(79946, "A Brother In Need")
	end)
end)
