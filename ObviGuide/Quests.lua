-- Auto accept and turn in (two options on the Settings page, on by default), as Zygor does it: only the quests the
-- step you're on still has to accept or turn in (its shown lines that aren't done yet, side tasks too). Other quests
-- are left alone, and so is a choice of rewards. Holding Shift while talking to an NPC leaves that conversation alone,
-- and so does declining a quest, for a few seconds (the NPC offering it again doesn't take it after all).
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine
local Conditions = ns.Conditions
-- the greeting's pickers take the quest's index (the annotations say they take nothing)
local SelectActiveByIndex = _G["SelectActiveQuest"] ---@type fun(index: integer)
local SelectAvailableByIndex = _G["SelectAvailableQuest"] ---@type fun(index: integer)

--- The quests the steps you're on still have to accept and turn in (the step of each guide window): their lines (and
--- side tasks) that are shown and not done yet. A step that is done, still shown a moment before the guide moves on,
--- gives way to the next one that isn't (the NPC may already offer its quest); no step further ahead counts.
---@return table<integer, boolean> accepts, table<integer, boolean> turnins
local function StepQuests()
	local accepts, turnins = {}, {}
	for _, at in ipairs(Engine.Following()) do
		local guide, step = at.guide, at.step
		local applies, done = false, false
		if step then applies, done = Engine.StepState(step) end
		if step and (not applies or done) then
			local from = step.index
			step = nil
			for i = from + 1, #guide.steps do
				local a, d = Engine.StepState(guide.steps[i])
				if a and not d then step = guide.steps[i] break end
			end
		end
		for _, list in ipairs(step and { step.goals, step.side } or {}) do
			---@cast step ObviGuideStep
			for _, g in ipairs(list) do
				if g.quest and Engine.IsVisible(g) and not Engine.IsComplete(g, step) then
					if g.kind == "accept" then accepts[g.quest] = true end
					if g.kind == "turnin" then turnins[g.quest] = true end
				end
			end
		end
	end
	return accepts, turnins
end

-- declining a quest leaves the next few seconds alone (as Zygor does): the NPC offering it again doesn't take it
local declined = 0
hooksecurefunc("DeclineQuest", function() declined = GetTime() end)

-- on unless turned off in Settings (nil: never changed, so the default, on)
local function On(option)
	return ns.db ~= nil and ns.db[option] ~= false and not IsShiftKeyDown() and GetTime() - declined > 10
end

-- the NPC's chat window: open the step's quest (one per show; the window comes back after it)
local function Gossip()
	local accept, turnin = On("autoAccept"), On("autoTurnin")
	if not (accept or turnin) then return end
	local accepts, turnins = StepQuests()
	if turnin then
		for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
			if q.isComplete and turnins[q.questID] then C_GossipInfo.SelectActiveQuest(q.questID) return end
		end
	end
	if accept then
		for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
			if accepts[q.questID] then C_GossipInfo.SelectAvailableQuest(q.questID) return end
		end
	end
end

-- the older quest greeting (an NPC with only quests, no chat options)
local function Greeting()
	local accept, turnin = On("autoAccept"), On("autoTurnin")
	if not (accept or turnin) then return end
	local accepts, turnins = StepQuests()
	if turnin then
		for i = 1, GetNumActiveQuests() do
			local id = GetActiveQuestID(i)
			if id and turnins[id] and C_QuestLog.ReadyForTurnIn(id) then SelectActiveByIndex(i) return end
		end
	end
	if accept then
		for i = 1, GetNumAvailableQuests() do
			local id = select(5, GetAvailableQuestInfo(i))
			if id and accepts[id] then SelectAvailableByIndex(i) return end
		end
	end
end

ns:On("GOSSIP_SHOW", Gossip)
ns:On("QUEST_GREETING", Greeting)

-- the quest's own window: accept it, hand it in, take the reward when there's no choice to make
ns:On("QUEST_DETAIL", function()
	if not On("autoAccept") then return end
	local accepts = StepQuests()
	if accepts[GetQuestID()] then AcceptQuest() end
end)
ns:On("QUEST_PROGRESS", function()
	if not On("autoTurnin") then return end
	local _, turnins = StepQuests()
	if turnins[GetQuestID()] and IsQuestCompletable() then CompleteQuest() end
end)
ns:On("QUEST_COMPLETE", function()
	if not On("autoTurnin") then return end
	local _, turnins = StepQuests()
	local choices = GetNumQuestChoices()
	-- as the quest frame does: choice 0 when there are no rewards to choose from, 1 when there is just one
	if turnins[GetQuestID()] and choices <= 1 then GetQuestReward(choices == 1 and 1 or 0) end
end)
