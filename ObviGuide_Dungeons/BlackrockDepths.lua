-- Blackrock Depths (48-60): the quests Attune lists for each faction, in two runs. Both: The Heart of the Mountain,
-- Ribbly Screwspigot, A Taste of Flame, the Thunderbrew recipe, and The Love Potion inside. Alliance: Ragnar Thunderbrew
-- and Hurley Blackbreath, The Good Stuff, Overmaster Pyron and Incendius!, The Smoldering Ruins of Thaurissan up to
-- The Princess's Surprise, Dragonkin Menace and The True Masters up to Marshal Windsor, Abandoned Hope and A Crumpled
-- Up Note. Horde: Lost Thunderbrew Recipe, The Last Element, The Rise of the Machines, the two KILL ON SIGHT bounties,
-- and Disharmony of Flame up to The Princess Saved?. Attune also counts the Shadowforge Key and the Molten Core
-- attunement here; they have guides of their own. Quest, NPC and item ids from Attune (CixiDelmont) and QuestieDB's
-- Forever data, the entrance and boss order from DungeonJournal (Exehn). Organised by hub: the Burning Steppes camps
-- (Morgan's Vigil, Flame Crest) or Kargath, then the first run; the hand-ins that open the rest; the second run.
-- See README.md.

local IRONFORGE, DUN_MOROGH, STORMWIND, ORGRIMMAR = 1455, 1426, 1453, 1454
local BLASTED, BURNING, REDRIDGE, SEARING, BADLANDS = 1419, 1428, 1433, 1427, 1418
local AZSHARA, UNGORO = 1447, 1449

-- the parts both factions share ---------------------------------------------------------------------------------

local function npcs(g)
	return {
		maxwort = g.Npc("Maxwort Uberglint", 9536),
		yuka    = g.Npc("Yuka Screwspigot", 9544),
		cyrus   = g.Npc("Cyrus Therepentous", 9459),
		nagmara = g.Npc("Mistress Nagmara", 9500),
	}
end

-- Flame Crest, in the north of the Burning Steppes; `extra` adds the faction's own lines there
local function flameCrestPickups(g, n, extra)
	g:Step(function(s)
		s:Goto(BURNING, 65.2, 23.9)
		if extra then extra(s) end
		s:Talk(n.maxwort)
		s:Accept(4123, "The Heart of the Mountain")
		s:Talk(n.yuka)
		s:Accept(4136, "Ribbly Screwspigot")
		s:Note("At Flame Crest. Yuka is in the small cave just behind, at 66.1, 22.0.")
	end)
end

-- Cyrus and A Taste of Flame; its first part needs the Molt from Kalaran Windblade's chain in Searing Gorge
local function tasteOfFlame(g, n)
	g:Step(function(s)
		s.only = "not done 3481 and not onquest 4022 and not done 4022 and not onquest 4024 and not done 4024"
		s:Do("A Taste of Flame needs the Black Dragonflight Molt from Kalaran Windblade's chain in Searing Gorge (Divine Retribution up to Trinkets...). Do that first, or tick this to leave it out.")
	end)

	g:Step(function(s)
		s.only = "done 3481 or onquest 4022 or done 4022 or onquest 4024 or done 4024"
		s:Goto(BURNING, 95.1, 31.6)
		s:Talk(n.cyrus)
		s:Accept(4022, "A Taste of Flame")
		s:Turnin(4022, "A Taste of Flame")
		s:Accept(4024, "A Taste of Flame")
		s:Note("In a cave on the eastern edge of the Steppes. Show him the Molt; he alters it for Bael'Gar.")
	end)
end

local function flameCrestTurnins(g, n)
	g:Step(function(s)
		s:Goto(BURNING, 65.2, 23.9)
		s:Talk(n.maxwort)
		s:Turnin(4123, "The Heart of the Mountain")
		s:Talk(n.yuka)
		s:Turnin(4136, "Ribbly Screwspigot")
	end)

	g:Step(function(s)
		s.only = "onquest 4024 or done 4024"
		s:Goto(BURNING, 95.1, 31.6)
		s:Talk(n.cyrus)
		s:Turnin(4024, "A Taste of Flame")
	end)
end

local function enter(g, skip)
	g:Step(function(s)
		s.skip = skip
		s:Goto(SEARING, 34.8, 84.0)
		s:Do("Enter Blackrock Depths with your group.")
		s:Note("In Blackrock Mountain: take the chain down from the Blackrock Spire ledge and follow the lower path to the portal.")
	end)
end

-- the keys for the Black Vault, the fanny packs and The Love Potion: side tasks for the first run
local function firstRunSides(g, n, until_)
	g:Side(until_, function(s)
		s.only = "not ready 4123 and not done 4123"
		s:Collect(g.Item("Relic Coffer Key", 11078), { count = 12 })
		s:Note("They drop throughout the Depths; you need 12 for the Black Vault.")
	end)

	g:Side(until_, function(s)
		s:Talk(n.nagmara)
		s:Accept(4201, "The Love Potion")
		s:Note("Optional: she walks around the Grim Guzzler. Its items are gathered outside, for the second run.")
	end)
end

local function vault(g)
	g:Step(function(s)
		s:Kill(g.Mob("Watchman Doomgrip", 9476))
		s:Collect(g.Item("The Heart of the Mountain", 11309), { quest = 4123, objective = 1 })
		s:Note("In the Black Vault off Shadowforge City: open all twelve Relic Coffers with the keys and Watchman Doomgrip comes. The Heart sits on a pillow under the Dark Coffer.")
	end)
end

local function baelgar(g)
	g:Step(function(s)
		s.only = "onquest 4024 or done 4024"
		s:Kill(g.Mob("Bael'Gar", 9016))
		s:Use(g.Item("Altered Black Dragonflight Molt", 11231))
		s:Collect(g.Item("Encased Fiery Essence", 11230), { quest = 4024, objective = 1 })
		s:Note("At the far end of the Dark Iron Highway. Use the Molt on his remains.")
	end)
end

-- the Grim Guzzler: Ribbly, then Hurley for the recipe (`recipe` is the faction's quest)
local function guzzler(g, recipe, label)
	g:Step(function(s)
		s:Kill(g.Mob("Ribbly Screwspigot", 9543))
		s:Collect(g.Item("Ribbly's Head", 11313), { quest = 4136, objective = 1 })
		s:Note("Downstairs in the Grim Guzzler. The bar turns on you when he's attacked.")
	end)

	g:Step(function(s)
		s.label = label
		s:Kill(g.Mob("Hurley Blackbreath", 9537))
		s:Collect(g.Item("Lost Thunderbrew Recipe", 11312), { quest = recipe, objective = 1 })
		s:Note("Break the three kegs (", g.Object("Thunderbrew Lager Keg"), ") in the Guzzler's side room and he comes out with his friends.")
	end)
end

-- The Love Potion's three ingredients, gathered between the runs
local function lovePotion(g, until_)
	g:Side(until_, function(s)
		s.only = "onquest 4201"
		s:Collect(g.Item("Gromsblood", 8846), { count = 4, quest = 4201, objective = 1 })
		s:Note("An herb: pick it or buy it on the auction house.")
	end)

	g:Side(until_, function(s)
		s.only = "onquest 4201"
		s:Goto(AZSHARA, 56.7, 79.8)
		s:Kill(g.Mob("Cliff Breaker", 6146))
		s:Kill(g.Mob("Cliff Thunderer", 6147))
		s:Collect(g.Item("Giant Silver Vein", 11405), { count = 10, quest = 4201, objective = 2 })
		s:Note("The giants in southern Azshara.")
	end)

	g:Side(until_, function(s)
		s.only = "onquest 4201"
		s:Goto(UNGORO, 32.0, 50.0)
		s:Use(g.Item("Nagmara's Vial", 11412))
		s:Collect(g.Item("Nagmara's Filled Vial", 11413), { quest = 4201, objective = 3 })
		s:Note("Fill it in the water of the Golakka Hot Springs.")
	end)
end

local function secondRun(g, n, rescue)
	g:Step(function(s)
		s.only = "onquest 4201"
		s:Talk(n.nagmara)
		s:Turnin(4201, "The Love Potion")
		s:Note("In the Grim Guzzler.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Emperor Dagran Thaurissan", 9019), { quest = rescue, objective = 1 })
		s:Note("Past the Grim Guzzler (Dark Iron Ale for Private Rocknot, or fight Phalanx): light the braziers in the Lyceum with the torches the Flame Keepers drop, kill Magmus, and the Imperial Seat is behind. ", g.Warn("Don't kill Princess Moira"), "; interrupt her heals.")
	end)
end

-- Alliance -------------------------------------------------------------------------------------------------------

ObviGuide.Guide(function(g)
	g.title = "Blackrock Depths: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-blackrock-depths"
	g.next  = "obvi-dire-maul"
	g.only  = "Alliance"

	local n = npcs(g)
	local archesonus = g.Npc("Royal Historian Archesonus", 8879)
	local magni      = g.Npc("King Magni Bronzebeard", 2784)
	local ragnar     = g.Npc("Ragnar Thunderbrew", 1267)
	local oralius    = g.Npc("Oralius", 9177)
	local helendis   = g.Npc("Helendis Riverhorn", 9562)
	local jalinda    = g.Npc("Jalinda Sprig", 9561)
	local maxwell    = g.Npc("Marshal Maxwell", 9560)
	local solomon    = g.Npc("Magistrate Solomon", 344)
	local bolvar     = g.Npc("Highlord Bolvar Fordragon", 1748)
	local windsor    = g.Npc("Marshal Windsor", 9023)

	-- Blasted Lands, Ironforge and Kharanos
	g:Step(function(s)
		s.skip = "onquest 4126 or done 4126"
		s:Goto(BLASTED, 63.6, 20.6)
		s:Talk(g.Npc("Enohar Thunderbrew", 9540))
		s:Accept(4128, "Ragnar Thunderbrew")
		s:Note("At Nethergarde Keep. It only leads to Ragnar: skip it if you're not passing by.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 38.4, 55.3)
		s:Talk(archesonus)
		s:Accept(3702, "The Smoldering Ruins of Thaurissan")
		s:Quest(3702, 1, "Listen to the story of Thaurissan.")
		s:Turnin(3702, "The Smoldering Ruins of Thaurissan")
		s:Accept(3701, "The Smoldering Ruins of Thaurissan")
		s:Note("In the Hall of Explorers.")
	end)

	g:Step(function(s)
		s:Goto(DUN_MOROGH, 46.8, 52.4)
		s:Talk(ragnar)
		s:Turnin(4128, "Ragnar Thunderbrew"):Only("onquest 4128")
		s:Accept(4126, "Hurley Blackbreath")
		s:Note("In Kharanos. Then fly from Ironforge to Morgan's Vigil.")
	end)

	-- Morgan's Vigil, then the dragonkin and the ruins
	g:Step(function(s)
		s:Goto(BURNING, 85.0, 69.0)
		s:Talk(oralius)
		s:Accept(4286, "The Good Stuff")
		s:Talk(helendis)
		s:Accept(4182, "Dragonkin Menace")
		s:Talk(jalinda)
		s:Accept(4262, "Overmaster Pyron")
		s:Note("At Morgan's Vigil, in the south-east of the Burning Steppes.")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 85.4, 28.5)
		s:Kill(g.Mob("Black Broodling", 7047), { quest = 4182, objective = 1 })
		s:Kill(g.Mob("Black Dragonspawn", 7040), { quest = 4182, objective = 2 })
		s:Kill(g.Mob("Black Drake", 7044), { quest = 4182, objective = 3 })
		s:Kill(g.Mob("Black Wyrmkin", 7041), { quest = 4182, objective = 4 })
		s:Note("Along the north-eastern hills. The drakes fly around; one is often near 84.9, 28.5.")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 60.3, 37.7)
		s:Quest(3701, 1, "Recover the information from the Thaurissan Relics.")
		s:Note("Click the small relics (", g.Object("Thaurissan Relic"), ") on the ground all over the Ruins of Thaurissan.")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 85.8, 69.0)
		s:Talk(helendis)
		s:Turnin(4182, "Dragonkin Menace")
		s:Accept(4183, "The True Masters")
		s:Note("Then fly to Lakeshire.")
	end)

	-- The True Masters: Lakeshire, Stormwind (and Ironforge by the tram), Lakeshire
	g:Step(function(s)
		s:Goto(REDRIDGE, 24.9, 44.5)
		s:Talk(solomon)
		s:Turnin(4183, "The True Masters")
		s:Accept(4184, "The True Masters")
		s:Note("In the town hall in Lakeshire. Then fly to Stormwind.")
	end)

	g:Step(function(s)
		s:Goto(STORMWIND, 80.2, 38.4)
		s:Talk(bolvar)
		s:Turnin(4184, "The True Masters")
		s:Accept(4185, "The True Masters")
		s:Talk(g.Npc("Lady Katrana Prestor", 1749))
		s:Quest(4185, 1, "Ask Lady Katrana Prestor for her advice.")
		s:Talk(bolvar)
		s:Turnin(4185, "The True Masters")
		s:Accept(4186, "The True Masters")
		s:Note("In the throne room of Stormwind Keep. Then take the Deeprun Tram to Ironforge.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 38.4, 55.3)
		s:Talk(archesonus)
		s:Turnin(3701, "The Smoldering Ruins of Thaurissan")
		s:Talk(magni)
		s:Accept(4341, "Kharan Mighthammer")
		s:Note("Magni is in the throne room next to the Hall of Explorers. Then fly to Lakeshire.")
	end)

	g:Step(function(s)
		s:Goto(REDRIDGE, 24.9, 44.5)
		s:Talk(solomon)
		s:Turnin(4186, "The True Masters")
		s:Accept(4223, "The True Masters")
		s:Note("Then fly to Morgan's Vigil.")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 84.7, 69.0)
		s:Talk(maxwell)
		s:Turnin(4223, "The True Masters")
		s:Accept(4224, "The True Masters")
	end)

	-- north: Cyrus, then Flame Crest, then back to Maxwell
	tasteOfFlame(g, n)

	flameCrestPickups(g, n, function(s)
		s:Talk(g.Npc("Ragged John", 9563))
		s:Quest(4224, 1, "Hear Ragged John's story.")
	end)

	g:Step(function(s)
		s:Goto(BURNING, 84.7, 69.0)
		s:Talk(maxwell)
		s:Turnin(4224, "The True Masters")
		s:Accept(4241, "Marshal Windsor")
		s:Note("Then on to Blackrock Mountain, at the west end of the Steppes.")
	end)

	g:Step(function(s)
		s:Goto(SEARING, 34.8, 84.0)
		s:Kill(g.Mob("Overmaster Pyron", 9026), { quest = 4262, objective = 1 })
		s:Note("An elite fire elemental in the quarry inside Blackrock Mountain, on the way to the Depths. Bring the group.")
	end)

	-- the first run
	enter(g, "done 4241 or done 4341")

	firstRunSides(g, n, "run1")

	g:Side("run1", function(s)
		s:Collect(g.Item("Dark Iron Fanny Pack", 11468), { count = 20, quest = 4286, objective = 1 })
		s:Note("The Dark Iron dwarves throughout the Depths carry them.")
	end)

	g:Side("run1", function(s)
		local note = g.Item("A Crumpled Up Note", 11446)
		s:Use(note):Only("not onquest 4264 and not done 4264")
		s:Accept(4264, "A Crumpled Up Note")
		s:Note("The dwarves sometimes drop ", note, ": it goes to Marshal Windsor, so read it before you free him.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("High Interrogator Gerstahn", 9018))
		s:Talk(g.Npc("Kharan Mighthammer", 9021))
		s:Turnin(4341, "Kharan Mighthammer")
		s:Accept(4342, "Kharan's Tale")
		s:Quest(4342, 1, "Listen to Kharan's tale.")
		s:Turnin(4342, "Kharan's Tale")
		s:Accept(4361, "The Bearer of Bad News")
		s:Note("The Detention Block, right after the entrance: Gerstahn drops the ", g.Item("Prison Cell Key", 11140), " for the cells.")
	end)

	g:Step(function(s)
		s:Talk(windsor)
		s:Turnin(4241, "Marshal Windsor")
		s:Turnin(4264, "A Crumpled Up Note"):Only("onquest 4264")
		s:Accept(4242, "Abandoned Hope")
		s:Note("In another cell along the same corridor.")
	end)

	vault(g)
	baelgar(g)
	guzzler(g, 4126, "run1")

	-- between the runs: Flame Crest and Cyrus, Morgan's Vigil, Ironforge and Kharanos
	lovePotion(g, "run2")

	flameCrestTurnins(g, n)

	g:Step(function(s)
		s:Goto(BURNING, 85.0, 69.0)
		s:Talk(maxwell)
		s:Turnin(4242, "Abandoned Hope")
		s:Talk(oralius)
		s:Turnin(4286, "The Good Stuff"):Only("ready 4286")
		s:Talk(jalinda)
		s:Turnin(4262, "Overmaster Pyron")
		s:Accept(4263, "Incendius!")
		s:Note("Then fly to Ironforge.")
	end)

	g:Step(function(s)
		s:Goto(DUN_MOROGH, 46.8, 52.4)
		s:Talk(ragnar)
		s:Turnin(4126, "Hurley Blackbreath")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 39.1, 56.2)
		s:Talk(magni)
		s:Turnin(4361, "The Bearer of Bad News")
		s:Accept(4362, "The Fate of the Kingdom")
		s:Note("Then fly back to Morgan's Vigil and on to Blackrock Mountain.")
	end)

	-- the second run
	enter(g, "ready 4263 or done 4263 or onquest 4363 or done 4363")

	g:Side("run2", function(s)
		s.only = "not done 4286"
		s:Collect(g.Item("Dark Iron Fanny Pack", 11468), { count = 20, quest = 4286, objective = 1 })
		s:Note("If you still need them: the Dark Iron dwarves carry them.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lord Incendius", 9017), { quest = 4263, objective = 1 })
		s:Note("At the Black Anvil, below the Hall of Crafting off Shadowforge City.")
	end)

	secondRun(g, n, 4362)

	g:Step(function(s)
		s.label = "run2"
		s:Talk(g.Npc("Princess Moira Bronzebeard", 8929))
		s:Turnin(4362, "The Fate of the Kingdom")
		s:Accept(4363, "The Princess's Surprise")
	end)

	-- the last turn-ins
	g:Step(function(s)
		s:Goto(BURNING, 85.0, 69.0)
		s:Talk(jalinda)
		s:Turnin(4263, "Incendius!")
		s:Talk(oralius)
		s:Turnin(4286, "The Good Stuff")
		s:Note("Then fly to Ironforge.")
	end)

	g:Step(function(s)
		s:Goto(IRONFORGE, 39.1, 56.2)
		s:Talk(magni)
		s:Turnin(4363, "The Princess's Surprise")
	end)
