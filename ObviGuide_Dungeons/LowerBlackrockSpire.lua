-- Lower Blackrock Spire (55-60): the quests Attune lists for each faction. Both: Kibler's Exotic Pets,
-- En-Ay-Es-Tee-Why, Mother's Milk, Urok Doomhowl, both Seal of Ascension quests (the key to Upper Blackrock Spire) and
-- the whole Mosh'aru chain from Screecher Spirits to The Final Tablets (it passes through Zul'Farrak and the Sunken
-- Temple). Alliance: Bijou's Belongings, Message to Maxwell, Maxwell's Mission, Put Her Down and General Drakkisath's
-- Command. Horde: Warlord's Command, The Pack Mistress, Operative Bijou and Bijou's chain, and Vivian Lagrave and the
-- Darkstone Tablet. Maxwell's Mission and the second Seal of Ascension come back to the spire, so the guide has a
-- second, shorter run at the end. Quest, NPC, item and object ids and positions from Attune (CixiDelmont) and
-- QuestieDB's Forever data; bosses and rooms from DungeonJournal (Exehn). See README.md.

local TANARIS, FERALAS, HINTERLANDS, SWAMP, EPL = 1446, 1444, 1425, 1435, 1423
local BURNING, BADLANDS, UNDERCITY, DUSTWALLOW = 1428, 1418, 1458, 1445

