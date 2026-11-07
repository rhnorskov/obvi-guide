-- Ragefire Chasm (Horde, 9-16): the quests Attune lists: Rahauro's two from Thunder Bluff (with Returning the Lost
-- Satchel from inside), The Power to Destroy... from the Undercity, Thrall's Hidden Enemies chain and Slaying the
-- Beast from Neeru Fireblade. Quest, NPC and item ids and positions from Attune (CixiDelmont) and QuestieDB's Forever
-- data; the entrance and where Maur Grimtotem lies from DungeonJournal (Exehn). Thunder Bluff, then Orgrimmar and a
-- zeppelin hop to the Undercity, the Burning Blade at Skull Rock by the zeppelin tower, Orgrimmar again, the chasm,
-- and the turn-ins in the same cities the other way round.

local THUNDER_BLUFF, ORGRIMMAR, UNDERCITY, DUROTAR = 1456, 1454, 1458, 1411

ObviGuide.Guide(function(g)
	g.title = "Ragefire Chasm: Quests"
	g.group = "Dungeons"
	g.id    = "obvi-ragefire-chasm-horde"
	g.next  = "obvi-ruins-of-lordaeron-horde"
	g.only  = "Horde"

	local rahauro = g.Npc("Rahauro", 11833)
	local thrall  = g.Npc("Thrall", 4949)
	local neeru   = g.Npc("Neeru Fireblade", 3216)
	local vari    = g.Npc("Varimathras", 2425)

	-- Thunder Bluff: Elder Rise
	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 70.1, 29.5)
		s:Talk(rahauro)
		s:Accept(5722, "Searching for the Lost Satchel")
		s:Accept(5723, "Testing an Enemy's Strength")
		s:Note("On Elder Rise; he walks around a little.")
	end)

	-- Orgrimmar: Thrall, then the zeppelin to the Undercity and back
	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Accept(5726, "Hidden Enemies")
		s:Note("In Grommash Hold, in the Valley of Wisdom. Fly from Thunder Bluff.")
	end)

	g:Step(function(s)
		s:Goto(UNDERCITY, 56.3, 92.2)
		s:Talk(vari)
		s:Accept(5725, "The Power to Destroy...")
		s:Note("Take the Undercity zeppelin from the tower just outside Orgrimmar's front gate. He stands in the Royal Quarter.")
	end)

	-- Skull Rock lies right next to the zeppelin tower
	g:Step(function(s)
		s:Goto(DUROTAR, 53.8, 9.0)
		s:Kill(g.Mob("Burning Blade Fanatic", 3197))
		s:Kill(g.Mob("Burning Blade Apprentice", 3198))
		s:Collect(g.Item("Lieutenant's Insignia", 14544), { quest = 5726, objective = 1 })
		s:Note("Take the zeppelin back. In the caves of Skull Rock, east of the tower.")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Turnin(5726, "Hidden Enemies")
		s:Accept(5727, "Hidden Enemies")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 49.5, 50.6)
		s:Talk(neeru)
		s:Quest(5727, 1, "Show ", neeru, " the insignia and speak to him frankly.")
		s:Accept(5761, "Slaying the Beast")
		s:Note("In the Cleft of Shadow.")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Turnin(5727, "Hidden Enemies")
		s:Accept(5728, "Hidden Enemies")
	end)

	g:Step(function(s)
		s.skip = "ready 5728 or done 5728 or ready 5761 or done 5761"   -- (been inside already)
		s:Goto(ORGRIMMAR, 52.6, 49.0)
		s:Do("Enter Ragefire Chasm with your group.")
		s:Note("The entrance is in the Cleft of Shadow.")
	end)

	-- inside, the whole way through
	g:Side("out", function(s)
		s:Kill(g.Mob("Ragefire Trogg", 11318), { quest = 5723, objective = 1 })
		s:Kill(g.Mob("Ragefire Shaman", 11319), { quest = 5723, objective = 2 })
		s:Note("Throughout the chasm.")
	end)

	g:Side("out", function(s)
		s:Kill(g.Mob("Searing Blade Cultist", 11322))
		s:Kill(g.Mob("Searing Blade Warlock", 11324))
		s:Collect(g.Item("Spells of Shadow", 14395), { quest = 5725, objective = 1 })
		s:Collect(g.Item("Incantations from the Nether", 14396), { quest = 5725, objective = 2 })
		s:Note("Only the Searing Blade Cultists and Warlocks drop the books.")
	end)

	g:Step(function(s)
		s:Talk(g.Npc("Maur Grimtotem", 11834))
		s:Turnin(5722, "Searching for the Lost Satchel")
		s:Accept(5724, "Returning the Lost Satchel")
		s:Note("His body lies up the ramp in the room off the first right turn on the long way down.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Taragaman the Hungerer", 11520))
		s:Collect(g.Item("Taragaman the Hungerer's Heart", 14540), { quest = 5761, objective = 1 })
		s:Note("The second boss.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Jergosh the Invoker", 11518), { quest = 5728, objective = 2 })
		s:Note("The third boss.")
	end)

	g:Step(function(s)
		s:Kill(g.Mob("Bazzalan", 11519), { quest = 5728, objective = 1 })
		s:Note("The last boss.")
	end)

	-- out: Neeru is right by the entrance, then up to Thrall and back
	g:Step(function(s)
		s.label = "out"
		s:Goto(ORGRIMMAR, 49.5, 50.6)
		s:Talk(neeru)
		s:Turnin(5761, "Slaying the Beast")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Turnin(5728, "Hidden Enemies")
		s:Accept(5729, "Hidden Enemies")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 49.5, 50.6)
		s:Talk(neeru)
		s:Turnin(5729, "Hidden Enemies")
		s:Accept(5730, "Hidden Enemies")
	end)

	g:Step(function(s)
		s:Goto(ORGRIMMAR, 31.7, 37.8)
		s:Talk(thrall)
		s:Turnin(5730, "Hidden Enemies")
	end)

	-- the Undercity, then Thunder Bluff
	g:Step(function(s)
		s:Goto(UNDERCITY, 56.3, 92.2)
		s:Talk(vari)
		s:Turnin(5725, "The Power to Destroy...")
		s:Note("By zeppelin again.")
	end)

	g:Step(function(s)
		s:Goto(THUNDER_BLUFF, 70.1, 29.5)
		s:Talk(rahauro)
		s:Turnin(5724, "Returning the Lost Satchel")
		s:Turnin(5723, "Testing an Enemy's Strength")
		s:Note("Zeppelin back to Orgrimmar and fly to Thunder Bluff.")
	end)
end)
