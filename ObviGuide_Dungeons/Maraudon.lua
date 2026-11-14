-- Maraudon (Alliance and Horde, 41-51): the quests Attune and DungeonJournal (Exehn) list for the dungeon. Both
-- factions: Twisted Evils (Willow), The Pariah's Instructions (the five Khans and the Amulet of Union), Legends of
-- Maraudon and The Scepter of Celebras, Seed of Life from Zaetar's Spirit after Princess Theradras, and Rot and Regret
-- (Woodwyrd, Shen'dralas), the end of a long Shen'dralas chain that is only pointed at. Alliance: Corruption of Earth
-- and Seed and Vyletongue Corruption from Nijel's Point, Shadowshard Fragments from Theramore. Horde: the same two from
-- Shadowprey Village, Shadowshard Fragments from Orgrimmar, and An'she's Radiance from Mulgore. Quest, NPC, item and
-- object ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the entrance, where things are
-- inside and the Forever quests from DungeonJournal (Exehn). See README.md.

local DESOLACE, DUSTWALLOW, ORGRIMMAR, MOONGLADE, MULGORE, SHENDRALAS = 1443, 1445, 1454, 1450, 1412, 2652

-- the people in Desolace both factions visit
local function willow(g, s, turnin)
	s:Goto(DESOLACE, 62.2, 39.6)
	s:Talk(g.Npc("Willow", 13656))
	if turnin then s:Turnin(7028, "Twisted Evils") else s:Accept(7028, "Twisted Evils") end
end

local function pariah(g, s, turnin)
	s:Goto(DESOLACE, 50.4, 86.7)
	s:Talk(g.Npc("Centaur Pariah", 13717))
	if turnin then
		s:Turnin(7067, "The Pariah's Instructions")
	else
		s:Accept(7067, "The Pariah's Instructions")
		s:Use(g.Item("The Pariah's Instructions", 17781))
		s:Note("He wanders this part of southern Desolace. Read the instructions he gives you.")
	end
end

-- Rot and Regret: the end of a long chain in Shen'dralas, south of Desolace; only pointed at, then for those on it
local function woodwyrdPointer(g)
	g:Step(function(s)
		s.skip = "onquest 93594 or done 93594"
		s:Do("Optional: Rot and Regret comes at the end of a long chain in Shen'dralas, south of Desolace. It starts at the ", g.Object("Shen'dralar Pylon"), " there (43.6, 34.2).")
		s:Note("Strange Pylons, then Mordent Evenshade's and Mithera's quests up to Word of the Woods. Without it you just skip Rot and Regret.")
	end)
end

local function woodwyrd(g, s, turnin)
	local vial = g.Item("Vial of Earth Song Water", 258296)
	s:Goto(SHENDRALAS, 53.5, 76.0)
	s:Talk(g.Npc("Woodwyrd", 254674))
	if turnin then
		s.only = "onquest 93404 or done 93404"
		s:Use(vial)
		s:Turnin(93404, "Rot and Regret")
		s:Accept(93601, "Passing the Blame")
		s:Note("Use the ", vial, " on the burning tree next to Woodwyrd, not on Woodwyrd himself. Passing the Blame goes on to Kog'thug the Brave and Agamaggan's Blood, a Razorfen Downs quest.")
	else
		s.only = "onquest 93594 or onquest 93404 or done 93404"
		s:Turnin(93594, "Word of the Woods"):Only("onquest 93594")
		s:Accept(93404, "Rot and Regret")
		s:Note("In the Forlorn Gardens, just east of Mithera.")
	end
end

-- the outer caves, before the instance portals: the Khans' amulet, three of the gems, the shadowshards, Cavindra and
-- the orange pool. vyletongue: the faction's Vyletongue Corruption quest id.
local function outerCaves(g, vyletongue, shadowshards)
	local amulet = g.Item("Amulet of Spirits", 17757)
	local done   = "items 17758 >= 1 or done 7067"   -- (the gems are joined already)

	g:Step(function(s)
		s.skip = done
		s:Goto(DESOLACE, 28.2, 62.4)
		s:Kill(g.Mob("The Nameless Prophet", 13718))
		s:Collect(amulet)
		s:Note("In the outer caves of Maraudon, before the instance portals. He has a few spots close together here.")
	end)

	local function khan(s, spirit, mob, gem, note)
		s.skip = done
		s:Use(amulet)
		s:Kill(mob)
		s:Collect(gem)
		s:Note("Use the ", amulet, " near the ", spirit, " to make him fight.", note and (" " .. note) or "")
	end

	g:Step(function(s)
		s:Goto(DESOLACE, 29.8, 60.3)
		khan(s, g.Npc("Spirit of Kolk", 12240), g.Mob("Kolk", 13742), g.Item("Gem of the First Kahn", 17761))
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 29.1, 57.2)
		khan(s, g.Npc("Spirit of Gelk", 12239), g.Mob("Gelk", 13741), g.Item("Gem of the Second Kahn", 17762), "He walks around this cave.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 28.4, 54.4)
		s:Kill(g.Mob("Shadowshard Rumbler", 11777))
		s:Kill(g.Mob("Shadowshard Smasher", 11778))
		s:Collect(g.Item("Shadowshard Fragment", 17756), { count = 10, quest = shadowshards, objective = 1 })
		s:Note("The crystal elementals in the purple caves, outside the instance.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 31.9, 63.8)
		s:Talk(g.Npc("Cavindra", 13697))
		s:Accept(7044, "Legends of Maraudon")
		s:Note("In the orange caves, on the way to the orange portal.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 33.2, 65.7)
		s:Use(g.Item("Coated Cerulean Vial", 17693))
		s:Collect(g.Item("Filled Cerulean Vial", 17696), { quest = vyletongue, objective = 2 })
		s:Note("At the orange crystal pool.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 35.2, 60.2)
		khan(s, g.Npc("Spirit of Magra", 12241), g.Mob("Magra", 13740), g.Item("Gem of the Third Kahn", 17763), "He walks around this cave.")
	end)
end

-- inside: the orange wing (Noxxion), the purple wing (Lord Vyletongue), then Celebras and the inner caves down to
-- Princess Theradras. vyletongue, theradras: the faction's quest ids; horde adds An'she's Radiance.
local function inside(g, vyletongue, theradras, horde)
	g:Step(function(s)
		s.skip = "ready " .. theradras .. " or done " .. theradras .. " or done 7046"   -- (been inside already)
		s:Goto(DESOLACE, 29.1, 62.5)
		s:Do("Enter Maraudon with your group.")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Theradric Crystal Carving", 17684), { count = 15, quest = 7028, objective = 1 })
		s:Note("Almost everything in Maraudon drops them.")
	end)

	g:Side("out", function(s)
		s:Use(g.Item("Filled Cerulean Vial", 17696))
		s:Kill(g.Mob("Noxxious Scion", 13696), { quest = vyletongue, objective = 1 })
		s:Note("In the orange wing: use the vial by a Vylestem Vine (a stump with a red top and five leaves) and kill the scion that comes out.")
	end)

	g:Side("out", function(s)
		s.skip = "items 17758 >= 1 or done 7067"
		s:Use(g.Item("Amulet of Spirits", 17757))
		s:Kill(g.Mob("Veng", 13738))
		s:Collect(g.Item("Gem of the Fifth Kahn", 17765))
		s:Note("The Spirit of Veng walks the orange wing.")
	end)

	g:Side("out", function(s)
		s.skip = "items 17758 >= 1 or done 7067"
		s:Use(g.Item("Amulet of Spirits", 17757))
		s:Kill(g.Mob("Maraudos", 13739))
		s:Collect(g.Item("Gem of the Fourth Kahn", 17764))
		s:Note("The Spirit of Maraudos walks the purple wing.")
	end)

	g:Side("out", function(s)
		s.only = "items 17761 >= 1 and items 17762 >= 1 and items 17763 >= 1 and items 17764 >= 1 and items 17765 >= 1"
		s:Use(g.Item("Gem of the Fifth Kahn", 17765))
		s:Collect(g.Item("Amulet of Union", 17758), { quest = 7067, objective = 1 })
		s:Note("With all five gems, use one to join them with the amulet.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Noxxion", 13282))
		s:Collect(g.Item("Celebrian Rod", 17702), { quest = 7044, objective = 2 })
		s:Note("The orange wing's boss.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lord Vyletongue", 12236))
		s:Collect(g.Item("Celebrian Diamond", 17703), { quest = 7044, objective = 1 })
		s:Note("The purple wing's boss, in a small room at the end of it.")
	end)

	g:Step(function(s)
		local redeemed = g.Npc("Celebras the Redeemed", 13716)
		s:Kill(g.Mob("Celebras the Cursed", 12225))
		s:Note("In the inner caves, where the two wings meet.")
		s:Talk(redeemed)
		s:Turnin(7044, "Legends of Maraudon")
		s:Accept(7046, "The Scepter of Celebras")
		s:Quest(7046, 1, "Follow him and wait while he makes the scepter.")
		s:Turnin(7046, "The Scepter of Celebras")
		s:Note(redeemed, " appears when Celebras the Cursed dies. The scepter opens the shortcut to the waterfall next time.")
	end)

	g:Step(function(s)
		s.only = "onquest 93404"
		s.skip = "ready 93404"   -- (the vial is used up at Woodwyrd)
		s:Collect(g.Item("Vial of Earth Song Water", 258296))
		s:Note("From the small geyser in the pools Rotgrip swims around in, in the waterfall cave below Princess Theradras.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Princess Theradras", 12201), { quest = theradras, objective = 1 })
		s:Note("The last boss, at the bottom of the inner caves past the waterfall.")
	end)

	g:Step(function(s)
		s:Talk(g.Npc("Zaetar's Spirit", 12238))
		s:Accept(7066, "Seed of Life")
		s:Note("He appears where Theradras died.")
	end)

	if horde then
		g:Step(function(s)
			s.only = "onquest 96776"
			s:Collect(g.Item("An'she's Radiance", 277140), { quest = 96776, objective = 1 })
			s:Note("Beyond Earth Song Falls, in the chamber of white crystals the giants guard: take it from the crystal near the highest part of the chamber.")
		end)
	end
end

local function seedOfLife(g, s)
	s:Goto(MOONGLADE, 36.2, 41.8)
	s:Talk(g.Npc("Keeper Remulos", 11832))
	s:Turnin(7066, "Seed of Life")
	s:Note("At the shrine in Moonglade. It can wait for your next trip there.")
end

ObviGuide.Guide(function(g)
	g.title = "Maraudon: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-maraudon"
	g.next  = "obvi-temple-of-atal-hakkar"
	g.only  = "Alliance"

	local tervosh   = g.Npc("Archmage Tervosh", 4967)
	local talendria = g.Npc("Talendria", 11715)
	local marandis  = g.Npc("Keeper Marandis", 13698)

	woodwyrdPointer(g)

	g:Step(function(s)
		s:Goto(DUSTWALLOW, 66.4, 49.3)
		s:Talk(tervosh)
		s:Accept(7070, "Shadowshard Fragments")
		s:Note("At the top of the tower in Theramore. Then fly to Nijel's Point.")
	end)

	-- Nijel's Point
	g:Step(function(s)
		s:Goto(DESOLACE, 68.5, 8.9)
		s:Talk(talendria)
		s:Accept(7041, "Vyletongue Corruption")
		s:Note("Upstairs in the building.")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 63.8, 10.7)
		s:Talk(marandis)
		s:Accept(7065, "Corruption of Earth and Seed")
	end)

	g:Step(function(s) willow(g, s) end)
	g:Step(function(s) pariah(g, s) end)
	g:Step(function(s) woodwyrd(g, s) end)

	outerCaves(g, 7041, 7070)
	inside(g, 7041, 7065)

	-- the turn-ins: south, then north to Nijel's Point
	g:Step(function(s)
		s.label = "out"
		pariah(g, s, true)
	end)

	g:Step(function(s) woodwyrd(g, s, true) end)
	g:Step(function(s) willow(g, s, true) end)

	g:Step(function(s)
		s:Goto(DESOLACE, 68.5, 8.9)
		s:Talk(talendria)
		s:Turnin(7041, "Vyletongue Corruption")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 63.8, 10.7)
		s:Talk(marandis)
		s:Turnin(7065, "Corruption of Earth and Seed")
		s:Note("Then fly to Theramore.")
	end)

	g:Step(function(s)
		s:Goto(DUSTWALLOW, 66.4, 49.3)
		s:Talk(tervosh)
		s:Turnin(7070, "Shadowshard Fragments")
	end)

	g:Step(function(s) seedOfLife(g, s) end)
