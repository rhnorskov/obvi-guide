-- Zul'Farrak (40-48): the quests Attune and DungeonJournal (Exehn) list for each faction. Both: Divino-matic Rod,
-- Gahz'rilla (with the Mallet of Zul'Farrak from the Hinterlands), Screecher Spirits and The Prophecy of Mosh'aru,
-- Tiara of the Deep, Troll Temper, and Scarab Shells with Tran'rek from Booty Bay (pointed at). Alliance: Nekrum's
-- Medallion, The Brassbolts Brothers from Ironforge and The Witch Doctor's Head (Archmage Lan'dalock, Dalaran). Horde:
-- Venom Bottles, Undamaged Venom Sac, Consult Master Gadrin, The Spider God and Zum'rah's Head (Mazu'kon, Mulgore).
-- Class quests, the part done here: Tabetha's Task and A Lesson in Literacy (mages), The Talisman of Kazdor (rogues). Quest, NPC, item and object ids and positions from Attune
-- (CixiDelmont) and QuestieDB's Forever data; the dungeon portal from QuestieDB, the bosses' places and the Forever
-- quests from DungeonJournal (Exehn). Pick-ups go Hinterlands, Dustwallow, Thousand Needles, Tanaris and Feralas; the
-- turn-ins run back the same way. See README.md.

local TANARIS, NEEDLES, DUSTWALLOW, FERALAS, MULGORE = 1446, 1441, 1445, 1444, 1412
local HINTERLANDS, BLASTED, HILLSBRAD, DUROTAR, IRONFORGE, ALTERAC = 1425, 1419, 1424, 1411, 1455, 1416

-- the Mallet of Zul'Farrak, which calls up Gahz'rilla: one in the group is enough
local function mallet(g)
	g:Step(function(s)
		s.skip = "items 9241 >= 1 or items 9240 >= 1 or done 2770"
		s:Goto(HINTERLANDS, 48.6, 68.2)
		s:Kill(g.Mob("Qiaga the Keeper", 7996))
		s:Collect(g.Item("Sacred Mallet", 9241))
		s:Note("At the Altar of Zul, up the stairs. She's elite and has guards: bring friends. Skip this and the next step if someone in your group already has a ", g.Item("Mallet of Zul'Farrak", 9240), ".")
	end)

	g:Step(function(s)
		s.skip = "items 9240 >= 1 or done 2770"
		s:Goto(HINTERLANDS, 59.6, 77.9)
		s:Use(g.Item("Sacred Mallet", 9241))
		s:Collect(g.Item("Mallet of Zul'Farrak", 9240))
		s:Note("At the altar on top of Jintha'Alor, the troll city in the south-east.")
	end)
end

-- Tanaris and Feralas, both factions
local function pickups(g)
	local yeh = g.Npc("Yeh'kinya", 8579)

	-- Tran'rek only sends you on to Scarab Shells, from Booty Bay; it's only pointed at
	g:Step(function(s)
		s.skip = "onquest 2864 or done 2864 or onquest 2865 or done 2865"
		s:Do("Optional: if you pass through Booty Bay, pick up Tran'rek from ", g.Npc("Krazek", 773), ".")
		s:Note("Upstairs in the Booty Bay inn (Stranglethorn Vale 26.9, 77.2). It only sends you to Tran'rek in Gadgetzan, who gives Scarab Shells anyway.")
	end)

	g:Step(function(s)
		s:Goto(DUSTWALLOW, 46.1, 57.1)
		s:Talk(g.Npc("Tabetha", 6546))
		s:Turnin(2861, "Tabetha's Task"):Only("onquest 2861")
		s:Accept(2846, "Tiara of the Deep")
		s:Note("In her hut in the south-west of the marsh.")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 78.1, 77.1)
		s:Talk(g.Npc("Wizzle Brassbolts", 4453))
		s:Turnin(2769, "The Brassbolts Brothers"):Only("onquest 2769")
		s:Accept(2770, "Gahz'rilla")
		s:Note("At the Mirage Raceway in the Shimmering Flats.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 52.5, 28.5)
		s:Talk(g.Npc("Chief Engineer Bilgewhizzle", 7407))
		s:Accept(2768, "Divino-matic Rod")
		s:Note("In Gadgetzan.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 51.4, 28.8)
		s:Talk(g.Npc("Trenton Lighthammer", 7804))
		s:Accept(3042, "Troll Temper")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 51.6, 26.8)
		s:Talk(g.Npc("Tran'rek", 7876))
		s:Turnin(2864, "Tran'rek"):Only("onquest 2864")
		s:Accept(2865, "Scarab Shells")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Accept(3520, "Screecher Spirits")
		s:Note("In Steamwheedle Port, east of Gadgetzan. Then fly from Gadgetzan to Feralas.")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 58.0, 58.0)
		s:Kill(g.Mob("Vale Screecher", 5307))
		s:Use(g.Item("Yeh'kinya's Bramble", 10699))
		s:Quest(3520, 1, "Capture 3 Screecher Spirits.")
		s:Note("Use the bramble on a dead screecher, then talk to the spirit that appears. The Rogue Vale Screechers around 43, 36 work too.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Turnin(3520, "Screecher Spirits")
		s:Accept(3527, "The Prophecy of Mosh'aru")
	end)
end

local function enter(g, skip)
	g:Step(function(s)
		s.skip = skip   -- (been inside already)
		s:Goto(TANARIS, 38.7, 20.0)
		s:Do("Enter Zul'Farrak with your group.")
		s:Note("The portal is in the north-west of Tanaris, at the end of the canyon into the troll city.")
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Sandfury Shadowcaster", 5648))
		s:Kill(g.Mob("Sandfury Blood Drinker", 5649))
		s:Collect(g.Item("Troll Temper", 9523), { count = 20, quest = 3042, objective = 1 })
		s:Note("From the Sandfury trolls throughout the dungeon.")
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Scarab", 7269))
		s:Collect(g.Item("Uncracked Scarab Shell", 9238), { count = 5, quest = 2865, objective = 1 })
		s:Note("Not every scarab drops one.")
	end)

	-- mages on A Lesson in Literacy (DungeonJournal, Exehn)
	g:Side("out", function(s)
		s.only = "onquest 82084"
		s:Kill(g.Mob("Zul'Farrak Zombie"))
		s:Collect(g.Item("Farraki Papyrus", 221360), { count = 8 })
		s:Note("From the zombies that rise from the graves in the graveyard.")
	end)

	-- rogues on The Talisman of Kazdor (DungeonJournal, Exehn)
	g:Side("out", function(s)
		s.only = "onquest 80411"
		s:Collect(g.Item("Talisman of Kazdor", 217609))
		s:Note("Alone, outside a group.")
	end)
end

-- the bosses, in the order a group meets them
local function bosses(g, horde)
	-- Zum'rah's head: The Witch Doctor's Head (Alliance) or Zum'rah's Head (Horde)
	local head = horde and 96775 or 96770
	g:Side("out", function(s)
		s.only = "onquest " .. head
		s:Kill(g.Mob("Witch Doctor Zum'rah", 7271))
		s:Collect(g.Item("Zum'rah's Head", 277112), { quest = head, objective = 1 })
		s:Note("In the graveyard. Zombies rise from the graves when he is pulled.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Theka the Martyr", 7272))
		s:Collect(g.Item("First Mosh'aru Tablet", 10660), { quest = 3527, objective = 1 })
		if horde then
			s:Quest(2936, 1, "Read the Tablet of Theka to learn the spider god's name.")
			s:Note("The ", g.Object("Tablet of Theka"), " stands in his room.")
		end
		s:Note("North from the entrance, then right where the path splits.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Nekrum Gutchewer", 7796))
		if not horde then
			s:Collect(g.Item("Nekrum's Medallion", 9471), { quest = 2991, objective = 1 })
		end
		s:Kill(g.Mob("Sergeant Bly", 7604))
		s:Collect(g.Item("Divino-matic Rod", 8548), { quest = 2768, objective = 1 })
		s:Note("The pyramid: let the prisoners out and hold the stairs against the waves of trolls. Nekrum and Shadowpriest Sezz'ziz come down last; Sergeant Bly and his crew turn on you at the top afterwards.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Hydromancer Velratha", 7795))
		s:Collect(g.Item("Tiara of the Deep", 9234), { quest = 2846, objective = 1 })
		s:Collect(g.Item("Second Mosh'aru Tablet", 10661), { quest = 3527, objective = 2 })
		s:Note("She walks around the big pool in the west.")
	end)

	g:Step(function(s)
		s:Use(g.Item("Mallet of Zul'Farrak", 9240))
		s:Kill(g.Mob("Gahz'rilla", 7273))
		s:Collect(g.Item("Gahz'rilla's Electrified Scale", 8707), { quest = 2770, objective = 1 })
		s:Note("Clear the pool, then ring the ", g.Object("Gong of Zul'Farrak"), " with the mallet. Face him away from the group.")
	end)
