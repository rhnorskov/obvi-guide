-- Razorfen Kraul (25-34): the quests Attune lists for each faction. Both: Blueleaf Tubers from Ratchet and Willix
-- the Importer inside. Alliance: Lonebrow's Journal and The Crone of the Kraul, and Mortality Wanes from Heralath inside.
-- Horde: Going, Going, Guano!, A Vengeful Fate, and An Unholy Alliance from Charlga's Small Scroll. Quest, NPC, item
-- and object ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance from DungeonJournal
-- (Exehn). See README.md.

local BARRENS, NEEDLES, FERALAS, DARNASSUS = 1413, 1441, 1444, 1457
local UNDERCITY, THUNDERBLUFF = 1458, 1456

local mebok = { "Mebok Mizzyrix", 3446 }

-- Ratchet: Mebok hands out the quest, the gear for it lies in the boxes beside him
local function tubersPickup(g)
	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(g.Npc(mebok[1], mebok[2]))
		s:Accept(1221, "Blueleaf Tubers")
		s:Collect(g.Item("Crate With Holes", 5880), { quest = 1221, objective = 2 })
		s:Collect(g.Item("Snufflenose Command Stick", 6684), { quest = 1221, objective = 4 })
		s:Collect(g.Item("Snufflenose Owner's Manual", 5897), { quest = 1221, objective = 3 })
		s:Note("In Ratchet. The crate, command stick and manual lie right beside him: take one of each and read the manual.")
	end)
end

local function tubersTurnin(g)
	g:Step(function(s)
		s:Goto(BARRENS, 62.4, 37.6)
		s:Talk(g.Npc(mebok[1], mebok[2]))
		s:Turnin(1221, "Blueleaf Tubers")
	end)
end

local function enter(g, skip)
	g:Step(function(s)
		s:Goto(BARRENS, 42.9, 90.2)
		s.skip = skip   -- (been inside already)
		s:Do("Enter Razorfen Kraul with your group.")
		s:Note("In the far south of the Barrens, at the end of the thorny corridor.")
	end)
end

local function insideSides(g)
	g:Side("out", function(s)
		s:Use(g.Item("Crate With Holes", 5880))
		s:Use(g.Item("Snufflenose Command Stick", 6684))
		s:Collect(g.Item("Blueleaf Tuber", 5876), { count = 6, quest = 1221, objective = 1 })
		s:Note("Let the gopher out of the crate, then use the stick on it: it digs up the tubers nearby. Keep at it all the way through.")
	end)

	-- Willix: an escort that can fail, so it never holds the guide up
	g:Side("out", function(s)
		local willix = g.Npc("Willix the Importer", 4508)
		s:Talk(willix)
		s:Accept(1144, "Willix the Importer")
		s:Quest(1144, 1, "Escort Willix out of Razorfen Kraul.")
		s:Turnin(1144, "Willix the Importer")
		s:Note("He's a captive partway in. Clear the way back first: he walks to the entrance, and you hand the quest in to him there.")
	end)
end