-- the Mosh'aru chain: Tanaris, Feralas, Zul'Farrak, the Hinterlands, the Sunken Temple and the Eastern Plaguelands,
-- before the last two tablets in the spire. Steps for a quest you've done pass by.
local function moshaRu(g)
	local yeh = g.Npc("Yeh'kinya", 8579)
	local ironboot = g.Npc("Prospector Ironboot", 10460)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Accept(3520, "Screecher Spirits")
		s:Note("In Steamwheedle Port. This chain runs through Zul'Farrak and the Sunken Temple; its last tablets are in Lower Blackrock Spire.")
	end)

	g:Step(function(s)
		s:Goto(FERALAS, 58.0, 58.0)
		s:Kill(g.Mob("Vale Screecher", 5307))
		s:Use(g.Item("Yeh'kinya's Bramble", 10699))
		s:Quest(3520, 1, "Capture 3 Screecher Spirits.")
		s:Note("Use the bramble on a dead screecher, then talk to the spirit that appears.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Turnin(3520, "Screecher Spirits")
		s:Accept(3527, "The Prophecy of Mosh'aru")
	end)

	g:Step(function(s)
		s.only = "onquest 3527"
		s:Goto(TANARIS, 38.7, 20.0)
		s:Collect(g.Item("First Mosh'aru Tablet", 10660), { quest = 3527, objective = 1 })
		s:Collect(g.Item("Second Mosh'aru Tablet", 10661), { quest = 3527, objective = 2 })
		s:Note("In Zul'Farrak: ", g.Mob("Theka the Martyr", 7272), " and ", g.Mob("Hydromancer Velratha", 7795), " drop them. The Zul'Farrak guide has the way.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Turnin(3527, "The Prophecy of Mosh'aru")
		s:Accept(4787, "The Ancient Egg")
	end)

	g:Step(function(s)
		s.only = "onquest 4787"
		s:Goto(HINTERLANDS, 57.6, 86.8)
		s:Collect(g.Item("Ancient Egg", 12402), { quest = 4787, objective = 1 })
		s:Note("Click the ", g.Object("Ancient Egg"), " in the cave under Jintha'Alor. Trolls all the way: bring help.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Turnin(4787, "The Ancient Egg")
		s:Accept(3528, "The God Hakkar")
	end)

	g:Step(function(s)
		s.only = "onquest 3528"
		s:Goto(SWAMP, 69.9, 53.6)
		s:Use(g.Item("Egg of Hakkar", 10465))
		s:Kill(g.Mob("Avatar of Hakkar", 8443))
		s:Collect(g.Item("Filled Egg of Hakkar", 10662), { quest = 3528, objective = 1 })
		s:Note("In the Sunken Temple, with a group. Use the egg in the Sanctum of the Fallen God to start the event: kill the Hakkari Bloodkeepers, use their blood to put out the four flames, then kill the Avatar and use its essence on the egg.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 67.0, 22.4)
		s:Talk(yeh)
		s:Turnin(3528, "The God Hakkar")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 66.9, 24.0)
		s:Talk(ironboot)
		s:Accept(5065, "The Lost Tablets of Mosh'aru")
		s:Note("Just south of Yeh'kinya.")
	end)

	g:Step(function(s)
		s.only = "onquest 5065"
		s:Goto(EPL, 63.6, 9.0)
		s:Collect(g.Item("Third Mosh'aru Tablet", 12411), { quest = 5065, objective = 1 })
		s:Collect(g.Item("Fourth Mosh'aru Tablet", 12412), { quest = 5065, objective = 2 })
		s:Note("In the troll ruins of Zul'Mashar in the far north: the fourth tablet at about 63.8, 10.2, the third up on the temple at 63.4, 7.8.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 66.9, 24.0)
		s:Talk(ironboot)
		s:Turnin(5065, "The Lost Tablets of Mosh'aru")
		s:Accept(4788, "The Final Tablets")
	end)
end

-- Flame Crest, at the east end of Burning Steppes' northern road
local function flameCrest(g)
	g:Step(function(s)
		s:Goto(BURNING, 65.0, 23.8)
		s:Talk(g.Npc("Ragged John", 9563))
		s:Accept(4866, "Mother's Milk")
		s:Note("In Flame Crest.")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 65.9, 21.9)
		s:Talk(g.Npc("Kibler", 10260))
		s:Accept(4729, "Kibler's Exotic Pets")
		s:Accept(4862, "En-Ay-Es-Tee-Why")
		s:Note("In the cave behind Ragged John.")
	end)
end

local function enter(s, skip)
	s.skip = skip   -- (been inside already)
	s:Goto(BURNING, 29.4, 38.3)
	s:Do("Enter Lower Blackrock Spire with your group.")
	s:Note("Into Blackrock Mountain, then up the chains to the Blackrock Spire portal on the upper level.")
end

-- the run itself; horde picks the faction's lines
local function dungeon(g, horde)
	local vaelan = g.Npc("Vaelan", 10296)
	local warosh = g.Npc("Warosh", 10799)
	local bijou  = g.Npc("Bijou", 10257)

	g:Step(function(s)
		enter(s, "onquest 4742 or done 4742 or onquest 4867 or done 4867")
	end)

	g:Side("out", function(s)
		s:Collect(g.Item("Unadorned Seal of Ascension", 12219), { quest = 4742, objective = 4 })
		s:Note("From the orcs and ogres throughout the spire.")
	end)

	if horde then
		g:Side("out", function(s)
			s:Collect(g.Item("Important Blackrock Documents", 12562), { quest = 4903, objective = 4 })
			s:Note("Click the ", g.Object("Inconspicuous Documents"), ": they lie in one of several places, so keep an eye out the whole way.")
		end)
	else
		g:Side("out", function(s)
			local command = g.Item("General Drakkisath's Command", 12780)
			s:Use(command):Only("not onquest 5089 and not done 5089")
			s:Accept(5089, "General Drakkisath's Command")
			s:Note(g.Mob("Overlord Wyrmthalak", 9568), " drops ", command, ": it starts the quest.")
		end)
	end

	g:Step(function(s)
		s:Talk(vaelan)
		s:Accept(4742, "Seal of Ascension")
		s:Note("Up the ramp just inside the entrance. Needs level 57.")
	end)

	g:Step(function(s)
		s:Talk(warosh)
		s:Accept(4867, "Urok Doomhowl")
		s:Note("He walks around Hordemar City, right from the Hall of Blackhand. The ", g.Object("Roughshod Pike"), " stands in a weapon rack on the left after the second bridge: one in the group is enough.")
	end)

	g:Step(function(s)
		s:Talk(bijou)
		if horde then
			s:Turnin(4981, "Operative Bijou")
			s:Accept(4982, "Bijou's Belongings")
		else
			s:Accept(5001, "Bijou's Belongings")
		end
		s:Note("Down in the trench in Hordemar City, past the second bridge.")
	end)

	g:Side("bijou", function(s)
		s:Collect(g.Item("Bijou's Belongings", 12345), { quest = horde and 4982 or 5001, objective = 1 })
		s:Note("A small chest on the lowest level, somewhere between Hordemar City and the Skitterweb Tunnels.")
	end)

	g:Step(function(s)
		s:Collect(g.Item("Fifth Mosh'aru Tablet", 12740), { quest = 4788, objective = 1 })
		if horde then
			s:Collect(g.Item("Darkstone Tablet", 12358), { quest = 4768, objective = 1 })
		end
		s:Note("In Shadow Hunter Vosh'gajin's part of Tazz'Alaor: from Bijou, down the ramp, up the other side and up the stairs on the left.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("War Master Voone", 9237), horde and { quest = 4903, objective = 3 } or nil)
		s:Collect(g.Item("Gemstone of Smolderthorn", 12335), { quest = 4742, objective = 2 })
		s:Collect(g.Item("Sixth Mosh'aru Tablet", 12741), { quest = 4788, objective = 2 })
		s:Note("At the bottom of Tazz'Alaor; the tablet is on the wall of his room.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Highlord Omokk", 9196), horde and { quest = 4903, objective = 2 } or nil)
		s:Collect(g.Item("Gemstone of Spirestone", 12336), { quest = 4742, objective = 1 })
		s:Note("West past Bijou's trench, at the back of the ogre hall. Whoever has the pike takes ", g.Item("Omokk's Head", 12534), ".")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Mother Smolderweb", 10596))
		s:Collect(g.Item("Spire Spider Egg", 12530), { count = 15, quest = 4862, objective = 1 })
		s:Note("In the Skitterweb Tunnels. Let her poison you with Mother's Milk and don't cleanse it: Ragged John needs it. Click the ", g.Object("Spire Spider Egg"), "s along the tunnels.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Urok Doomhowl", 10584))
		s:Collect(g.Item("Warosh's Mojo", 12712), { quest = 4867, objective = 1 })
		s:Note("Use ", g.Item("Omokk's Head", 12534), " at the pile of skulls up the ramp past Mother Smolderweb. Urok comes after a few waves of ogres.")
	end)

	g:Step(function(s)
		s.label = "bijou"
		s:Talk(bijou)
		if horde then
			s:Turnin(4982, "Bijou's Belongings")
			s:Accept(4983, "Bijou's Reconnaissance Report")
		else
			s:Turnin(5001, "Bijou's Belongings")
			s:Accept(5002, "Message to Maxwell")
		end
		s:Talk(warosh)
		s:Turnin(4867, "Urok Doomhowl")
		s:Note("Both are in Hordemar City.")
	end)

	g:Step(function(s)
		s:Use(g.Item("Empty Worg Pup Cage", 12262))
		s:Collect(g.Item("Caged Worg Pup", 12263), { quest = 4729, objective = 1 })
		s:Kill(g.Mob("Halycon", 10220), { quest = horde and 4724 or 4701, objective = 1 })
		s:Note("In Halycon's Lair, south-west from Urok past the scorpions. Cage a ", g.Mob("Bloodaxe Worg Pup"), " before the pack is dead.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Overlord Wyrmthalak", 9568), horde and { quest = 4903, objective = 1 } or nil)
		s:Collect(g.Item("Gemstone of Bloodaxe", 12337), { quest = 4742, objective = 3 })
		s:Note("The last boss, in the Chamber of Battle. The gemstones don't always drop.")
	end)

	g:Step(function(s)
		s.only = "onquest 4742 or done 4742"
		s:Talk(vaelan)
		s:Turnin(4742, "Seal of Ascension")
		s:Accept(4743, "Seal of Ascension")
		s:Note("Back by the entrance, on the way out.")
	end)
end

-- the second Seal of Ascension: Emberstrife in Dustwallow Marsh
local function emberstrife(g)
	g:Step(function(s)
		s.only = "onquest 4743 or done 4743"
		s:Goto(DUSTWALLOW, 56.7, 87.7)
		s:Use(g.Item("Vaelan's Gift", 12339))
		s:Kill(g.Mob("Emberstrife", 10321))
		s:Use(g.Item("Orb of Draconic Energy", 12300))
		s:Collect(g.Item("Forged Seal of Ascension", 12324), { quest = 4743, objective = 1 })
		s:Note("In the Wyrmbog, with a group. Open the gift, beat Emberstrife low without killing him, put down the Unforged Seal and use the orb on him; as him, breathe fire on the seal, then pick it up.")
	end)
end

-- back into the spire, for Vaelan and (Alliance) Maxwell's Mission
local function secondRun(g, cond, alliance)
	g:Step(function(s)
		s.only = cond
		enter(s, nil)
		s:Note("A second run, for what you brought back.")
	end)

	g:Step(function(s)
		s.only = "onquest 4743"
		s:Talk(g.Npc("Vaelan", 10296))
		s:Turnin(4743, "Seal of Ascension")
		s:Note("Up the ramp just inside. The seal it gives is the key to Upper Blackrock Spire.")
	end)

	if alliance then
		g:Step(function(s)
			s:Kill(g.Mob("War Master Voone", 9237), { quest = 5081, objective = 1 })
			s:Kill(g.Mob("Highlord Omokk", 9196), { quest = 5081, objective = 2 })
			s:Kill(g.Mob("Overlord Wyrmthalak", 9568), { quest = 5081, objective = 3 })
			s:Note("The three generals again: Voone at the bottom of Tazz'Alaor, Omokk past Bijou's trench, Wyrmthalak at the end.")
		end)
	end
end

ObviGuide.Guide(function(g)
	g.title = "Lower Blackrock Spire: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-lower-blackrock-spire"
	g.next  = "obvi-upper-blackrock-spire"
	g.only  = "Alliance"

	local maxwell  = g.Npc("Marshal Maxwell", 9560)
	local helendis = g.Npc("Helendis Riverhorn", 9562)

	moshaRu(g)

	g:Step(function(s)
		s:Goto(BURNING, 85.8, 69.0)
		s:Talk(helendis)
		s:Accept(4701, "Put Her Down")
		s:Note("At Morgan's Vigil, in the east of Burning Steppes.")
	end)

	flameCrest(g)
	dungeon(g, false)

	g:Step(function(s)
		s.label = "out"
		s:Goto(BURNING, 65.0, 23.8)
		s:Talk(g.Npc("Ragged John", 9563))
		s:Quest(4866, 1, "Let Ragged John milk the poison.")
		s:Turnin(4866, "Mother's Milk")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 65.9, 21.9)
		s:Talk(g.Npc("Kibler", 10260))
		s:Turnin(4729, "Kibler's Exotic Pets")
		s:Turnin(4862, "En-Ay-Es-Tee-Why")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 85.8, 69.0)
		s:Talk(helendis)
		s:Turnin(4701, "Put Her Down")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 84.7, 69.0)
		s:Talk(maxwell)
		s:Turnin(5002, "Message to Maxwell")
		s:Accept(5081, "Maxwell's Mission")
		s:Turnin(5089, "General Drakkisath's Command"):Only("onquest 5089 or done 5089")
		s:Note("Maxwell's Mission sends you back for the three generals.")
	end)

	g:Step(function(s)
		s.only = "onquest 4788 or done 4788"
		s:Goto(TANARIS, 66.9, 24.0)
		s:Talk(g.Npc("Prospector Ironboot", 10460))
		s:Turnin(4788, "The Final Tablets")
	end)

	emberstrife(g)
	secondRun(g, "onquest 5081 or onquest 4743", true)

	g:Step(function(s)
		s.only = "onquest 5081 or done 5081"
		s:Goto(BURNING, 84.7, 69.0)
		s:Talk(maxwell)
		s:Turnin(5081, "Maxwell's Mission")
	end)