end)

ObviGuide.Guide(function(g)
	g.title = "Maraudon: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-maraudon-horde"
	g.next  = "obvi-temple-of-atal-hakkar-horde"
	g.only  = "Horde"

	local uthelnay = g.Npc("Uthel'nay", 7311)
	local vark     = g.Npc("Vark Battlescar", 11823)
	local selendra = g.Npc("Selendra", 13699)
	local olana    = g.Npc("Olana Brighthoof", 268557)

	woodwyrdPointer(g)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 39.2, 86.3)
		s:Talk(uthelnay)
		s:Accept(7068, "Shadowshard Fragments")
		s:Note("With the mage trainers in the Valley of Spirits. Then fly to Thunder Bluff.")
	end)

	g:Step(function(s)
		s:Goto(MULGORE, 33.8, 23.7)
		s:Talk(olana)
		s:Accept(96776, "An'she's Radiance")
		s:Note("At Camp Gev'rek on the Skywatcher Plateau, in north-west Mulgore. Then fly from Thunder Bluff to Shadowprey Village.")
	end)

	-- Shadowprey Village
	g:Step(function(s)
		s:Goto(DESOLACE, 23.2, 70.3)
		s:Talk(vark)
		s:Accept(7029, "Vyletongue Corruption")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 26.9, 77.7)
		s:Talk(selendra)
		s:Accept(7064, "Corruption of Earth and Seed")
		s:Note("Just east of Shadowprey Village.")
	end)

	g:Step(function(s) pariah(g, s) end)
	g:Step(function(s) woodwyrd(g, s) end)
	g:Step(function(s) willow(g, s) end)

	outerCaves(g, 7029, 7068)
	inside(g, 7029, 7064, true)

	-- the turn-ins: east to Willow, then down to the Pariah and back to Shadowprey
	g:Step(function(s)
		s.label = "out"
		willow(g, s, true)
	end)

	g:Step(function(s) pariah(g, s, true) end)
	g:Step(function(s) woodwyrd(g, s, true) end)

	g:Step(function(s)
		s:Goto(DESOLACE, 26.9, 77.7)
		s:Talk(selendra)
		s:Turnin(7064, "Corruption of Earth and Seed")
	end)

	g:Step(function(s)
		s:Goto(DESOLACE, 23.2, 70.3)
		s:Talk(vark)
		s:Turnin(7029, "Vyletongue Corruption")
		s:Note("Then fly to Thunder Bluff.")
	end)

	g:Step(function(s)
		s:Goto(MULGORE, 33.8, 23.7)
		s:Talk(olana)
		s:Turnin(96776, "An'she's Radiance")
		s:Note("Then fly from Thunder Bluff to Orgrimmar.")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 39.2, 86.3)
		s:Talk(uthelnay)
		s:Turnin(7068, "Shadowshard Fragments")
	end)

	g:Step(function(s) seedOfLife(g, s) end)
end)
