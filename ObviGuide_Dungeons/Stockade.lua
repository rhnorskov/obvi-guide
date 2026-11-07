-- The Stockade (Alliance, 26-29): the quests Attune lists: What Comes Around... from Lakeshire, Crime and Punishment
-- from Darkshire, The Color of Blood and Quell The Uprising in Stormwind, and The Unsent Letter (dropped by Edwin
-- VanCleef in the Deadmines) with Bazil Thredd and The Stockade Riots after it. Quest, NPC and item ids and positions
-- from Attune (CixiDelmont) and QuestieDB's Forever data. See README.md.

local STORMWIND, REDRIDGE, DUSKWOOD = 1453, 1433, 1431

ObviGuide.Guide(function(g)
	g.title = "The Stockade: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-stockade"
	g.next  = "obvi-dalaran"
	g.only  = "Alliance"

	local berton    = g.Npc("Guard Berton", 859)
	local millstipe = g.Npc("Councilman Millstipe", 270)
	local nikova    = g.Npc("Nikova Raskol", 1721)
	local baros     = g.Npc("Baros Alexston", 1646)
	local thelwater = g.Npc("Warden Thelwater", 1719)
	local letter    = g.Item("An Unsent Letter", 2874)

	-- Lakeshire and Darkshire first, then fly to Stormwind
	g:Step(function(s)
		s:Goto(REDRIDGE, 21.2, 46.6)
		s:Talk(berton)
		s:Accept(386, "What Comes Around...")
		s:Note("In Lakeshire. Then fly to Darkshire.")
	end)

	g:Step(function(s)
		s:Goto(DUSKWOOD, 71.9, 47.8)
		s:Talk(millstipe)
		s:Accept(377, "Crime and Punishment")
		s:Note("He walks around inside the town hall. Then fly to Stormwind.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 76.4, 63.7)
		s:Talk(nikova)
		s:Accept(388, "The Color of Blood")
		s:Note("She walks around Old Town.")
	end)

	-- The Unsent Letter: only with VanCleef's letter from the Deadmines
	g:Step(function(s)
		s.only = "items 2874 >= 1 or onquest 373 or done 373"
		s:Goto(STORMWIND, 57.7, 47.9)
		s:Use(letter):Only("not onquest 373 and not done 373")
		s:Accept(373, "The Unsent Letter")
		s:Talk(baros)
		s:Turnin(373, "The Unsent Letter")
		s:Accept(389, "Bazil Thredd")
		s:Note("In the Cathedral Square building. Without the ", letter, " from Edwin VanCleef in the Deadmines there's no Stockade Riots.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 51.5, 69.4)
		s:Talk(thelwater)
		s:Turnin(389, "Bazil Thredd"):Only("onquest 389")
		s:Accept(391, "The Stockade Riots"):Only("done 389 or onquest 389")
		s:Accept(387, "Quell The Uprising")
		s:Note("Inside the Stockade building in the Canal District.")
	end)

	g:Step(function(s)
		s.skip = "ready 387 or done 387"   -- (been inside already)
		s:Goto(STORMWIND, 52.4, 70.0)
		s:Do("Enter the Stockade with your group.")
	end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Defias Prisoner", 1706), { quest = 387, objective = 1 })
		s:Kill(g.Mob("Defias Convict", 1711), { quest = 387, objective = 2 })
		s:Kill(g.Mob("Defias Insurgent", 1715), { quest = 387, objective = 3 })
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Red Wool Bandana", 2909), { count = 10, quest = 388, objective = 1 })
		s:Note("The Defias inside drop them.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Targorr the Dread", 1696))
		s:Collect(g.Item("Head of Targorr", 3630), { quest = 386, objective = 1 })
		s:Note("In one of the side cells near the entrance, or in the room straight north.")
	end)

	g:Step(function(s)
		s.only = "onquest 391 or done 391"
		s:Kill(g.Mob("Bazil Thredd", 1716))
		s:Collect(g.Item("Head of Bazil Thredd", 2926), { quest = 391, objective = 1 })
		s:Note("At the end of the east wing.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Dextren Ward", 1663))
		s:Collect(g.Item("Hand of Dextren Ward", 3628), { quest = 377, objective = 1 })
		s:Note("At the end of the west wing.")
	end)

	-- the turn-ins: Stormwind, then fly to Darkshire and Lakeshire
	g:Step(function(s)
		s.label = "out"
		s:Goto(STORMWIND, 51.5, 69.4)
		s:Talk(thelwater)
		s:Turnin(387, "Quell The Uprising")
		s:Turnin(391, "The Stockade Riots"):Only("onquest 391")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 76.4, 63.7)
		s:Talk(nikova)
		s:Turnin(388, "The Color of Blood")
	end)

	g:Step(function(s)
		s:Goto(DUSKWOOD, 71.9, 47.8)
		s:Talk(millstipe)
		s:Turnin(377, "Crime and Punishment")
	end)

	g:Step(function(s)
		s:Goto(REDRIDGE, 21.2, 46.6)
		s:Talk(berton)
		s:Turnin(386, "What Comes Around...")
	end)
end)
