-- An example guide in ObviGuide's own form (not loaded by the game; see FORMAT.md).
ObviGuide.Guide(function(g)
	g.title = "9-13 Skyborne"
	g.group = "My guides"
	g.next  = "13-15 Lowlands"
	g.only  = "Alliance"

	g:Step(function(s)
		s.label = "Deliver the News"
		s:Goto(2521, 47.51, 78.44)
		s:Talk(g.Npc("Aamelia Windfield", 252800))
		s:Turnin(92693, "Standing Our Ground")
		s:Accept(92703, "Deliver the News"):Only("Alliance")
		s:Note("Turn it in right away; ", g.Npc("Aamelia Windfield", 252800), " soon walks back.")
	end)

	g:Side("next", function(s)
		s.only = "Alliance"
		s:Kill(g.Mob("Skyhopper", 251314), { quest = 93949, objective = 1 })
	end)
end)