end)

-- Horde ----------------------------------------------------------------------------------------------------------

ObviGuide.Guide(function(g)
	g.title = "Blackrock Depths: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-blackrock-depths-horde"
	g.next  = "obvi-dire-maul-horde"
	g.only  = "Horde"

	local n = npcs(g)
	local vivian      = g.Npc("Shadowmage Vivian Lagrave", 9078)
	local thunderheart = g.Npc("Thunderheart", 9084)
	local goretooth   = g.Npc("Warlord Goretooth", 9077)
	local lotwil      = g.Npc("Lotwil Veriatus", 2921)
	local thrall      = g.Npc("Thrall", 4949)
	local gorshak     = g.Npc("Commander Gor'shak", 9020)

	-- Kargath, and Lotwil out east
	g:Step(function(s)
		s:Goto(BADLANDS, 3.3, 47.8)
		s:Talk(vivian)
		s:Accept(4134, "Lost Thunderbrew Recipe")
		s:Talk(thunderheart)
		s:Accept(3906, "Disharmony of Flame")
		s:Accept(4081, "KILL ON SIGHT: Dark Iron Dwarves")
		s:Note("In Kargath. Thunderheart walks a patrol: wait for him to stop before you click him. The bounty is on the ", g.Object("WANTED"), " poster at 3.7, 47.4.")
	end)

	g:Step(function(s)
		s.only = "not onquest 4062 and not done 4062 and not onquest 4063 and not done 4063"
		s:Do("The Rise of the Machines needs Hierophant Theodora Mulvadania's first two parts (in Kargath; the shards come from the Burning Steppes). Do them first, or tick this to leave it out.")
	end)

	g:Step(function(s)
		s.only = "onquest 4062 or done 4062 or onquest 4063 or done 4063"
		s:Goto(BADLANDS, 26.0, 44.9)
		s:Talk(lotwil)
		s:Turnin(4062, "The Rise of the Machines"):Only("onquest 4062")
		s:Accept(4063, "The Rise of the Machines")
		s:Note("At his camp in the middle of the Badlands. Then fly from Kargath to Flame Crest.")
	end)

	-- the Burning Steppes, then Pyron
	flameCrestPickups(g, n)
	tasteOfFlame(g, n)

	g:Step(function(s)
		s:Goto(SEARING, 34.8, 84.0)
		s:Kill(g.Mob("Overmaster Pyron", 9026), { quest = 3906, objective = 1 })
		s:Note("An elite fire elemental in the quarry inside Blackrock Mountain. Kill him before the first run: turning him in opens three quests for it.")
	end)

	g:Step(function(s)
		s:Goto(BADLANDS, 3.3, 48.3)
		s:Talk(thunderheart)
		s:Turnin(3906, "Disharmony of Flame")
		s:Accept(3907, "Disharmony of Fire")
		s:Talk(vivian)
		s:Accept(7201, "The Last Element")
		s:Talk(g.Npc("Galamav the Marksman", 9081))
		s:Accept(3981, "Commander Gor'shak")
		s:Note("Back in Kargath; Galamav is at the top of the tower at 6.0, 47.7.")
	end)

	-- the first run
	enter(g, "done 3981 or onquest 4001 or done 4001")

	firstRunSides(g, n, "run1")

	g:Side("run1", function(s)
		s:Kill(g.Mob("Anvilrage Guardsman", 8891), { quest = 4081, objective = 1 })
		s:Kill(g.Mob("Anvilrage Warden", 8890), { quest = 4081, objective = 2 })
		s:Kill(g.Mob("Anvilrage Footman", 8892), { quest = 4081, objective = 3 })
		s:Note("In the Detention Block and the halls around the Ring of Law.")
	end)

	g:Side("run1", function(s)
		s:Kill(g.Mob("Warbringer Construct", 8905))
		s:Kill(g.Mob("Ragereaver Golem", 8906))
		s:Collect(g.Item("Essence of the Elements", 11129), { count = 10, quest = 7201, objective = 1 })
		s:Note("From the golems, their makers and the fire elementals.")
	end)

	g:Side("run1", function(s)
		s.only = "onquest 4063"
		s:Kill(g.Mob("Warbringer Construct", 8905))
		s:Kill(g.Mob("Ragereaver Golem", 8906))
		s:Collect(g.Item("Intact Elemental Core", 11269), { count = 10, quest = 4063, objective = 2 })
		s:Note("From the golems, most of them around Argelmach in the Manufactory.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("High Interrogator Gerstahn", 9018))
		s:Talk(gorshak)
		s:Turnin(3981, "Commander Gor'shak")
		s:Accept(3982, "What Is Going On?")
		s:Note("The Detention Block, right after the entrance: Gerstahn drops the ", g.Item("Prison Cell Key", 11140), " for the cells.")
	end)

	g:Step(function(s)
		s:Quest(3982, 1, "Keep Commander Gor'shak alive.")
		s:Talk(gorshak)
		s:Turnin(3982, "What Is Going On?")
		s:Accept(4001, "What Is Going On?")
		s:Note("Two waves of guards come to his cell; clear the corridor first.")
	end)

	g:Step(function(s)
		s:Talk(g.Npc("Kharan Mighthammer", 9021))
		s:Quest(4001, 1, "Hear Kharan Mighthammer's story.")
		s:Note("In the cell across the corridor.")
	end)

	vault(g)

	g:Step(function(s)
		s:Kill(g.Mob("Lord Incendius", 9017), { quest = 3907, objective = 1 })
		s:Collect(g.Item("Tablet of Kurniya", 11126), { quest = 3907, objective = 2 })
		s:Note("At the Black Anvil, below the Hall of Crafting off Shadowforge City.")
	end)

	baelgar(g)

	g:Step(function(s)
		s.only = "onquest 4063 or done 4063"
		s:Kill(g.Mob("Golem Lord Argelmach", 8983))
		s:Collect(g.Item("Head of Argelmach", 11268), { quest = 4063, objective = 1 })
		s:Note("In the Manufactory, by the West Garrison.")
	end)

	guzzler(g, 4134, "run1")

	-- between the runs: Flame Crest and Cyrus, Kargath, Lotwil, Orgrimmar
	lovePotion(g, "run2")

	flameCrestTurnins(g, n)

	g:Step(function(s)
		s:Goto(BADLANDS, 3.3, 48.3)
		s:Talk(thunderheart)
		s:Turnin(3907, "Disharmony of Fire")
		s:Talk(vivian)
		s:Turnin(4134, "Lost Thunderbrew Recipe")
		s:Turnin(7201, "The Last Element")
		s:Talk(goretooth)
		s:Turnin(4081, "KILL ON SIGHT: Dark Iron Dwarves")
		s:Accept(4082, "KILL ON SIGHT: High Ranking Dark Iron Officials")
		s:Note("Fly from Flame Crest to Kargath. Goretooth is at the top of the tower (5.8, 47.5); the next bounty is on the ", g.Object("KILL ON SIGHT"), " poster at 3.9, 46.7.")
	end)

	g:Step(function(s)
		s.only = "onquest 4063 or done 4063"
		s:Goto(BADLANDS, 26.0, 44.9)
		s:Talk(lotwil)
		s:Turnin(4063, "The Rise of the Machines")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Turnin(4001, "What Is Going On?")
		s:Accept(4002, "The Eastern Kingdom")
		s:Turnin(4002, "The Eastern Kingdom")
		s:Accept(4003, "The Royal Rescue")
		s:Note("In Grommash Hold. Then back to Blackrock Mountain.")
	end)

	-- the second run
	enter(g, "onquest 4004 or done 4004")

	g:Side("run2", function(s)
		s:Kill(g.Mob("Anvilrage Medic", 8894), { quest = 4082, objective = 1 })
		s:Kill(g.Mob("Anvilrage Soldier", 8893), { quest = 4082, objective = 2 })
		s:Kill(g.Mob("Anvilrage Officer", 8895), { quest = 4082, objective = 3 })
		s:Note("Along the way, mostly in the Detention Block and the garrisons.")
	end)

	secondRun(g, n, 4003)

	g:Step(function(s)
		s.label = "run2"
		s:Talk(g.Npc("Princess Moira Bronzebeard", 8929))
		s:Turnin(4003, "The Royal Rescue")
		s:Accept(4004, "The Princess Saved?")
	end)

	-- the last turn-ins
	g:Step(function(s)
		s:Goto(BADLANDS, 5.8, 47.5)
		s:Talk(goretooth)
		s:Turnin(4082, "KILL ON SIGHT: High Ranking Dark Iron Officials")
		s:Note("At the top of the tower in Kargath.")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Turnin(4004, "The Princess Saved?")
	end)
end)
