-- Engine: follows one guide for this character. It decides which goals are visible and done from the game's state,
-- moves on to the next step that applies, and remembers manual ticks and reached waypoints.
--
-- A goal is visible when its condition holds; goals tied to a quest objective also need the quest in the log.
-- A step applies when its condition holds and it has at least one visible goal that can complete; it is done when
-- all of those are complete. Text and "talk to" lines only describe.
local _, ns = ...
---@cast ns ObviGuideNS

local Conditions = ns.Conditions

---@class ObviGuideEngine
local Engine = {}
ns.Engine = Engine

local guide ---@type ObviGuideGuide?
local index = 1

local COMPLETABLE = { accept = true, turnin = true, objective = true, kill = true, collect = true, equip = true,
	cast = true, learn = true, level = true, home = true, hearth = true, ["goto"] = true, confirm = true }

-- manual ticks and reached waypoints: charDB.marks[guide title]["step:goal"] = true
local function Marks()
	if not (guide and ns.charDB) then return {} end
	ns.charDB.marks = ns.charDB.marks or {}
	ns.charDB.marks[guide.title] = ns.charDB.marks[guide.title] or {}
	return ns.charDB.marks[guide.title]
end
local function MarkKey(step, goal)
	for i, g in ipairs(step.goals) do if g == goal then return step.index .. ":" .. i end end
	for i, g in ipairs(step.side) do if g == goal then return step.index .. ":s" .. i end end
end

local function Objective(goal)
	local objs = goal.quest and C_QuestLog.GetQuestObjectives(goal.quest)
	return objs and objs[goal.objective or 1]
end

--- Yards between the player and a point, or nil when they are not on the same continent.
---@param p ObviGuidePoint
local function Distance(p)
	local here = C_Map.GetBestMapForUnit("player")
	if not here then return nil end
	local pos = C_Map.GetPlayerMapPosition(here, "player")
	if not pos then return nil end
	local c1, w1 = C_Map.GetWorldPosFromMapPos(here, pos)
	local c2, w2 = C_Map.GetWorldPosFromMapPos(p.map, CreateVector2D(p.x, p.y))
	if not (w1 and w2) or c1 ~= c2 then return nil end
	local dx, dy = w1.x - w2.x, w1.y - w2.y
	return math.sqrt(dx * dx + dy * dy)
end

---@param goal ObviGuideGoal
---@return boolean
function Engine.IsVisible(goal)
	if not Conditions.Eval(goal.cond) then return false end
	if goal.quest and (goal.kind == "objective" or goal.kind == "kill" or (goal.kind == "collect" and goal.objective)) then
		-- hidden for a quest you haven't got; one already turned in still counts (as done), so its step is a step
		-- you can go back to rather than one that "doesn't apply"
		return C_QuestLog.IsOnQuest(goal.quest) or C_QuestLog.IsQuestFlaggedCompleted(goal.quest)
	end
	if goal.kind == "turnin" then
		return C_QuestLog.IsOnQuest(goal.quest) or C_QuestLog.IsQuestFlaggedCompleted(goal.quest)
	end
	return true
end

---@param goal ObviGuideGoal
---@param step ObviGuideStep
---@return boolean
function Engine.IsComplete(goal, step)
	if goal.done and Conditions.Eval(goal.done) then return true end
	local k = goal.kind
	if k == "accept" then return C_QuestLog.IsOnQuest(goal.quest) or C_QuestLog.IsQuestFlaggedCompleted(goal.quest) end
	if k == "turnin" then return C_QuestLog.IsQuestFlaggedCompleted(goal.quest) end
	if k == "objective" or k == "kill" or (k == "collect" and goal.objective) then
		if C_QuestLog.IsQuestFlaggedCompleted(goal.quest) or C_QuestLog.ReadyForTurnIn(goal.quest) then return true end
		local o = Objective(goal)
		return o and o.finished or false
	end
	if k == "collect" then return C_Item.GetItemCount(goal.id) >= (goal.count or 1) end
	if k == "equip" then return goal.id and C_Item.IsEquippedItem(goal.id) or false end
	if k == "learn" then return C_SpellBook.IsSpellKnown(goal.id) end
	if k == "cast" then
		-- complete once the spell is on a real cooldown (over 2 s, so another spell's global cooldown doesn't count)
		local cd = C_Spell.GetSpellCooldown(goal.id)
		return cd ~= nil and (cd.duration or 0) > 2
	end
	if k == "level" then
		local lvl = UnitLevel("player")
		return lvl > goal.level or (lvl == goal.level and UnitXP("player") >= (goal.xp or 0))
	end
	if k == "home" then
		local place = goal.text:match("to (.+)$")
		return place ~= nil and (GetBindLocation() or "") == place:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	end
	if k == "goto" or k == "confirm" or k == "hearth" then
		local key = MarkKey(step, goal)
		return key ~= nil and Marks()[key] == true
	end
	return false