end

-- the turn-ins both factions share
local function turnins(g)
	g:Step(function(s)
		s.label = "out"
		s:Goto(TANARIS, 52.5, 28.5)
		s:Talk(g.Npc("Chief Engineer Bilgewhizzle", 7407))
		s:Turnin(2768, "Divino-matic Rod")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 51.4, 28.8)
		s:Talk(g.Npc("Trenton Lighthammer", 7804))
		s:Turnin(3042, "Troll Temper")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 51.6, 26.8)
		s:Talk(g.Npc("Tran'rek", 7876))
		s:Turnin(2865, "Scarab Shells")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(g.Npc("Yeh'kinya", 8579))
		s:Turnin(3527, "The Prophecy of Mosh'aru")
		s:Note("He offers The Ancient Egg next: the chain carries on in the Hinterlands, the Sunken Temple and Blackrock Spire.")
	end)

	g:Step(function(s)
		s:Goto(NEEDLES, 78.1, 77.1)
		s:Talk(g.Npc("Wizzle Brassbolts", 4453))
		s:Turnin(2770, "Gahz'rilla")
	end)

	g:Step(function(s)
		s:Goto(DUSTWALLOW, 46.1, 57.1)
		s:Talk(g.Npc("Tabetha", 6546))
		s:Turnin(2846, "Tiara of the Deep")
	end)
