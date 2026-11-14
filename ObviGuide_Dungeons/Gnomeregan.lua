-- Gnomeregan (24-35): the quests Attune and DungeonJournal (Exehn) list for each faction. Alliance: Tinkmaster
-- Overspark and Save Techbot's Brain!, The Day After, Gnogaine and The Only Cure is More Green Glow, Essential
-- Artificials, Gyrodrillmatic Excavationators, The Grand Betrayal, and Data Rescue with its punch cards (Castpipe's
-- Task handed in if you have it). Horde: Rig Wars, with Chief Engineer Scooty and Gnomer-gooooone! on the way. Both: A
-- Fine Mess (Kernobee), The Sparklematic 5200!, and the Grime-Encrusted Ring that leads to Return of the Ring and then
-- Gnome Improvement (Alliance) or Nogg's Ring Redo (Horde). Quest, NPC, item and object ids and positions from Attune
-- (CixiDelmont) and QuestieDB's Forever data; where things are inside from DungeonJournal. See README.md.

local STORMWIND, IRONFORGE, DUNMOROGH, STV, ORGRIMMAR = 1453, 1455, 1426, 1434, 1454

-- Data Rescue's punch cards, in order: each Matrix Punchograph turns one into the next
local CARDS = { 9279, 9280, 9282, 9281, 9316 }   -- white, yellow, blue, red, prismatic