end

--- "3/8" for goals with a count, or nil.
---@param goal ObviGuideGoal
---@return string?
function Engine.Progress(goal)
	if goal.kind == "objective" or goal.kind == "kill" or (goal.kind == "collect" and goal.objective) then
		local o = Objective(goal)
		if o and (o.numRequired or 0) > 1 then return o.numFulfilled .. "/" .. o.numRequired end
	elseif goal.kind == "collect" and (goal.count or 1) > 1 then
		return math.min(C_Item.GetItemCount(goal.id), goal.count) .. "/" .. goal.count
	end
end

---@param step ObviGuideStep
---@return boolean applies, boolean done
function Engine.StepState(step)
	if not Conditions.Eval(step.cond) then return false, false end
	if step.skip and Conditions.Eval(step.skip) then return true, true end
	local any, done = false, true
	-- alternatives (orGroup): how many more each group needs; once a group has enough, every alternative counts as
	-- done (as Zygor has it)
	local need, orOpen = {}, false
	for _, g in ipairs(step.goals) do
		if COMPLETABLE[g.kind] and Engine.IsVisible(g) then
			any = true
			local complete = Engine.IsComplete(g, step)
			if complete and g.finishes then return true, true end
			if g.orGroup then
				need[g.orGroup] = (need[g.orGroup] or g.orCount or 1) - (complete and 1 or 0)
				if not complete then orOpen = true end
			elseif not complete then
				done = false
			end
		end
	end
	if orOpen then
		local met = false
		for _, n in pairs(need) do if n < 1 then met = true end end
		if not met then done = false end
	end
	return any, any and done
end

--- Where a step that is done (or has nothing left to do) goes on: the first open jump, or nil for the next step.
---@param step ObviGuideStep
---@return integer?
function Engine.JumpOf(step)
	for _, j in ipairs(step.jumps or {}) do
		local g = j.goal
		if Conditions.Eval(j.cond)
			and (not g or (Engine.IsVisible(g) and (not COMPLETABLE[g.kind] or Engine.IsComplete(g, step)))) then
			return j.to
		end
	end
end

-- the guide is finished: the window shows its end (and the next guide to continue with) instead of a step
local ended = false

--- The guide, and its current step (none once the guide has ended).
---@return ObviGuideGuide?, ObviGuideStep?
function Engine.Current()
	return guide, guide and not ended and guide.steps[index] or nil
end

local function Changed()
	-- by name where the guide has one: titles may repeat across groups (Zygor's are the last part of its path)
	if ns.charDB and guide then ns.charDB.guide, ns.charDB.step = guide.name or guide.title, index end
	local _, step = Engine.Current()
	ns.Travel.Show(step)
	ns:Fire("OBVIGUIDE_STEP")
end

-- Going back pauses auto-advance, as Zygor does: it stays paused until the step you're on is not done (from then
-- on finishing it moves on as usual), so a finished step you went back to stays put.
local paused = false

--- Whether the guide is finished, and the title of the guide that follows it (when we have it).
---@return boolean ended, string? nextTitle
function Engine.Ended()
	local nxt = ended and guide and guide.next and ns.FindGuide(guide.next)
	return ended, nxt and nxt.title or nil
end

