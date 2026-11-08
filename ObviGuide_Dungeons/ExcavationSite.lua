-- Excavation Site: Wetlands (24-29): the quests Attune lists for each faction. Alliance: Caitlin Grassman's chain
-- (Lost in the Thicket Things, Heartwoven; Seeking Caitlin handed in if you have it), Daily Delivery and Highland
-- Hides, Rethiel the Greenwarden's chain up to Horrors in the Highland, Songblade Search and Fallen in the Fen, and
-- Lost Relic Carry from the Relic Guardian. Horde: Dragonmaw Rumors and Open the Maw, Changing Tastes, and Elder
-- Knowledge from the Relic Guardian. Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's
-- Forever data; the entrance from DungeonJournal (Exehn). See README.md.

local WETLANDS, REDRIDGE = 1437, 1433
local ARATHI, ORGRIMMAR, THUNDER_BLUFF = 1417, 1454, 1456

-- the dungeon portal: under a big tree in the hills south-east of Whelgar's Excavation
local function enter(s, skip)
	s.skip = skip   -- (been inside already)
	s:Goto(WETLANDS, 47.7, 56.2)
	s:Do("Enter the Excavation Site with your group.")
	s:Note("A blue portal under a large tree in the hills south-east of Whelgar's Excavation; walk up from Thelgen Rock.")
end

