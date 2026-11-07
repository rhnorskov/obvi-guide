-- Shadowforge Key (both factions, 48+): the key to the Shadowforge City gate in Blackrock Depths, from Dark Iron
-- Legacy: Franclorn Forgewright's ghost in Blackrock Mountain, Fineous Darkvire's hammer Ironfel, and the Shrine of
-- Thaurissan. Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever data; the
-- Blackrock Depths entrance from DungeonJournal (Exehn). See README.md.

local SEARING_GORGE, BURNING_STEPPES = 1427, 1428

ObviGuide.Guide(function(g)
	g.title = "Shadowforge Key"
	g.group = "Dungeon keys"
	g.id    = "obvi-key-shadowforge"

	local franclorn = g.Npc("Franclorn Forgewright", 8888)
	local ironfel   = g.Item("Ironfel", 10999)

	-- Franclorn is a ghost: only the dead can see him
	g:Step(function(s)
		s:Goto(BURNING_STEPPES, 29.0, 28.9)
		s:Talk(franclorn)
		s:Accept(3801, "Dark Iron Legacy")
		s:Turnin(3801, "Dark Iron Legacy")
		s:Accept(3802, "Dark Iron Legacy")
		s:Note("On top of his tomb in the middle of Blackrock Mountain. He is a ghost and only shows himself to ghosts: die in the mountain, release, and run back to him before you go back to your body.")
	end)

	g:Step(function(s)
		s.skip = "items 10999 >= 1 or done 3802"   -- (been inside already)
		s:Goto(SEARING_GORGE, 34.8, 84.0)
		s:Do("Enter Blackrock Depths with your group.")
		s:Note("Take the chain down from the Blackrock Spire ledge and follow the lower path to the portal.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Fineous Darkvire", 9056))
		s:Collect(ironfel, { quest = 3802, objective = 1 })
		s:Note("In the Hall of Crafting.")
	end)

	g:Step(function(s)
		s:Say("Place ", ironfel, " on the ", g.Object("Monument of Franclorn Forgewright"), ".")
		s:Turnin(3802, "Dark Iron Legacy")
		s:Note("Back across the bridge in Shadowforge City, at the far end of the Shrine of Thaurissan. The Shadowforge Key is the reward; only one person in the group needs it.")
	end)
end)
