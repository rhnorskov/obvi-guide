-- Engine: follows one guide for this character. It decides which goals are visible and done from the game's state,
-- moves on to the next step that applies, and remembers manual ticks and reached waypoints.
--
-- A goal is visible when its condition holds; goals tied to a quest objective also need the quest in the log.
-- A step applies when its condition holds and it has at least one visible goal that can complete; it is done when
-- all of those are complete. Text and "talk to" lines only describe.
local _, ns = ...
---@cast ns AnyGuideNS

local Conditions = ns.Conditions

---@class AnyGuideEngine
local Engine = {}
ns.Engine = Engine

local guide ---@type AnyGuideGuide?
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
---@param p AnyGuidePoint
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

---@param goal AnyGuideGoal
---@return boolean
function Engine.IsVisible(goal)
	if not Conditions.Eval(goal.cond) then return false end
	if goal.quest and (goal.kind == "objective" or goal.kind == "kill" or (goal.kind == "collect" and goal.objective)) then
		return C_QuestLog.IsOnQuest(goal.quest)
	end
	if goal.kind == "turnin" then
		return C_QuestLog.IsOnQuest(goal.quest) or C_QuestLog.IsQuestFlaggedCompleted(goal.quest)
	end
	return true
end

---@param goal AnyGuideGoal
---@param step AnyGuideStep
---@return boolean
function Engine.IsComplete(goal, step)
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
---@param goal AnyGuideGoal
---@return string?
function Engine.Progress(goal)
	if goal.kind == "objective" or goal.kind == "kill" or (goal.kind == "collect" and goal.objective) then
		local o = Objective(goal)
		if o and (o.numRequired or 0) > 1 then return o.numFulfilled .. "/" .. o.numRequired end
	elseif goal.kind == "collect" and (goal.count or 1) > 1 then
		return math.min(C_Item.GetItemCount(goal.id), goal.count) .. "/" .. goal.count
	end
end

---@param step AnyGuideStep
---@return boolean applies, boolean done
function Engine.StepState(step)
	if not Conditions.Eval(step.cond) then return false, false end
	if step.skip and Conditions.Eval(step.skip) then return true, true end
	local any, done = false, true
	for _, g in ipairs(step.goals) do
		if COMPLETABLE[g.kind] and Engine.IsVisible(g) then
			any = true
			if not Engine.IsComplete(g, step) then done = false end
		end
	end
	return any, any and done
end

---@return AnyGuideGuide?, AnyGuideStep?
function Engine.Current()
	return guide, guide and guide.steps[index]
end

local function Changed()
	if ns.charDB and guide then ns.charDB.guide, ns.charDB.step = guide.title, index end
	local _, step = Engine.Current()
	ns.Travel.Show(step)
	ns:Fire("ANYGUIDE_STEP")
end

--- Moves forward past steps that don't apply or are done.
function Engine.Advance()
	if not guide then return end
	local start = index
	while index <= #guide.steps do
		local applies, done = Engine.StepState(guide.steps[index])
		if applies and not done then break end
		index = index + 1
	end
	if index > #guide.steps then
		index = #guide.steps
		-- the guide is finished: continue with its next guide, if we have it
		local _, done = Engine.StepState(guide.steps[index])
		if done and guide.next and ns.FindGuide(guide.next) then
			ns.Print("finished %s, continuing with %s", guide.title, guide.next)
			Engine.Load(guide.next, 1)
			return
		end
	end
	if index ~= start then Changed() end
end

---@param title string
---@param step? integer
function Engine.Load(title, step)
	local g = ns.FindGuide(title)
	if not g then ns.Print("no guide called '%s'", title) return end
	guide, index = g, math.max(1, math.min(step or 1, #g.steps))
	Changed()
	Engine.Advance()
end

--- Steps the player moves to by hand (the window's arrows): only steps that apply to this character.
---@param dir integer  1 or -1
function Engine.Step(dir)
	if not guide then return end
	local i = index + dir
	while guide.steps[i] do
		if (Engine.StepState(guide.steps[i])) then index = i Changed() return end
		i = i + dir
	end
end

--- Ticks off a 'confirm' goal (or any goal the window lets the player click).
---@param goal AnyGuideGoal
function Engine.Tick(goal)
	local _, step = Engine.Current()
	local key = step and MarkKey(step, goal)
	if key then Marks()[key] = not Marks()[key] end
	Engine.Update()
end

function Engine.Update()
	Engine.Advance()
	ns:Fire("ANYGUIDE_UPDATE")
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

ns:On("PLAYER_ENTERING_WORLD", function()
	if guide then return end
	local saved = ns.charDB and ns.charDB.guide
	if saved and ns.FindGuide(saved) then Engine.Load(saved, ns.charDB.step) end
end)

C_Timer.NewTicker(0.5, CheckArrival)
