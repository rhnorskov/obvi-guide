-- Skeleton Key (Alliance and Horde, 50-60): the key to Scholomance. The Western Plaguelands opening (Clear the Way or
-- Scarlet Diversions, then All Along the Watchtowers), then the key chain: Skeletal Fragments, the mould from Krinkle
-- Goodsteel in Gadgetzan, forging it at Fire Plume Ridge in Un'Goro, Araj the Summoner in Andorhal, and The Key to
-- Scholomance. Alliance from Chillwind Camp, Horde from the Bulwark. Quest, NPC, item and object ids and positions
-- from Attune (CixiDelmont) and QuestieDB's Forever data. See README.md.

local TIRISFAL, PLAGUELANDS, TANARIS, UNGORO = 1420, 1422, 1446, 1449

-- Alliance: Chillwind Camp, in the south of the Western Plaguelands
ObviGuide.Guide(function(g)
	g.title = "Skeleton Key"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-scholomance"
	g.only  = "Alliance"

	local valorfist = g.Npc("Commander Ashlam Valorfist", 10838)
	local arbington = g.Npc("Alchemist Arbington", 11056)
	local torch     = g.Item("Beacon Torch", 12815)
	local mould     = g.Item("Skeleton Key Mold", 14644)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.7, 84.0)
		s:Talk(valorfist)
		s:Accept(5092, "Clear the Way")
		s:Note("In Chillwind Camp.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 49.5, 78.5)
		s:Kill(g.Mob("Skeletal Flayer", 1783), { quest = 5092, objective = 1 })
		s:Kill(g.Mob("Slavering Ghoul", 1791), { quest = 5092, objective = 2 })
		s:Note("On Sorrow Hill, east of the camp.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.7, 84.0)
		s:Talk(valorfist)
		s:Turnin(5092, "Clear the Way")
		s:Accept(5097, "All Along the Watchtowers")
	end)

	-- the four towers of Andorhal, from the south
	g:Step(function(s)
		s:Goto(PLAGUELANDS, 46.6, 71.1)
		s:Use(torch)
		s:Quest(5097, 4, "Mark Tower Four.")
		s:Note("Stand in the tower's doorway to use the torch.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 40.1, 71.6)
		s:Use(torch)
		s:Quest(5097, 1, "Mark Tower One.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.3, 66.2)
		s:Use(torch)
		s:Quest(5097, 2, "Mark Tower Two.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 44.3, 63.3)
		s:Use(torch)
		s:Quest(5097, 3, "Mark Tower Three.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.7, 84.0)
		s:Talk(valorfist)
		s:Turnin(5097, "All Along the Watchtowers")
		s:Level(55)
		s:Accept(5533, "Scholomance")
		s:Note("Scholomance needs level 55.")
		s:Talk(arbington)
		s:Turnin(5533, "Scholomance")
		s:Accept(5537, "Skeletal Fragments")
		s:Note(arbington, " stands right beside him.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 49.5, 78.5)
		s:Kill(g.Mob("Skeletal Flayer", 1783))
		s:Collect(g.Item("Skeletal Fragments", 14619), { count = 15, quest = 5537, objective = 1 })
		s:Note("Back on Sorrow Hill. Any skeleton in the Plaguelands drops them; Andorhal is full of them too.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.7, 83.8)
		s:Talk(arbington)
		s:Turnin(5537, "Skeletal Fragments")
		s:Accept(5538, "Mold Rhymes With...")
		s:Note("Krinkle Goodsteel wants 15 gold for the mould, and the next step needs 2 ", g.Item("Thorium Bar", 12359), ": bring them along.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 51.5, 28.8)
		s:Talk(g.Npc("Krinkle Goodsteel", 5411))
		s:Turnin(5538, "Mold Rhymes With...")
		s:Accept(5801, "Fire Plume Forged")
		s:Note("The blacksmith in Gadgetzan.")
	end)

	g:Step(function(s)
		s:Goto(UNGORO, 48.9, 47.0)
		s:Use(mould)
		s:Collect(g.Item("Unfinished Skeleton Key", 14645), { quest = 5801, objective = 1 })
		s:Note("At the top of Fire Plume Ridge, by the lava lake.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.7, 83.8)
		s:Talk(arbington)
		s:Turnin(5801, "Fire Plume Forged")
		s:Accept(5803, "Araj's Scarab")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 45.3, 69.2)
		s:Kill(g.Mob("Araj the Summoner", 1852))
		s:Say("Open ", g.Object("Araj's Phylactery"), " where he falls.")
		s:Collect(g.Item("Araj's Scarab", 14610), { quest = 5803, objective = 1 })
		s:Note("In the middle of Andorhal, among his skeletons. He is elite: bring friends.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.7, 83.8)
		s:Talk(arbington)
		s:Turnin(5803, "Araj's Scarab")
		s:Accept(5505, "The Key to Scholomance")
		s:Turnin(5505, "The Key to Scholomance")
		s:Note("The Skeleton Key is the reward; only one person in the group needs it.")
	end)
end)

-- Horde: the Bulwark, on the Tirisfal side of the border
ObviGuide.Guide(function(g)
	g.title = "Skeleton Key"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-scholomance-horde"
	g.only  = "Horde"

	local derrington = g.Npc("High Executor Derrington", 10837)
	local dithers    = g.Npc("Apothecary Dithers", 11057)
	local torch      = g.Item("Beacon Torch", 12815)
	local mould      = g.Item("Skeleton Key Mold", 14644)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 68.9)
		s:Talk(derrington)
		s:Accept(5096, "Scarlet Diversions")
		s:Note("At the Bulwark, on the eastern edge of Tirisfal.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.2, 69.1)
		s:Say("Take a flame from the ", g.Object("Box of Incendiaries"), ".")
		s:Collect(g.Item("Flame in a Bottle", 12814))
		s:Note("Right next to him.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 40.7, 52.0)
		s:Say("Set the ", g.Object("Command Tent"), " alight, then plant the banner.")
		s:Use(g.Item("Scourge Banner", 12807))
		s:Quest(5096, 1, "Destroy the command tent and plant the Scourge banner.")
		s:Note("The Scarlet camp between Felstone Field and Dalson's Tears.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 68.9)
		s:Talk(derrington)
		s:Turnin(5096, "Scarlet Diversions")
		s:Accept(5098, "All Along the Watchtowers")
	end)

	-- the four towers of Andorhal, from the north
	g:Step(function(s)
		s:Goto(PLAGUELANDS, 44.3, 63.3)
		s:Use(torch)
		s:Quest(5098, 3, "Mark Tower Three.")
		s:Note("Stand in the tower's doorway to use the torch.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 42.3, 66.2)
		s:Use(torch)
		s:Quest(5098, 2, "Mark Tower Two.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 40.1, 71.6)
		s:Use(torch)
		s:Quest(5098, 1, "Mark Tower One.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 46.6, 71.1)
		s:Use(torch)
		s:Quest(5098, 4, "Mark Tower Four.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.1, 68.9)
		s:Talk(derrington)
		s:Turnin(5098, "All Along the Watchtowers")
		s:Level(55)
		s:Accept(838, "Scholomance")
		s:Note("Scholomance needs level 55.")
		s:Talk(dithers)
		s:Turnin(838, "Scholomance")
		s:Accept(964, "Skeletal Fragments")
		s:Note(dithers, " stands right beside him.")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 44.5, 68.0)
		s:Kill(g.Mob("Skeletal Executioner", 1787))
		s:Kill(g.Mob("Skeletal Warlord", 1788))
		s:Collect(g.Item("Skeletal Fragments", 14619), { count = 15, quest = 964, objective = 1 })
		s:Note("In Andorhal. Any skeleton in the Plaguelands drops them.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.3, 69.2)
		s:Talk(dithers)
		s:Turnin(964, "Skeletal Fragments")
		s:Accept(5514, "Mold Rhymes With...")
		s:Note("Krinkle Goodsteel wants 15 gold for the mould, and the next step needs 2 ", g.Item("Thorium Bar", 12359), ": bring them along.")
	end)

	g:Step(function(s)
		s:Goto(TANARIS, 51.5, 28.8)
		s:Talk(g.Npc("Krinkle Goodsteel", 5411))
		s:Turnin(5514, "Mold Rhymes With...")
		s:Accept(5802, "Fire Plume Forged")
		s:Note("The blacksmith in Gadgetzan.")
	end)

	g:Step(function(s)
		s:Goto(UNGORO, 48.9, 47.0)
		s:Use(mould)
		s:Collect(g.Item("Unfinished Skeleton Key", 14645), { quest = 5802, objective = 1 })
		s:Note("At the top of Fire Plume Ridge, by the lava lake.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.3, 69.2)
		s:Talk(dithers)
		s:Turnin(5802, "Fire Plume Forged")
		s:Accept(5804, "Araj's Scarab")
	end)

	g:Step(function(s)
		s:Goto(PLAGUELANDS, 45.3, 69.2)
		s:Kill(g.Mob("Araj the Summoner", 1852))
		s:Say("Open ", g.Object("Araj's Phylactery"), " where he falls.")
		s:Collect(g.Item("Araj's Scarab", 14610), { quest = 5804, objective = 1 })
		s:Note("In the middle of Andorhal, among his skeletons. He is elite: bring friends.")
	end)

	g:Step(function(s)
		s:Goto(TIRISFAL, 83.3, 69.2)
		s:Talk(dithers)
		s:Turnin(5804, "Araj's Scarab")
		s:Talk(derrington)
		s:Accept(5511, "The Key to Scholomance")
		s:Turnin(5511, "The Key to Scholomance")
		s:Note("The Skeleton Key is the reward; only one person in the group needs it.")
	end)
end)