end

ObviGuide.Guide(function(g)
	g.title = "Zul'Farrak: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-zul-farrak"
	g.next  = "obvi-maraudon"
	g.only  = "Alliance"

	local thadius   = g.Npc("Thadius Grimshade", 8022)
	local landalock = g.Npc("Archmage Lan'dalock", 20735)

	g:Step(function(s)
		s:Goto(ALTERAC, 15.3, 73.9)
		s:Talk(landalock)
		s:Accept(96770, "The Witch Doctor's Head")
		s:Note("At the Violet Hold entrance in Dalaran. Then fly from Southshore to Aerie Peak, in the Hinterlands.")
	end)

	-- Nekrum's Medallion needs a Hinterlands chain first; Attune doesn't count that chain, so it's only pointed at
	g:Step(function(s)
		s.skip = "onquest 2988 or onquest 2989 or onquest 2990 or done 2990"
		s:Goto(HINTERLANDS, 9.8, 44.5)
		s:Do("Optional: do Witherbark Cages, The Altar of Zul and Thadius Grimshade for ", g.Npc("Gryphon Master Talonaxe", 5636), " first.")
		s:Note("At Aerie Peak. The chain ends in the Blasted Lands with Nekrum's Medallion, a Zul'Farrak quest; without it you just skip that one.")
	end)

	mallet(g)

	-- Ironforge, on the way south: The Brassbolts Brothers only sends you on to Gahz'rilla
	g:Step(function(s)
		s:Goto(IRONFORGE, 67.9, 46.1)
		s:Talk(g.Npc("Klockmort Spannerspan", 6169))
		s:Accept(2769, "The Brassbolts Brothers")
		s:Note("In Tinker Town. It sends you to Wizzle Brassbolts in Thousand Needles.")
	end)

	-- Nekrum's Medallion comes at the end of a chain from Aerie Peak; only for those on it
	g:Step(function(s)
		s.only = "onquest 2990 or done 2990"
		s:Goto(BLASTED, 66.9, 19.5)
		s:Talk(thadius)
		s:Turnin(2990, "Thadius Grimshade")
		s:Accept(2991, "Nekrum's Medallion")
		s:Note("In the tower of Nethergarde Keep. Then take the boat from Menethil Harbor to Theramore.")
	end)

	pickups(g)
	enter(g, "ready 3042 or done 3042 or ready 2768 or done 2768")
	bosses(g, false)
	turnins(g)

	g:Step(function(s)
		s.only = "onquest 2991 or done 2991"
		s:Goto(BLASTED, 66.9, 19.5)
		s:Talk(thadius)
		s:Turnin(2991, "Nekrum's Medallion")
		s:Note("His next quest, The Divination, follows straight on.")
	end)

	g:Step(function(s)
		s.only = "onquest 96770 or done 96770"
		s:Goto(ALTERAC, 15.3, 73.9)
		s:Talk(landalock)
		s:Turnin(96770, "The Witch Doctor's Head")
		s:Note("Back at Dalaran; Southshore is the nearest flight path.")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Zul'Farrak: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-zul-farrak-horde"
	g.next  = "obvi-maraudon-horde"
	g.only  = "Horde"

	local lydon  = g.Npc("Apothecary Lydon", 2216)
	local gadrin  = g.Npc("Master Gadrin", 3188)
	local mazukon = g.Npc("Mazu'kon", 264074)

	-- the Venom Bottles chain starts from a bottle in the Hinterlands
	g:Step(function(s)
		s:Goto(HINTERLANDS, 23.5, 58.8)
		s:Accept(2933, "Venom Bottles")
		s:Note("Click a ", g.Object("Venom Bottle"), " in the troll camp of Shadra'Alor.")
	end)

	mallet(g)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.4, 19.1)
		s:Talk(lydon)
		s:Turnin(2933, "Venom Bottles")
		s:Accept(2934, "Undamaged Venom Sac")
		s:Note("In Tarren Mill.")
	end)

	g:Step(function(s)
		s:Goto(HINTERLANDS, 31.0, 69.7)
		s:Kill(g.Mob("Witherbark Broodguard", 2686))
		s:Collect(g.Item("Undamaged Venom Sac", 9322), { quest = 2934, objective = 1 })
		s:Note("The spiders around Shadra'Alor.")
	end)

	g:Step(function(s)
		s:Goto(HILLSBRAD, 61.4, 19.1)
		s:Talk(lydon)
		s:Turnin(2934, "Undamaged Venom Sac")
		s:Accept(2935, "Consult Master Gadrin")
	end)

	g:Step(function(s)
		s:Goto(DUROTAR, 55.9, 74.7)
		s:Talk(gadrin)
		s:Turnin(2935, "Consult Master Gadrin")
		s:Accept(2936, "The Spider God")
		s:Note("In Sen'jin Village. Then fly from Orgrimmar to Thunder Bluff.")
	end)

	g:Step(function(s)
		s:Goto(MULGORE, 32.5, 20.7)
		s:Talk(mazukon)
		s:Accept(96775, "Zum'rah's Head")
		s:Note("On the Skywatcher Plateau, in north-west Mulgore. Then fly from Thunder Bluff to Brackenwall Village for Dustwallow Marsh.")
	end)

	pickups(g)
	enter(g, "ready 3042 or done 3042 or ready 2936 or done 2936")
	bosses(g, true)
	turnins(g)

	g:Step(function(s)
		s:Goto(DUROTAR, 55.9, 74.7)
		s:Talk(gadrin)
		s:Turnin(2936, "The Spider God")
		s:Note("His next quest, Summoning Shadra, goes back to the Hinterlands.")
	end)

	g:Step(function(s)
		s.only = "onquest 96775 or done 96775"
		s:Goto(MULGORE, 32.5, 20.7)
		s:Talk(mazukon)
		s:Turnin(96775, "Zum'rah's Head")
		s:Note("On the Skywatcher Plateau; fly to Thunder Bluff.")
	end)
end)