end)

ObviGuide.Guide(function(g)
	g.title = "Lower Blackrock Spire: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-lower-blackrock-spire-horde"
	g.next  = "obvi-upper-blackrock-spire-horde"
	g.only  = "Horde"

	local vivian    = g.Npc("Shadowmage Vivian Lagrave", 9078)
	local goretooth = g.Npc("Warlord Goretooth", 9077)
	local lexlort   = g.Npc("Lexlort", 9080)
	local galamav   = g.Npc("Galamav the Marksman", 9081)

	moshaRu(g)

	g:Step(function(s)
		s:Goto(UNDERCITY, 50.1, 68.0)
		s:Talk(g.Npc("Apothecary Zinge", 5204))
		s:Accept(4769, "Vivian Lagrave and the Darkstone Tablet")
		s:Note("In the Apothecarium. Needs level 57.")
	end)

	-- Kargath
	g:Step(function(s)
		s:Goto(BADLANDS, 2.9, 47.8)
		s:Talk(vivian)
		s:Turnin(4769, "Vivian Lagrave and the Darkstone Tablet")
		s:Accept(4768, "The Darkstone Tablet")
		s:Note("In Kargath, in the west of the Badlands.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 5.8, 47.5)
		s:Talk(goretooth)
		s:Accept(4903, "Warlord's Command")
		s:Note("He walks around; listen to his story and the quest comes as ", g.Item("Warlord Goretooth's Command", 12563), " if it isn't offered straight away.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 5.9, 47.6)
		s:Talk(lexlort)
		s:Accept(4981, "Operative Bijou")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 6.0, 47.7)
		s:Talk(galamav)
		s:Accept(4724, "The Pack Mistress")
		s:Note("At the top of the tower. Then fly to Flame Crest.")
	end)

	flameCrest(g)
	dungeon(g, true)

	g:Step(function(s)
		s.label = "out"
		s:Goto(BURNING, 65.0, 23.8)
		s:Talk(g.Npc("Ragged John", 9563))
		s:Quest(4866, 1, "Let Ragged John milk the poison.")
		s:Turnin(4866, "Mother's Milk")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 65.9, 21.9)
		s:Talk(g.Npc("Kibler", 10260))
		s:Turnin(4729, "Kibler's Exotic Pets")
		s:Turnin(4862, "En-Ay-Es-Tee-Why")
		s:Note("Then fly to Kargath.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 6.0, 47.7)
		s:Talk(galamav)
		s:Turnin(4724, "The Pack Mistress")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 5.9, 47.6)
		s:Talk(lexlort)
		s:Turnin(4983, "Bijou's Reconnaissance Report")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 5.8, 47.5)
		s:Talk(goretooth)
		s:Turnin(4903, "Warlord's Command")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 2.9, 47.8)
		s:Talk(vivian)
		s:Turnin(4768, "The Darkstone Tablet")
	end)

	g:Step(function(s)
		s.only = "onquest 4788 or done 4788"
		s:Goto(TANARIS, 66.9, 24.0)
		s:Talk(g.Npc("Prospector Ironboot", 10460))
		s:Turnin(4788, "The Final Tablets")
	end)

	emberstrife(g)
	secondRun(g, "onquest 4743", false)
end)
