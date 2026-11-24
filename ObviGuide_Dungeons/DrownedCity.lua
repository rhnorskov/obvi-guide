-- The Drowned City (35-42), WoW Forever's sunken troll city off Stranglethorn Vale. Horde: Kin'weelay's chain at
-- Grom'gol (The Vile Reef, The Gurubashi Legends of Old, Locating the Lost City) to The Drowned City and A Tale Spun
-- Around the Fire, Commander Aggro'gosh's Enemies in the Water and The Only Good Brinescale..., and Mazu'kon's Ancient
-- Gurubashi Idol. Alliance: Loremaster Dibbs' Take Two With Water and Magics of the Drowned City with their
-- follow-ups, and Archmage Timear's Ancient Gurubashi Secrets. Both: Krazek's Shady Saltseers and The Saltseer Captain.
-- Quests, chain order and givers from DungeonJournal (Exehn); NPC, item and object ids and positions from DungeonJournal
-- and Zygor's Drowned City quest guides. See README.md.

local STV, MULGORE, DUROTAR = 1434, 1412, 1411
local HILLSBRAD, ALTERAC, IRONFORGE = 1424, 1416, 1455

local function krazek(g) return g.Npc("Krazek", 773) end

local function saltseers(g, s, accept)
	s:Goto(STV, 26.94, 77.21)
	s:Talk(krazek(g))
	if accept then
		s:Accept(95789, "Shady Saltseers")
		s:Accept(95791, "The Saltseer Captain")
	else
		s:Turnin(95789, "Shady Saltseers")
		s:Turnin(95791, "The Saltseer Captain")
	end
end

local function enter(s, skip)
	s.skip = skip   -- (been inside already)
	s:Goto(STV, 21.95, 27.73)
	s:Do("Enter the Drowned City with your group.")
	s:Note("The entrance is a cave under the water.")
end

-- inside: the tablets (Take Two With Water / The Drowned City), the Saltseers and the idol, in the order you meet them
local function inside(g, tablets, idol, varTaka)
	local function tablet(s, n, item, name)
		s:Collect(g.Item(name, item), { quest = tablets, objective = n }):Only("onquest " .. tablets)
	end

	g:Side("out", function(s)
		s.only = "onquest 95789"
		s:Kill(g.Mob("Saltseer Cultist", 259981))
		s:Kill(g.Mob("Saltseer Murderer", 259979))
		s:Kill(g.Mob("Saltseer Manhunter", 259987))
		s:Collect(g.Item("Voodoo-Infused Artifact", 270333), { count = 10, quest = 95789, objective = 1 })
	end)

	g:Step(function(s)
		s.only = "onquest " .. tablets
		tablet(s, 1, 270308, "The First Tablet of I'lalai")
		s:Note("Past Zul'Alai, down to the left.")
	end)

	g:Step(function(s)
		s.only = "onquest 95791 or onquest " .. tablets
		s:Kill(g.Mob("Captain Dreadrise", 260042), { quest = 95791, objective = 1 }):Only("onquest 95791")
		s:Kill(g.Mob("Saltseer Coroner", 260353), { quest = 95791, objective = 2 }):Only("onquest 95791")
		tablet(s, 2, 270309, "The Second Tablet of I'lalai")
		s:Note("In the pirate area. The second tablet is half hidden under a skull.")
	end)

	g:Step(function(s)
		s.only = (varTaka and "onquest 95776 or " or "") .. "onquest " .. tablets
		if varTaka then
			s:Kill(g.Mob("Var'Taka", 258924), { quest = 95776, objective = 1 }):Only("onquest 95776")
		end
		tablet(s, 3, 270310, "The Third Tablet of I'lalai")
		s:Note("By Var'Taka.")
	end)

	g:Step(function(s)
		s.only = "onquest " .. idol
		s:Kill(g.Mob("Deathless Marrow", 269586))
		s:Collect(g.Item("Ancient Gurubashi Idol", 276894), { quest = idol, objective = 1 })
	end)

	g:Step(function(s)
		s.only = "onquest " .. tablets
		tablet(s, 4, 270311, "The Fourth Tablet of I'lalai")
		s:Note("By Min'loth, the last boss.")
	end)
end