ObviGuide.Guide(function(g)
	g.title = "Razorfen Kraul: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-razorfen-kraul"
	g.next  = "obvi-gnomeregan"
	g.only  = "Alliance"

	local falfindel = g.Npc("Falfindel Waywarder", 4048)

	tubersPickup(g)

	-- Lonebrow's Journal starts the Crone of the Kraul: down the Great Lift into Thousand Needles, then west to
	-- Thalanaar, and back up past the kraul
	g:Step(function(s)
		local journal = g.Item("Henrig Lonebrow's Journal", 5791)
		s:Goto(NEEDLES, 30.7, 24.4)
		s:Use(journal):Only("not onquest 1100 and not done 1100")
		s:Accept(1100, "Lonebrow's Journal")
		s:Note("In north-west Thousand Needles: pick up the ", journal, " that lies here, and use it.")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 89.6, 46.6)
		s:Talk(falfindel)
		s:Turnin(1100, "Lonebrow's Journal")
		s:Accept(1101, "The Crone of the Kraul")
		s:Note("At Thalanaar, on the eastern edge of Feralas, west from Thousand Needles. Get its flight path.")
	end)

	enter(g, "ready 1101 or done 1101")

	insideSides(g)

	g:Side("out", function(s)
		s:Talk(g.Npc("Heralath Fallowbrook", 4510))
		s:Accept(1142, "Mortality Wanes")
		s:Collect(g.Item("Treshala's Pendant", 5825), { quest = 1142, objective = 1 })
		s:Note("Heralath lies dead in the kraul. The pendant drops from the quilboar once you have the quest.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Charlga Razorflank", 4421))
		s:Collect(g.Item("Razorflank's Medallion", 5792), { quest = 1101, objective = 1 })
		s:Note("The last boss, at the far end.")
	end)

	-- out: Thalanaar, Ratchet, and Darnassus whenever you're there next
	g:Step(function(s)
		s.label = "out"
		s:Goto(FERALAS, 89.6, 46.6)
		s:Talk(falfindel)
		s:Turnin(1101, "The Crone of the Kraul")
		s:Note("Then fly towards Ratchet.")
	end)

	tubersTurnin(g)

	g:Step(function(s)
		s.only = "onquest 1142 or done 1142"
		s:Goto(DARNASSUS, 69.5, 67.8)
		s:Talk(g.Npc("Treshala Fallowbrook", 4521))
		s:Turnin(1142, "Mortality Wanes")
		s:Note("It can wait for your next time in Darnassus.")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Razorfen Kraul: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-razorfen-kraul-horde"
	g.next  = "obvi-gnomeregan-horde"
	g.only  = "Horde"

	local faranell   = g.Npc("Master Apothecary Faranell", 2055)
	local stonespire = g.Npc("Auld Stonespire", 4451)

	-- Undercity first, then the zeppelin and a flight to Ratchet
	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Accept(1109, "Going, Going, Guano!")
		s:Note("In the Apothecarium. Then take the zeppelin to Orgrimmar and fly to Ratchet.")
	end)

	tubersPickup(g)

	g:Step(function(s)
		s:Goto(THUNDERBLUFF, 36.0, 59.9)
		s:Talk(stonespire)
		s:Accept(1102, "A Vengeful Fate")
		s:Note("Then fly to Camp Taurajo and ride south to the kraul.")
	end)

	enter(g, "ready 1102 or done 1102")

	insideSides(g)

	g:Side("out", function(s)
		s:Kill(g.Mob("Kraul Bat", 4538))
		s:Kill(g.Mob("Greater Kraul Bat", 4539))
		s:Collect(g.Item("Kraul Guano", 5801), { quest = 1109, objective = 1 })
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Charlga Razorflank", 4421))
		s:Collect(g.Item("Razorflank's Heart", 5793), { quest = 1102, objective = 1 })
		s:Note("The last boss, at the far end.")
	end)

	g:Step(function(s)
		local scroll = g.Item("Small Scroll", 17008)
		s:Use(scroll):Only("not onquest 6522 and not done 6522")
		s:Accept(6522, "An Unholy Alliance")
		s:Note("Charlga drops the ", scroll, ": it starts the quest.")
	end)

	-- out: Thunder Bluff, Ratchet, then Undercity
	g:Step(function(s)
		s.label = "out"
		s:Goto(THUNDERBLUFF, 36.0, 59.9)
		s:Talk(stonespire)
		s:Turnin(1102, "A Vengeful Fate")
		s:Note("Fly from Camp Taurajo.")
	end)

	tubersTurnin(g)

	g:Step(function(s)
		s:Goto(UNDERCITY, 48.8, 69.3)
		s:Talk(faranell)
		s:Turnin(1109, "Going, Going, Guano!")
		s:Note("His next quest, Hearts of Zeal, is for the Scarlet Monastery.")
	end)

	g:Step(function(s)
		s.only = "onquest 6522 or done 6522"
		s:Goto(UNDERCITY, 56.3, 92.2)
		s:Talk(g.Npc("Varimathras", 2425))
		s:Turnin(6522, "An Unholy Alliance")
		s:Note("In the Royal Quarter. His next quest leads to Razorfen Downs.")
	end)
end)
