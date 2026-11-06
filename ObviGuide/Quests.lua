-- Auto accept and turn in (two options on the Settings page, on by default): only the quests the current step accepts
-- or turns in. Other quests are left alone, and so is a choice of rewards. Holding Shift while talking to an NPC
-- leaves that conversation alone.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine
local Conditions = ns.Conditions
-- the greeting's pickers take the quest's index (the annotations say they take nothing)
local SelectActiveByIndex = _G["SelectActiveQuest"] ---@type fun(index: integer)
local SelectAvailableByIndex = _G["SelectAvailableQuest"] ---@type fun(index: integer)

--- The quests the current step accepts and turns in (its lines and side tasks meant for this character). A step that
--- has just been finished stays shown a moment before the guide moves on, while the NPC may already offer the next
--- quest: then the step after it counts too.
---@return table<integer, boolean> accepts, table<integer, boolean> turnins
local function StepQuests()
	local accepts, turnins = {}, {}
	local guide, step = Engine.Current()
	if not (guide and step) then return accepts, turnins end
	local function add(s)
		if not Conditions.Eval(s.cond) then return end
		for _, list in ipairs({ s.goals, s.side }) do
			for _, g in ipairs(list) do
				if g.quest and Conditions.Eval(g.cond) then
					if g.kind == "accept" then accepts[g.quest] = true end
					if g.kind == "turnin" then turnins[g.quest] = true end
				end
			end
		end
	end
	add(step)
	local _, done = Engine.StepState(step)
	if done then
		for i = step.index + 1, #guide.steps do
			local applies, nextDone = Engine.StepState(guide.steps[i])
			if applies and not nextDone then add(guide.steps[i]) break end
		end
	end
	return accepts, turnins
end

-- on unless turned off in Settings (nil: never changed, so the default, on)
local function On(option) return ns.db ~= nil and ns.db[option] ~= false and not IsShiftKeyDown() end

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
