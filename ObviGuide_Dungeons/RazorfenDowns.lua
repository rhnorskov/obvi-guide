-- Razorfen Downs (Alliance and Horde, 35-42): the quests Attune lists for the dungeon. Both factions: A Host of Evil
-- outside the entrance and Scourge of the Downs with Belnistrasz inside. Alliance: Bring the Light (Amnennar the
-- Coldbringer) from Stormwind. Horde: Bring the End from the Undercity, and An Unholy Alliance, which starts from the
-- Small Scroll Charlga Razorflank drops in Razorfen Kraul. Quest, NPC and item ids and positions from Attune
-- (CixiDelmont) and QuestieDB's Forever data; the entrance from DungeonJournal (Exehn). See README.md.

local BARRENS, STORMWIND, UNDERCITY = 1413, 1453, 1458

-- the quilboar and cultists around the entrance, for A Host of Evil
local function hostOfEvil(g, s)
	s:Goto(BARRENS, 48.6, 89.8)
	s:Kill(g.Mob("Razorfen Battleguard", 7873), { quest = 6626, objective = 1 })
	s:Kill(g.Mob("Razorfen Thornweaver", 7874), { quest = 6626, objective = 2 })
	s:Kill(g.Mob("Death's Head Cultist", 7872), { quest = 6626, objective = 3 })
	s:Note("All along the thorny paths below the entrance; the cultists also stand further north-west, around 45.9, 87.7.")
end

-- inside: Belnistrasz first, Amnennar is the last boss
local function belnistrasz(g, s)
	s:Talk(g.Npc("Belnistrasz", 8516))
	s:Accept(3523, "Scourge of the Downs")
	s:Turnin(3523, "Scourge of the Downs")
	s:Note("Locked in a pen on the left side of the Murder Pens, after the Caller's Chamber. He then offers Extinguishing the Idol, an escort: take it together with your group, as it starts right away.")
end

ObviGuide.Guide(function(g)
	g.title = "Razorfen Downs: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-razorfen-downs"
	g.next  = "obvi-uldaman"
	g.only  = "Alliance"

	local myriam     = g.Npc("Myriam Moonsinger", 12866)
	local benedictus = g.Npc("Archbishop Benedictus", 1284)

	g:Step(function(s)
		s:Goto(STORMWIND, 50.3, 45.5)
		s:Talk(benedictus)
		s:Accept(3636, "Bring the Light")
		s:Note("Inside the Cathedral of Light.")
	end)

	-- the far south of the Barrens, on the border with Thousand Needles
	g:Step(function(s)
		s:Goto(BARRENS, 49.0, 94.9)
		s:Talk(myriam)
		s:Accept(6626, "A Host of Evil")
		s:Note("Up the path, just below the dungeon entrance.")
	end)

	g:Step(function(s) hostOfEvil(g, s) end)

	g:Step(function(s)
		s:Goto(BARRENS, 49.0, 94.9)
		s:Talk(myriam)
		s:Turnin(6626, "A Host of Evil")
	end)

	g:Step(function(s)
		s.skip = "done 3523 or ready 3636 or done 3636"   -- (been inside already)
		s:Goto(BARRENS, 50.0, 92.0)
		s:Do("Enter Razorfen Downs with your group.")
	end)

	g:Step(function(s) belnistrasz(g, s) end)

	g:Step(function(s)
		s:Kill(g.Mob("Amnennar the Coldbringer", 7358), { quest = 3636, objective = 1 })
		s:Note("The last boss, at the top of the spiral at the far end of the dungeon.")
	end)

	g:Step(function(s)
		s.label = "out"
		s:Goto(STORMWIND, 50.3, 45.5)
		s:Talk(benedictus)
		s:Turnin(3636, "Bring the Light")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Razorfen Downs: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-razorfen-downs-horde"
	g.next  = "obvi-uldaman-horde"
	g.only  = "Horde"

	local myriam      = g.Npc("Myriam Moonsinger", 12866)
	local varimathras = g.Npc("Varimathras", 2425)
	local andrew      = g.Npc("Andrew Brownell", 2308)
	local scroll      = g.Item("Small Scroll", 17008)

	-- An Unholy Alliance only if you have the scroll from Razorfen Kraul
	g:Step(function(s)
		s.only = "items 17008 >= 1 or onquest 6522 or done 6522"
		s:Use(scroll)
		s:Accept(6522, "An Unholy Alliance")
		s:Note("Charlga Razorflank, the last boss of Razorfen Kraul, drops the ", scroll, ". Without it, skip this and the other Unholy Alliance steps.")
	end)

	g:Step(function(s)
		s.only = "onquest 6522 or done 6522"
		s:Goto(UNDERCITY, 56.2, 92.2)
		s:Talk(varimathras)
		s:Turnin(6522, "An Unholy Alliance")
		s:Accept(6521, "An Unholy Alliance")
		s:Note("In the Royal Quarter.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 74.1, 33.3)
		s:Talk(andrew)
		s:Accept(3341, "Bring the End")
		s:Note("In the Magic Quarter.")
	end)

	-- the far south of the Barrens, on the border with Thousand Needles
	g:Step(function(s)
		s:Goto(BARRENS, 49.0, 94.9)
		s:Talk(myriam)
		s:Accept(6626, "A Host of Evil")
		s:Note("Up the path, just below the dungeon entrance.")
	end)

	g:Step(function(s)
		s.only = "onquest 6521 or done 6521"
		s:Goto(BARRENS, 46.2, 90.2)
		s:Kill(g.Mob("Ambassador Malcin", 12865))
		s:Collect(g.Item("Ambassador Malcin's Head", 17009), { quest = 6521, objective = 1 })
		s:Note("He wanders among the quilboar outside; also look around 47.8, 90.6 and 48.0, 92.4.")
	end)

	g:Step(function(s) hostOfEvil(g, s) end)

	g:Step(function(s)
		s:Goto(BARRENS, 49.0, 94.9)
		s:Talk(myriam)
		s:Turnin(6626, "A Host of Evil")
	end)

	g:Step(function(s)
		s.skip = "done 3523 or ready 3341 or done 3341"   -- (been inside already)
		s:Goto(BARRENS, 50.0, 92.0)
		s:Do("Enter Razorfen Downs with your group.")
	end)

	g:Step(function(s) belnistrasz(g, s) end)

	g:Step(function(s)
		s:Kill(g.Mob("Amnennar the Coldbringer", 7358))
		s:Collect(g.Item("Skull of the Coldbringer", 10420), { quest = 3341, objective = 1 })
		s:Note("The last boss, at the top of the spiral at the far end of the dungeon.")
	end)

	g:Step(function(s)
		s.label = "out"
		s:Goto(UNDERCITY, 74.1, 33.3)
		s:Talk(andrew)
		s:Turnin(3341, "Bring the End")
	end)

	g:Step(function(s)
		s.only = "onquest 6521 or done 6521"
		s:Goto(UNDERCITY, 56.2, 92.2)
		s:Talk(varimathras)
		s:Turnin(6521, "An Unholy Alliance")
	end)
end)