--- Moves forward past steps that don't apply or are done. A step meant for this character that is done (or has
--- nothing left to do) may jump elsewhere instead (Zygor's "|next"); the step it lands on starts afresh, without the
--- ticks of an earlier visit, as Zygor has it (so a menu step you come back to asks again).
function Engine.Advance()
	if not guide or ended then return end
	if paused then
		local applies, done = Engine.StepState(guide.steps[index])
		if applies and not done then paused = false end
		return
	end
	local start = index
	local landed = {}   -- each jump target once, so two done steps can't send us round in circles
	while index <= #guide.steps do
		local step = guide.steps[index]
		local applies, done = Engine.StepState(step)
		if applies and not done then break end
		local to = step.jumps and Conditions.Eval(step.cond) and Engine.JumpOf(step)
		if to and guide.steps[to] and not landed[to] then
			landed[to] = true
			index = to
			local marks, prefix = Marks(), to .. ":"
			for key in pairs(marks) do if key:sub(1, #prefix) == prefix then marks[key] = nil end end
		else
			index = index + 1
		end
	end
	if index > #guide.steps then
		-- the guide is finished: its end is shown, with the next guide to continue with (not loaded on its own, so
		-- the player sees the guide ended rather than another one starting)
		index = #guide.steps
		ended = true
		Changed()
		return
	end
	if index ~= start then Changed() end
end

--- From a finished guide on to the one that follows it (the end's button, or the next arrow).
function Engine.Continue()
	local _, nextTitle = Engine.Ended()
	if nextTitle then Engine.Load(nextTitle, 1) end
end

---@param title string
---@param step? integer
function Engine.Load(title, step)
	local g = ns.FindGuide(title)
	if not g then ns.Print("no guide called '%s'", title) return end
	guide, index = g, math.max(1, math.min(step or 1, #g.steps))
	paused, ended = false, false
	Changed()
	Engine.Advance()
end

--- One step by hand (the window's arrows, the keybinds): the next or previous step meant for this character (its
--- condition holds), done or not. It pauses auto-advance (see Advance), so a finished step stays put; finishing an
--- unfinished one moves on as usual.
---@param dir integer  1 or -1
function Engine.Step(dir)
	if not guide then return end
	-- at the guide's end: back shows its last step again, next goes on to the following guide
	if ended then
		if dir > 0 then Engine.Continue() return end
		ended, paused = false, true
		Changed()
		return
	end
	local i = index + dir
	while guide.steps[i] do
		-- (a step with no lines only jumps elsewhere)
		if Conditions.Eval(guide.steps[i].cond) and #guide.steps[i].goals > 0 then
			index = i
			paused = true
			Changed()
			return
		end
		i = i + dir
	end
	-- next past the last step: the guide's end
	if dir > 0 then ended = true Changed() end
end

--- Fast forward or back (right-click on the arrows, as in Zygor): forward to the next unfinished step, back to the
--- nearest earlier unfinished one (or the first step).
---@param dir integer  1 or -1
function Engine.Jump(dir)
	if not guide then return end
	if ended then Engine.Step(dir) return end
	if dir > 0 then
		paused = false
		local start = index
		index = math.min(index + 1, #guide.steps)
		Engine.Advance()
		if index ~= start then Changed() end
		return
	end
	local target
	for i = index - 1, 1, -1 do
		local applies, done = Engine.StepState(guide.steps[i])
		if applies and not done then target = i break end
	end
	if not target then
		for i = 1, index - 1 do
			if Conditions.Eval(guide.steps[i].cond) and #guide.steps[i].goals > 0 then target = i break end
		end
	end
	if not target then return end
	index = target
	paused = true
	Changed()
end

--- Ticks off a 'confirm' goal (or any goal the window lets the player click).
---@param goal ObviGuideGoal
function Engine.Tick(goal)
	local _, step = Engine.Current()
	local key = step and MarkKey(step, goal)
	if key then Marks()[key] = not Marks()[key] end
	Engine.Update()
end

function Engine.Update()
	Engine.Advance()
	ns:Fire("OBVIGUIDE_UPDATE")
end

-- reached waypoints of 'goto' goals are marked as the player arrives
local function CheckArrival()
	local _, step = Engine.Current()
	if not step then return end
	for _, g in ipairs(step.goals) do
		if g.kind == "goto" and g.point and Engine.IsVisible(g) and not Engine.IsComplete(g, step) then
			local d = Distance(g.point)
			if d and d <= (g.point.radius or 10) then
				Marks()[MarkKey(step, g)] = true
				Engine.Update()
				return
			end
		end
	end
end

for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP",
	"PLAYER_XP_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN",
	"HEARTHSTONE_BOUND", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do
	ns:On(event, function() Engine.Update() end)
end

-- a hearth goal is done once the player casts a hearth (the Hearthstone's spell, or Astral Recall; as RestedXP checks)
local HEARTH_SPELLS = { [8690] = true, [556] = true }
ns:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
	if unit ~= "player" or not HEARTH_SPELLS[spellID] then return end
	local _, step = Engine.Current()
	if not step then return end
	for _, g in ipairs(step.goals) do
		if g.kind == "hearth" and Engine.IsVisible(g) then Marks()[MarkKey(step, g)] = true end
	end
	Engine.Update()
end)

-- the guide this character followed is picked up again once in the world, or when its pack adds it later (a pack
-- that hands over guides only after another addon has loaded its own)
local inWorld = false
local function Restore()
	if guide or not inWorld then return end
	local saved = ns.charDB and ns.charDB.guide
	if saved and ns.FindGuide(saved) then Engine.Load(saved, ns.charDB.step) end
end
ns:On("PLAYER_ENTERING_WORLD", function() inWorld = true Restore() end)
ns:On("OBVIGUIDE_GUIDES_ADDED", Restore)

C_Timer.NewTicker(0.5, CheckArrival)