ObviGuide.Guide(function(g)
	g.title = "The Drowned City: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-drowned-city-horde"
	g.only  = "Horde"

	local kinweelay = g.Npc("Kin'weelay", 2519)
	local aggrogosh = g.Npc("Commander Aggro'gosh", 2464)
	local mazukon   = g.Npc("Mazu'kon", 264074)

	g:Step(function(s)
		s:Goto(MULGORE, 33.41, 22.56)
		s:Talk(mazukon)
		s:Accept(96774, "Ancient Gurubashi Idol")
	end)

	g:Step(function(s) saltseers(g, s, true) end)

	-- Kin'weelay's chain to the dungeon
	g:Step(function(s)
		s:Goto(STV, 32.27, 27.71)
		s:Talk(kinweelay)
		s:Accept(629, "The Vile Reef")
	end)

	g:Step(function(s)
		s:Goto(STV, 24.75, 22.84)
		s:Collect(g.Item("Tablet Shard", 4094), { quest = 629, objective = 1 })
		s:Note("From the tablet ", g.Object("Gri'lek the Wanderer"), " under the water. The murlocs are elite.")
	end)

	g:Step(function(s)
		s:Goto(STV, 32.27, 27.71)
		s:Talk(kinweelay)
		s:Turnin(629, "The Vile Reef")
		s:Accept(95748, "The Gurubashi Legends of Old")
	end)

	g:Step(function(s)
		s:Goto(STV, 22.95, 12.02)
		s:Collect(g.Item("The Third Troll Legend", 2007), { quest = 95748, objective = 1 })
		s:Note("A rubbing of the tablet ", g.Object("Fall of Gurubashi"), ".")
	end)

	g:Step(function(s)
		s:Goto(STV, 32.27, 27.71)
		s:Talk(kinweelay)
		s:Turnin(95748, "The Gurubashi Legends of Old")
		s:Accept(95770, "Locating the Lost City")
		s:Talk(aggrogosh)
		s:Accept(95773, "Enemies in the Water")
	end)

	g:Step(function(s)
		s:Goto(STV, 22.95, 27.86)
		s:Kill(g.Mob("Brinescale Skirmisher", 262397))
		s:Collect(g.Item("Brinescale Trident", 270305), { count = 10, quest = 95773, objective = 1 })
	end)

	g:Step(function(s)
		s:Goto(STV, 21.65, 27.67)
		s:Quest(95770, 1, "Find the Drowned City's entrance.")
		s:Note("A cave under the water.")
	end)

	g:Step(function(s)
		s:Goto(STV, 32.27, 27.71)
		s:Talk(kinweelay)
		s:Turnin(95770, "Locating the Lost City")
		s:Accept(95775, "The Drowned City")
		s:Talk(aggrogosh)
		s:Turnin(95773, "Enemies in the Water")
		s:Accept(95776, "The Only Good Brinescale...")
	end)

	g:Step(function(s) enter(s, "ready 95775 or done 95775") end)

	inside(g, 95775, 96774, true)

	-- the turn-ins
	g:Step(function(s)
		s.label = "out"
		s:Goto(STV, 32.27, 27.71)
		s:Talk(kinweelay)
		s:Turnin(95775, "The Drowned City")
		s:Accept(96078, "A Tale Spun Around the Fire")
		s:Talk(aggrogosh)
		s:Turnin(95776, "The Only Good Brinescale...")
	end)

	g:Step(function(s) saltseers(g, s, false) end)

	g:Step(function(s)
		s.only = "onquest 96078"
		s:Goto(DUROTAR, 55.8, 74.4)
		s:Talk(g.Npc("Master Gadrin", 3188))
		s:Turnin(96078, "A Tale Spun Around the Fire")
	end)

	g:Step(function(s)
		s:Goto(MULGORE, 33.41, 22.56)
		s:Talk(mazukon)
		s:Turnin(96774, "Ancient Gurubashi Idol")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "The Drowned City: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-drowned-city"
	g.only  = "Alliance"

	local dibbs  = g.Npc("Loremaster Dibbs", 2277)
	local timear = g.Npc("Archmage Timear", 31439)

	g:Step(function(s) saltseers(g, s, true) end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 50.57, 57.09)
		s:Talk(dibbs)
		s:Accept(95788, "Magics of the Drowned City")
		s:Accept(95787, "Take Two With Water")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 15.42, 73.95)
		s:Talk(timear)
		s:Accept(97130, "Ancient Gurubashi Secrets")
	end)

	g:Step(function(s) enter(s, "ready 95787 or done 95787") end)

	-- the I'lalai Fetishes, from the trolls all through
	g:Side("out", function(s)
		s.only = "onquest 95788"
		s:Kill(g.Mob("Profane Necromancer", 263196))
		s:Kill(g.Mob("Risen Sentry", 258792))
		s:Collect(g.Item("I'lalai Fetish", 270343), { count = 5, quest = 95788, objective = 1 })
	end)

	inside(g, 95787, 97130, false)

	-- the turn-ins
	g:Step(function(s)
		s.label = "out"
		saltseers(g, s, false)
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 50.57, 57.09)
		s:Talk(dibbs)
		s:Turnin(95788, "Magics of the Drowned City")
		s:Turnin(95787, "Take Two With Water")
		s:Accept(95799, "Findings for the Explorer's League")
		s:Accept(95798, "The Web of Magic")
	end)

	g:Step(function(s)
		s:Goto(ALTERAC, 15.42, 73.95)
		s:Talk(timear)
		s:Turnin(97130, "Ancient Gurubashi Secrets")
	end)

	g:Step(function(s)
		s.only = "onquest 95798"
		s:Talk(g.Npc("Abra Cadabra", 252019))
		s:Turnin(95798, "The Web of Magic")
		s:Note("In Dalaran.")
	end)

	g:Step(function(s)
		s.only = "onquest 95799"
		s:Goto(IRONFORGE, 76.4, 12.2)
		s:Talk(g.Npc("Historian Karnik", 2916))
		s:Turnin(95799, "Findings for the Explorer's League")
	end)
end)
