-- Aqual Quintessence (both factions, 55-60): douses the runes in Molten Core so Majordomo Executus comes out. Duke
-- Hydraxis's chain in Azshara: Poisoned Water (Eastern Plaguelands) and Stormers and Rumblers (Silithus), Eye of the
-- Emberseer (Upper Blackrock Spire), The Molten Core, Agent of Hydraxis (Honored with the Hydraxian Waterlords),
-- Hands of the Enemy, and A Hero's Reward. Quest, NPC, item and object ids and positions from Attune (CixiDelmont)
-- and QuestieDB's Forever data. See README.md.

local AZSHARA, EASTERN_PLAGUELANDS, SILITHUS = 1447, 1423, 1451

ObviGuide.Guide(function(g)
	g.title = "Aqual Quintessence"
	g.group = "Extras"
	g.id    = "obvi-aqual-quintessence"

	local hydraxis = g.Npc("Duke Hydraxis", 13278)
	local aspect   = g.Item("Aspect of Neptulon", 17310)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Accept(6804, "Poisoned Water")
		s:Accept(6805, "Stormers and Rumblers")
		s:Note("On the small island off the south-east coast of Azshara.")
	end)

	g:Step(function(s)
		s:Goto(EASTERN_PLAGUELANDS, 54.2, 69.5)
		s:Use(aspect)
		s:Kill(g.Mob("Blighted Surge", 8519))
		s:Kill(g.Mob("Plague Ravager", 8520))
		s:Collect(g.Item("Discordant Bracers", 17309), { count = 12, quest = 6804, objective = 1 })
		s:Note("Use the ", aspect, " on the poisoned elementals, then kill them.")
	end)

	g:Step(function(s)
		s:Goto(SILITHUS, 18.5, 21.0)
		s:Kill(g.Mob("Dust Stormer", 11744), { quest = 6805, objective = 1 })
		s:Kill(g.Mob("Desert Rumbler", 11746), { quest = 6805, objective = 2 })
		s:Note("In the north-west of Silithus: the stormers mostly around 17.2, 26.0, the rumblers further north around 19.5, 15.5.")
	end)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6804, "Poisoned Water")
		s:Turnin(6805, "Stormers and Rumblers")
		s:Accept(6821, "Eye of the Emberseer")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Pyroguard Emberseer", 9816))
		s:Collect(g.Item("Eye of the Emberseer", 17322), { quest = 6821, objective = 1 })
		s:Note("The first boss of Upper Blackrock Spire, with a raid group. Someone in the group needs the key to the upper spire.")
	end)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6821, "Eye of the Emberseer")
		s:Accept(6822, "The Molten Core")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Molten Giant", 11658), { quest = 6822, objective = 1 })
		s:Kill(g.Mob("Firelord", 11668), { quest = 6822, objective = 2 })
		s:Kill(g.Mob("Ancient Core Hound", 11673), { quest = 6822, objective = 3 })
		s:Kill(g.Mob("Lava Surger", 12101), { quest = 6822, objective = 4 })
		s:Note("In Molten Core: one of each on the way through the first bosses. The Molten Core trash also gives Hydraxian Waterlords reputation, which the next quest needs.")
	end)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6822, "The Molten Core")
		s:Accept(6823, "Agent of Hydraxis")
	end)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6823, "Agent of Hydraxis")
		s:Accept(6824, "Hands of the Enemy")
		s:Note("Once you are Honored with the Hydraxian Waterlords, from Molten Core runs.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Lucifron", 12118))
		s:Kill(g.Mob("Gehennas", 12259))
		s:Kill(g.Mob("Shazzrah", 12264))
		s:Kill(g.Mob("Sulfuron Harbinger", 12098))
		s:Collect(g.Item("Hand of Lucifron", 17329))
		s:Collect(g.Item("Hand of Gehennas", 17331))
		s:Collect(g.Item("Hand of Shazzrah", 17332))
		s:Collect(g.Item("Hand of Sulfuron", 17330))
		s:Note("Four of the Molten Core bosses.")
	end)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.3, 73.7)
		s:Talk(hydraxis)
		s:Turnin(6824, "Hands of the Enemy")
		s:Accept(7486, "A Hero's Reward")
	end)

	g:Step(function(s)
		s:Goto(AZSHARA, 79.2, 74.9)
		s:Say("Open ", g.Object("Hydraxis' Coffer"), ".")
		s:Turnin(7486, "A Hero's Reward")
		s:Note("Next to him. The ", g.Item("Aqual Quintessence", 17333), " is inside.")
	end)
end)