-- holds while you have card i of the cards above or a later one (or Data Rescue is done)
local function hasCard(i)
	local t = {}
	for j = i, #CARDS do
		t[#t + 1] = "items " .. CARDS[j] .. " >= 1"
	end
	t[#t + 1] = "done 2930"
	return table.concat(t, " or ")
end

-- the bits both factions share: the way in, and the side tasks inside
local function enter(g, skip)
	g:Step(function(s)
		s:Path(DUNMOROGH, 24.3, 39.8)
		s:Path(DUNMOROGH, 23.4, 39.2)
		s:Goto(DUNMOROGH, 20.0, 36.0)
		s.skip = skip   -- (been inside already)
		s:Do("Enter Gnomeregan with your group.")
		s:Note("Into the building in north-west Dun Morogh, down the elevator, then keep left through the tunnels to the portal.")
	end)
end

local function insideSides(g, ringQuest)
	-- Kernobee: an escort that can fail, so it never holds the guide up
	g:Side("out", function(s)
		s:Talk(g.Npc("Kernobee", 7850))
		s:Accept(2904, "A Fine Mess")
		s:Quest(2904, 1, "Escort Kernobee to the Clockwerk Run exit.")
		s:Note("He's in a room on the north wall of the Dormitory. Clear around him first: he follows you and dies easily.")
	end)

	-- the ring drops from the Dark Iron Agents; the Sparklematic 5200 cleans it
	g:Side("out", function(s)
		local ring = g.Item("Grime-Encrusted Ring", 9326)
		s:Use(ring):Only("not onquest 2945 and not done 2945")
		s:Accept(2945, "Grime-Encrusted Ring")
		s:Turnin(2945, "Grime-Encrusted Ring")
		s:Accept(ringQuest, "Return of the Ring")
		s:Note("Only if a ", g.Mob("Dark Iron Agent", 6212), " drops the ", ring, ". Put it in The Sparklematic 5200 in the Clean Zone, early in the dungeon; it takes three silver coins.")
	end)

	-- the same machine cleans a Grime-Encrusted Object; the quest has two twins (4601, 4602) and only one can be done
	g:Side("out", function(s)
		s.only = "not done 4601 and not done 4602"
		local object = g.Item("Grime-Encrusted Object", 9308)
		s:Collect(object):Done("done 2951")
		s:Accept(2951, "The Sparklematic 5200!")
		s:Turnin(2951, "The Sparklematic 5200!")
		s:Note("Many of the creatures in and around Gnomeregan drop a ", object, ". Put it in The Sparklematic 5200 in the Clean Zone, with three silver coins, for a ", g.Item("Sparklematic-Wrapped Box", 9363), ".")
	end)
end

ObviGuide.Guide(function(g)
	g.title = "Gnomeregan: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-gnomeregan"
	g.next  = "obvi-scarlet-monastery"
	g.only  = "Alliance"

	local shoni      = g.Npc("Shoni the Shilent", 6579)
	local tinkmaster = g.Npc("Tinkmaster Overspark", 7944)
	local klockmort  = g.Npc("Klockmort Spannerspan", 6169)
	local mekkatorque = g.Npc("High Tinker Mekkatorque", 7937)
	local ozzie      = g.Npc("Ozzie Togglevolt", 1268)
	local castpipe   = g.Npc("Master Mechanic Castpipe", 7950)
	local talvash    = g.Npc("Talvash del Kissel", 6826)

	-- Stormwind
	g:Step(function(s)
		s:Goto(STORMWIND, 51.1, 48.4)
		s:Talk(g.Npc("Brother Sarno", 7917))
		s:Accept(2923, "Tinkmaster Overspark")
		s:Note("Inside the building in Cathedral Square.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 62.6, 34.1)
		s:Talk(shoni)
		s:Accept(2928, "Gyrodrillmatic Excavationators")
		s:Note("In the Dwarven District. Then take the Deeprun Tram to Ironforge.")
	end)

	-- Ironforge: all of it in and around Tinker Town
	g:Step(function(s)
		s:Goto(IRONFORGE, 69.6, 50.3)
		s:Talk(tinkmaster)
		s:Turnin(2923, "Tinkmaster Overspark")
		s:Accept(2922, "Save Techbot's Brain!")
		s:Talk(g.Npc("Gnoarn", 6569))
		s:Accept(2927, "The Day After")
		s:Talk(castpipe)
		s:Turnin(2931, "Castpipe's Task"):Only("onquest 2931")
		s:Accept(2930, "Data Rescue")
		s:Note("In Tinker Town, all three close together.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 68.8, 49.0)
		s:Talk(mekkatorque)
		s:Accept(2929, "The Grand Betrayal")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 67.9, 46.1)
		s:Talk(klockmort)
		s:Accept(2924, "Essential Artificials")
	end)

	-- Kharanos, on the way out to Gnomeregan
	g:Step(function(s)
		s:Goto(DUNMOROGH, 45.9, 49.4)
		s:Talk(ozzie)
		s:Turnin(2927, "The Day After")
		s:Accept(2926, "Gnogaine")
		s:Accept(2962, "The Only Cure is More Green Glow"):Only("done 2926")
		s:Note("Inside the building in Kharanos.")
	end)

	g:Step(function(s)
		s:Goto(DUNMOROGH, 20.9, 36.0)
		s:Use(g.Item("Empty Leaden Collection Phial", 9283))
		s:Collect(g.Item("Full Leaden Collection Phial", 9284), { quest = 2926, objective = 1 })
		s:Note("Use it on a living ", g.Mob("Irradiated Invader", 6213), " or ", g.Mob("Irradiated Pillager", 6329), ": the troggs in the tunnels before the portal, and inside near the start.")
	end)

	-- Data Rescue: the first two punch cards are outside the dungeon
	g:Step(function(s)
		s.only = "onquest 2930"
		s:Goto(DUNMOROGH, 22.0, 32.6)
		s:Collect(g.Item("White Punch Card", CARDS[1])):Done(hasCard(1))
		s:Note("A chance drop from the troggs and the ", g.Mob("Addled Leper", 6221), "s outside the dungeon.")
		s:Collect(g.Item("Yellow Punch Card", CARDS[2])):Done(hasCard(2))
		s:Note("Put the white card in ", g.Object("Matrix Punchograph 3005-A"), ", on the raised platform in the Train Depot or by the Workshop entrance.")
	end)

	-- Ozzie's next quest needs Gnogaine handed in, and is done inside: back to Kharanos once
	g:Step(function(s)
		s:Goto(DUNMOROGH, 45.9, 49.4)
		s:Talk(ozzie)
		s:Turnin(2926, "Gnogaine")
		s:Accept(2962, "The Only Cure is More Green Glow")
		s:Note("Back to Kharanos with the full phial, then back to Gnomeregan.")
	end)

	enter(g, "ready 2929 or done 2929")

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Mechano-Tank", 6225))
		s:Kill(g.Mob("Mechanized Sentry", 6233))
		s:Collect(g.Item("Robo-mechanical Guts", 9309), { count = 24, quest = 2928, objective = 1 })
		s:Note("From the mechanical enemies throughout the dungeon.")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Essential Artificial", 9278), { count = 12, quest = 2924, objective = 1 })
		s:Note("From the ", g.Object("Artificial Extrapolator"), " machines: square upright boxes all over the dungeon.")
	end)

	insideSides(g, 2947)

	-- the fallout collapses quickly, so it's worth getting late in the run
	g:Side("out", function(s)
		s.only = "onquest 2962"
		s:Use(g.Item("Heavy Leaden Collection Phial", 9364))
		s:Collect(g.Item("High Potency Radioactive Fallout", 9365), { quest = 2962, objective = 1 })
		s:Note("Use the phial on a living ", g.Mob("Irradiated Slime", 6218), " or ", g.Mob("Corrosive Lurker", 6219), "; it can take a few tries. The fallout soon collapses: get it late in the run and go straight to Ozzie.")
	end)

	g:Step(function(s)
		s.only = "onquest 2930"
		s:Collect(g.Item("Blue Punch Card", CARDS[3])):Done(hasCard(3))
		s:Note("Put the yellow card in ", g.Object("Matrix Punchograph 3005-B"), ", in the Dormitory just past the Clean Zone.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Techbot", 6231))
		s:Collect(g.Item("Techbot's Memory Core", 9277), { quest = 2922, objective = 1 })
		s:Note("Near the start of the dungeon, before the Hall of Gears.")
	end)

	g:Step(function(s)
		s.only = "onquest 2930"
		s:Collect(g.Item("Red Punch Card", CARDS[4])):Done(hasCard(4))
		s:Note("Put the blue card in ", g.Object("Matrix Punchograph 3005-C"), ", on the upper platform of the Launch Bay, where Electrocutioner 6000 is.")
	end)

	g:Step(function(s)
		s.only = "onquest 2930"
		s:Collect(g.Item("Prismatic Punch Card", CARDS[5]), { quest = 2930, objective = 1 })
		s:Note("Put the red card in ", g.Object("Matrix Punchograph 3005-D"), ": take the elevator down to the lower level of the Engineering Labs; it's in the first passage on the right, on the west side.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Mekgineer Thermaplugg", 7800), { quest = 2929, objective = 1 })
		s:Note("The last boss, in Tinkers' Court. Kill the walking bombs as they come out.")
	end)

	-- out: Kharanos, then Ironforge, then Stormwind
	g:Step(function(s)
		s.label = "out"
		s:Goto(DUNMOROGH, 45.9, 49.4)
		s:Talk(ozzie)
		s:Turnin(2926, "Gnogaine"):Only("onquest 2926")
		s:Turnin(2962, "The Only Cure is More Green Glow"):Only("ready 2962")
		s:Note("If the fallout collapsed on the way, The Only Cure is More Green Glow waits for another try.")
	end)

	-- the ring: Return of the Ring, then Talvash improves it for a Silver Bar, a Moss Agate and 30 silver
	g:Step(function(s)
		s.only = "onquest 2947 or (done 2947 and not done 2948)"
		s:Goto(IRONFORGE, 36.4, 3.6)
		s:Talk(talvash)
		s:Turnin(2947, "Return of the Ring")
		s:Accept(2948, "Gnome Improvement")
		s:Collect(g.Item("Silver Bar", 2842), { quest = 2948, objective = 1 }):Only("onquest 2948")
		s:Collect(g.Item("Moss Agate", 1206), { quest = 2948, objective = 2 }):Only("onquest 2948")
		s:Turnin(2948, "Gnome Improvement")
		s:Note("In the Mystic Ward. The bar and the agate come from mining, or the Auction House. Or keep the ring as it is: either way Return of the Ring is done.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 67.9, 46.1)
		s:Talk(klockmort)
		s:Turnin(2924, "Essential Artificials")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 68.8, 49.0)
		s:Talk(mekkatorque)
		s:Turnin(2929, "The Grand Betrayal")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 69.6, 50.3)
		s:Talk(tinkmaster)
		s:Turnin(2922, "Save Techbot's Brain!")
		s:Talk(castpipe)
		s:Turnin(2930, "Data Rescue"):Only("onquest 2930")
		s:Note("Then take the tram back to Stormwind.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 62.6, 34.1)
		s:Talk(shoni)
		s:Turnin(2928, "Gyrodrillmatic Excavationators")
	end)

	g:Step(function(s)
		s.only = "onquest 2904"
		s:Goto(STV, 27.6, 77.5)
		s:Talk(g.Npc("Scooty", 7853))
		s:Turnin(2904, "A Fine Mess")
		s:Note("In Booty Bay. It can wait for your next time there.")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Gnomeregan: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-gnomeregan-horde"
	g.next  = "obvi-scarlet-monastery-horde"
	g.only  = "Horde"

	local nogg   = g.Npc("Nogg", 3412)
	local scooty = g.Npc("Scooty", 7853)

	-- Orgrimmar: the two engineers in the Valley of Honor
	g:Step(function(s)
		s:Goto(ORGRIMMAR, 76.0, 25.4)
		s:Talk(nogg)
		s:Accept(2841, "Rig Wars")
		s:Talk(g.Npc("Sovik", 3413))
		s:Accept(2842, "Chief Engineer Scooty")
		s:Note("Inside the building in the Valley of Honor. Take Rig Wars first: if it vanishes from Nogg, abandon Chief Engineer Scooty and it comes back.")
	end)

	-- Booty Bay: Scooty's transporter is the way to Gnomeregan
	g:Step(function(s)
		s:Goto(STV, 27.6, 77.5)
		s:Talk(scooty)
		s:Turnin(2842, "Chief Engineer Scooty")
		s:Accept(2843, "Gnomer-gooooone!")
		s:Quest(2843, 1, "Wait for Scooty to calibrate the Goblin Transponder.")
		s:Turnin(2843, "Gnomer-gooooone!")
		s:Note("Then step onto the transporter beside him: it drops you near Gnomeregan.")
	end)

	enter(g, "ready 2841 or done 2841")

	insideSides(g, 2949)

	g:Step(function(s)
		s:Kill(g.Mob("Mekgineer Thermaplugg", 7800))
		s:Collect(g.Item("Thermaplugg's Safe Combination", 9299), { quest = 2841, objective = 2 })
		s:Note("The last boss, in Tinkers' Court. Kill the walking bombs as they come out.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Rig Blueprints", 9153), { quest = 2841, objective = 1 })
		s:Note("Open ", g.Object("Thermaplugg's Safe"), ", against the back wall of his room.")
	end)

	-- out: home to Orgrimmar
	g:Step(function(s)
		s.label = "out"
		s:Goto(ORGRIMMAR, 76.0, 25.4)
		s:Talk(nogg)
		s:Turnin(2841, "Rig Wars")
		s:Turnin(2949, "Return of the Ring"):Only("onquest 2949")
		s:Accept(2950, "Nogg's Ring Redo"):Only("done 2949")
		s:Collect(g.Item("Silver Bar", 2842), { quest = 2950, objective = 1 }):Only("onquest 2950")
		s:Collect(g.Item("Moss Agate", 1206), { quest = 2950, objective = 2 }):Only("onquest 2950")
		s:Turnin(2950, "Nogg's Ring Redo"):Only("onquest 2950")
		s:Note("Hearth or fly back. Return of the Ring is only there if you found the ring; you may also keep it. Nogg's Ring Redo after it also wants a Silver Bar, a Moss Agate and 30 silver: from mining, or the Auction House.")
	end)

	g:Step(function(s)
		s.only = "onquest 2904"
		s:Goto(STV, 27.6, 77.5)
		s:Talk(scooty)
		s:Turnin(2904, "A Fine Mess")
		s:Note("In Booty Bay. It can wait for your next time there.")
	end)
end)