ObviGuide.Guide(function(g)
	g.title = "Excavation Site: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-excavation-site"
	g.next  = "obvi-blackfathom-deeps"
	g.only  = "Alliance"

	local dorin    = g.Npc("Dorin Songblade", 956)
	local caitlin  = g.Npc("Caitlin Grassman", 1480)
	local halloran = g.Npc("James Halloran", 2094)
	local rethiel  = g.Npc("Rethiel the Greenwarden", 1244)
	local relic    = g.Item("Titan Relic", 270865)

	-- Lakeshire first: Dorin's brother went missing in the dig
	g:Step(function(s)
		s:Goto(REDRIDGE, 25.8, 46.4)
		s:Talk(dorin)
		s:Accept(95772, "Songblade Search")
		s:Note("Inside the building in Lakeshire.")
	end)

	-- Menethil Harbor. (Seeking Caitlin, from Llana in Astranaar, only leads to her: she gives her quest without it,
	-- so the guide doesn't send you across the sea for it, but hands it in if you have it.)
	g:Step(function(s)
		s:Goto(WETLANDS, 11.9, 58.8)
		s:Talk(caitlin)
		s:Turnin(95737, "Seeking Caitlin"):Only("onquest 95737")
		s:Accept(95647, "Lost in the Thicket Things")
		s:Note("Inside the building. From Lakeshire, fly to Menethil Harbor if you have the flight path; otherwise fly to Ironforge and ride north through Loch Modan.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 8.6, 55.7)
		s:Talk(halloran)
		s:Accept(484, "Young Crocolisk Skins")
		s:Accept(98815, "Highland Hides")
		s:Note("He walks around the tannery.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 10.9, 59.6)
		s:Talk(g.Npc("First Mate Fitzsimmons", 1239))
		s:Accept(463, "The Greenwarden")
	end)

	-- east along the road: Einar, then the Greenwarden
	g:Step(function(s)
		s.only = "not done 484 or onquest 469 or done 469"   -- (not offered once Young Crocolisk Skins is turned in)
		s:Goto(WETLANDS, 49.9, 39.4)
		s:Talk(g.Npc("Einar Stonegrip", 2093))
		s:Accept(469, "Daily Delivery")
		s:Note("Carry the bundle back to Menethil later.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 56.4, 40.4)
		s:Talk(rethiel)
		s:Turnin(463, "The Greenwarden")
		s:Accept(276, "Tramping Paws")
		s:Note("He walks around.")
	end)

	g:Side("next", function(s)
		s:Kill(g.Mob("Young Wetlands Crocolisk", 1417))
		s:Collect(g.Item("Young Crocolisk Skin", 3397), { count = 4, quest = 484, objective = 1 })
		s:Note("Along the rivers and lakes on the way south.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 61.5, 66.0)
		s:Kill(g.Mob("Mosshide Gnoll", 1007), { quest = 276, objective = 1 })
		s:Kill(g.Mob("Mosshide Mongrel", 1008), { quest = 276, objective = 2 })
		s:Note("South-east, from 60, 60 down to 63, 75.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 53.4, 38.6)
		s:Kill(g.Mob("Young Wetlands Crocolisk", 1417))
		s:Collect(g.Item("Young Crocolisk Skin", 3397), { count = 4, quest = 484, objective = 1 })
		s:Note("In the water north of Rethiel, if you still need some.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 56.4, 40.4)
		s:Talk(rethiel)
		s:Turnin(276, "Tramping Paws")
		s:Accept(277, "Fire Taboo")
	end)

	-- west for the flints, then back to Menethil on the way
	g:Step(function(s)
		s:Goto(WETLANDS, 32.5, 32.5)
		s:Kill(g.Mob("Mosshide Trapper", 1011))
		s:Kill(g.Mob("Mosshide Brute", 1012))
		s:Collect(g.Item("Crude Flint", 2611), { count = 9, quest = 277, objective = 1 })
		s:Note("The gnolls of the Mosshide camps in the west, around 31, 32 and 35, 27.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 8.6, 55.7)
		s:Talk(halloran)
		s:Turnin(469, "Daily Delivery")
		s:Turnin(484, "Young Crocolisk Skins")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 56.4, 40.4)
		s:Talk(rethiel)
		s:Turnin(277, "Fire Taboo")
		s:Accept(275, "Blisters on The Land")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 54.0, 38.5)
		s:Kill(g.Mob("Fen Creeper", 1040), { quest = 275, objective = 1 })
		s:Note("Stealthed, near the water around Rethiel; more west along the river to 45, 32.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 56.4, 40.4)
		s:Talk(rethiel)
		s:Turnin(275, "Blisters on The Land")
		s:Accept(95646, "Horrors in the Highland")
	end)

	g:Step(function(s) enter(s, "ready 95646 or done 95646") end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Thicket Lurker", 260800))
		s:Kill(g.Mob("Thicket Hunter", 260801))
		s:Collect(g.Item("Thicket Raptor Hide", 284845), { count = 4, quest = 98815, objective = 1 })
		s:Note("From the raptors, Shadetooth among them.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Saltspine", 260322))
		s:Note("The first boss. Clear the trash around him first.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Shadetooth", 260325))
		s:Note("The second boss, with two Thicket Hunters.")
	end)

	g:Step(function(s)
		s.only = "onquest 95772 or done 95772"
		s:Talk(g.Npc("Daewyn Songblade", 262465))
		s:Turnin(95772, "Songblade Search")
		s:Accept(95795, "Fallen in the Fen")
		s:Note("In a tent south of the Highland Horror.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Highland Horror", 260808))
		s:Collect(g.Item("Horrible Rootcore", 270180), { quest = 95646, objective = 1 })
		s:Note("Near the Lost Dig Site, where the Dragonmaw are.")
	end)

	g:Step(function(s)
		local ardin = g.Npc("Ardin Grassman", 262681)
		s:Talk(ardin)
		s:Quest(95647, 1, "Find out what happened to ", ardin, ".")
		s:Turnin(95647, "Lost in the Thicket Things")
		s:Accept(95809, "Heartwoven")
		s:Note("On a ramp to the right, just before the Relic Guardian.")
	end)

	g:Step(function(s)
		s:Say("Click the ", g.Object("Archival Panel"), " to the right of the boss to start the fight.")
		s:Kill(g.Mob("Relic Guardian", 260326))
		s:Use(relic):Only("not onquest 95810 and not done 95810")
		s:Accept(95810, "Lost Relic Carry")
		s:Note("The last boss drops the ", relic, ": it starts the quest.")
	end)

	-- the turn-ins: Rethiel, Whelgar on the way west, then Menethil and Lakeshire
	g:Step(function(s)
		s.label = "out"
		s:Goto(WETLANDS, 56.4, 40.4)
		s:Talk(rethiel)
		s:Turnin(95646, "Horrors in the Highland")
	end)

	g:Step(function(s)
		s.only = "onquest 95810 or done 95810"
		s:Goto(WETLANDS, 38.8, 52.4)
		s:Talk(g.Npc("Prospector Whelgar", 1077))
		s:Turnin(95810, "Lost Relic Carry")
		s:Note("Inside the small cave at Whelgar's Excavation.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 8.6, 55.7)
		s:Talk(halloran)
		s:Turnin(98815, "Highland Hides")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 11.9, 58.8)
		s:Talk(caitlin)
		s:Turnin(95809, "Heartwoven")
	end)

	g:Step(function(s)
		s.only = "onquest 95795 or done 95795"
		s:Goto(REDRIDGE, 25.8, 46.4)
		s:Talk(dorin)
		s:Turnin(95795, "Fallen in the Fen")
		s:Note("Back in Lakeshire; it can wait for your next time there.")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Excavation Site: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-excavation-site-horde"
	g.next  = "obvi-blackfathom-deeps-horde"
	g.only  = "Horde"

	local borstan = g.Npc("Borstan", 3368)
	local agent   = g.Npc("Deathstalker Agent", 13155)
	local relic   = g.Item("Titan Relic", 270866)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 57.2, 53.3)
		s:Talk(borstan)
		s:Accept(95697, "Changing Tastes")
		s:Note("The meat vendor in the Valley of Strength. Then the zeppelin to Undercity and on to Hammerfall.")
	end)

	g:Step(function(s)
		s:Goto(ARATHI, 74.5, 35.6)
		s:Talk(g.Npc("Zaruk", 2787))
		s:Accept(95663, "Dragonmaw Rumors")
		s:Note("In Hammerfall. Then west over Thandol Span into the Wetlands.")
	end)

	g:Step(function(s)
		s:Goto(WETLANDS, 51.5, 59.3)
		s:Talk(agent)
		s:Turnin(95663, "Dragonmaw Rumors")
		s:Accept(95682, "Open the Maw")
		s:Note("On the hills above the Dragonmaw camp, close to the dungeon.")
	end)

	g:Step(function(s) enter(s, "ready 95682 or done 95682") end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Thicket Lurker", 260800))
		s:Kill(g.Mob("Thicket Hunter", 260801))
		s:Collect(g.Item("Thicket Raptor Meat", 271100), { count = 4, quest = 95697, objective = 1 })
		s:Note("From the raptors, Shadetooth among them.")
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Dragonmaw Saboteur", 275045), { quest = 95682, objective = 1 })
		s:Kill(g.Mob("Dragonmaw Warder", 275044), { quest = 95682, objective = 2 })
		s:Kill(g.Mob("Dragonmaw Thaumaturgist", 275046))
		s:Collect(g.Item("Dragonmaw Dispatch", 284844))
		s:Note("Around the Lost Dig Site. The Thaumaturgist carries the dispatch.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Saltspine", 260322))
		s:Note("The first boss. Clear the trash around him first.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Shadetooth", 260325))
		s:Note("The second boss, with two Thicket Hunters.")
	end)

	g:Step(function(s)
		s:Say("Click the ", g.Object("Archival Panel"), " to the right of the boss to start the fight.")
		s:Kill(g.Mob("Relic Guardian", 260326))
		s:Use(relic):Only("not onquest 95664 and not done 95664")
		s:Accept(95664, "Elder Knowledge")
		s:Note("The last boss drops the ", relic, ": it starts the quest.")
	end)

	-- out: the agent by the camp, then Orgrimmar and Thunder Bluff
	g:Step(function(s)
		s.label = "out"
		s:Goto(WETLANDS, 51.5, 59.3)
		s:Talk(agent)
		s:Turnin(95682, "Open the Maw")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 57.2, 53.3)
		s:Talk(borstan)
		s:Turnin(95697, "Changing Tastes")
	end)

	g:Step(function(s)
		s.only = "onquest 95664 or done 95664"
		s:Goto(THUNDER_BLUFF, 71.1, 34.2)
		s:Talk(g.Npc("Bashana Runetotem", 9087))
		s:Turnin(95664, "Elder Knowledge")
		s:Note("On the Elder Rise.")
	end)
end)
