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
	cast = true, learn = true, level = true, home = true, hearth = true, ["goto"] = true, confirm = true, skill = true }

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

-- Flight paths, as Zygor's LibTaxi does it: the game lists a continent's flight points with whether each is still
-- undiscovered (C_TaxiMap.GetTaxiNodesForMap, slow, so a map is read once and kept), and it's read again when a
-- new flight path is learned or a flight map opens. On WoW Forever that list calls every flight point discovered
-- (seen: Lakeshire, not yet flown to, "undiscovered false" on Redridge's, Eastern Kingdoms' and Azeroth's maps), so a
-- list is believed only when it marks at least one flight point undiscovered. Otherwise the flight points this
-- character was seen to know count: the ones a flight master's map offered (charDB.flights), and the ones learned.
local discovered = {} ---@type table<integer, {names: table<string, boolean>, trusted: boolean}>

--- "Tokka's Landing, Zul'Aman" -> "tokka's landing" (as Zygor trims them)
---@param name string
local function FlightName(name) return (name:gsub(", .*", "")):lower() end

--- The flight points a map's flight map lists (read once, kept until a flight path is learned): name -> discovered,
--- and whether the list can be believed (it marks some flight point undiscovered).
---@param map integer
local function Discovered(map)
	local list = discovered[map]
	if list then return list end
	list = { names = {}, trusted = false }
	local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, map)
	for _, node in ipairs(ok and nodes or {}) do
		if node.name then
			local name = FlightName(node.name)
			list.names[name] = (list.names[name] or false) or not node.isUndiscovered
			if node.isUndiscovered then list.trusted = true end
		end
	end
	discovered[map] = list
	return list
end

-- the flight point each race starts out knowing (as Zygor's InitialFlightPaths has them)
local HOME_FLIGHT = { Human = "stormwind", Dwarf = "ironforge", Gnome = "ironforge", NightElf = "rut'theran village",
	Orc = "orgrimmar", Troll = "orgrimmar", Scourge = "undercity", Tauren = "thunder bluff" }

--- The flight points this character was seen to know (and its race's home one).
---@return table<string, boolean>
local function Seen()
	if not ns.charDB then return {} end
	ns.charDB.flights = ns.charDB.flights or {}
	local home = HOME_FLIGHT[select(2, UnitRace("player")) or ""]
	if home then ns.charDB.flights[home] = true end
	return ns.charDB.flights
end

--- Whether a "get the flight path" line's flight point is discovered (by name). The flight points are asked for on
--- the line's (or step's) map and every map above it, as some zones (underground ones) hang off the tree oddly and
--- their continent's flight map doesn't list them; a believable list that has it decides (one listing it
--- undiscovered wins). Without one, the flight points seen known decide.
---@param goal ObviGuideGoal
---@param step ObviGuideStep
---@return boolean
local function FlightKnown(goal, step)
	if not goal.flight then return false end
	local want = FlightName(goal.flight)
	-- either name may be the longer one: the guide's "Stormwind City" is the game's "Stormwind, Elwynn" (trimmed: "stormwind")
	local function Match(name) return name:find(want, 1, true) ~= nil or want:find(name, 1, true) ~= nil end
	local map = (goal.point and goal.point.map) or (step.dest and step.dest.map)
	if map and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
		local info, seen, known = C_Map.GetMapInfo(map), 0, nil
		while info and seen < 8 do
			local list = Discovered(info.mapID)
			if list.trusted then
				for name, found in pairs(list.names) do
					if Match(name) then
						if not found then return false end
						known = true
					end
				end
			end
			if (info.parentMapID or 0) == 0 then break end
			info, seen = C_Map.GetMapInfo(info.parentMapID), seen + 1
		end
		if known then return true end
	end
	for name in pairs(Seen()) do if Match(name) then return true end end
	return false
end

-- an open flight map: the flight points it offers are known (on this client the map lists only those; where it lists
-- the rest too, they are unreachable)
local function RememberFlights()
	local seen = Seen()
	local mapID = _G["GetTaxiMapID"] and _G["GetTaxiMapID"]()
	local ok, nodes = false, nil
	if mapID and C_TaxiMap.GetAllTaxiNodes then ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID) end
	local unreachable = Enum.FlightPathState and Enum.FlightPathState.Unreachable
	for _, node in ipairs(ok and nodes or {}) do
		local state = (node --[[@as table]]).state
		if node.name and state ~= unreachable then seen[FlightName(node.name)] = true end
	end
	local count = _G["NumTaxiNodes"] and _G["NumTaxiNodes"]() or 0
	for i = 1, count do
		local kind, name = _G["TaxiNodeGetType"](i), _G["TaxiNodeName"](i)
		if name and (kind == "REACHABLE" or kind == "CURRENT") then seen[FlightName(name)] = true end
	end
end

ns:On("UI_INFO_MESSAGE", function(_, _, message)
	if message ~= _G["ERR_NEWTAXIPATH"] then return end
	wipe(discovered)
	-- learned just now: the current step's flight lines count as done, whatever the flight map lists, and their flight
	-- points are remembered as known (Zygor notes the flight master's node the same way)
	local _, step = Engine.Current()
	if step then
		for _, g in ipairs(step.goals) do
			local key = g.flight and MarkKey(step, g)
			if key then
				Marks()[key] = true
				Seen()[FlightName(g.flight)] = true
			end
		end
	end
	Engine.Update()
end)
ns:On("TAXIMAP_OPENED", function()
	wipe(discovered)
	RememberFlights()
	Engine.Update()
end)

--- Lower-case words only: "Arrive at |cff..Talonstrike Terrace|r (0/1)" -> "arrive at talonstrike terrace".
---@param s string?
local function Words(s)
	s = (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("%b()", "")
	return (s:lower():gsub("[%d/:%p]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

--- The quest objective a line counts. Guides number objectives as the game did when they were written; when the
--- numbered one's text doesn't mention the line's words but exactly one other objective does, that one is meant
--- (the game numbers some quests' objectives differently, e.g. on retail).
local function Objective(goal)
	local objs = goal.quest and C_QuestLog.GetQuestObjectives(goal.quest)
	if not objs then return nil end
	local o = objs[goal.objective or 1]
	local want = Words(goal.text)
	if #want < 8 or (o and Words(o.text):find(want, 1, true)) then return o end
	local match
	for _, other in ipairs(objs) do
		if Words(other.text):find(want, 1, true) then
			if match then return o end   -- more than one: keep the guide's number
			match = other
		end
	end
	return match or o
end

--- Yards between the player and a point, or nil when they are not on the same continent.
---@param p ObviGuidePoint
local function Distance(p)
	local c1, w1 = ns.Travel.PlayerWorld()
	local c2, w2 = ns.Travel.World(p)
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
-- Quest chains whose quests share a title ("The Tome of Divinity" 1641, 1642, 1643...): a guide may start such a
-- chain at a quest the game no longer gives (on Forever this one starts at the Tome item, 1642), so a line for a quest
-- counts as done once a quest of the same title that comes later in the guide is in the log or done. Per guide: each
-- quest's later namesakes, worked out the first time it's asked.
local namesakes = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGuide, table<integer, integer[]>>

---@param text string?
local function QuestTitle(text)
	text = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return (text:gsub("^Accept%s+", ""):gsub("^Turn in%s+", ""):lower())
end

---@param quest integer
---@return boolean
local function LaterNamesakeTaken(quest)
	if not guide then return false end
	local later = namesakes[guide]
	if not later then
		later = {}
		local order = {} ---@type table<string, integer[]>   title -> its quests, in the order the guide has them
		for _, s in ipairs(guide.steps) do
			for _, g in ipairs(s.goals) do
				if (g.kind == "accept" or g.kind == "turnin") and g.quest then
					local list = order[QuestTitle(g.text)] or {}
					order[QuestTitle(g.text)] = list
					local seen = false
					for _, q in ipairs(list) do if q == g.quest then seen = true break end end
					if not seen then list[#list + 1] = g.quest end
				end
			end
		end
		for _, list in pairs(order) do
			for i, q in ipairs(list) do
				later[q] = {}
				for j = i + 1, #list do table.insert(later[q], list[j]) end
			end
		end
		namesakes[guide] = later
	end
	for _, q in ipairs(later[quest] or {}) do
		if C_QuestLog.IsOnQuest(q) or C_QuestLog.IsQuestFlaggedCompleted(q) then return true end
	end
	return false
end


---@param goal ObviGuideGoal
---@param step ObviGuideStep
---@return boolean
function Engine.IsComplete(goal, step)
	if goal.done and Conditions.Eval(goal.done) then return true end
	if goal.with then
		for _, w in ipairs(goal.with) do if not Engine.IsComplete(w, step) then return false end end
		return true
	end
	local k = goal.kind
	if k == "accept" then
		return C_QuestLog.IsOnQuest(goal.quest) or C_QuestLog.IsQuestFlaggedCompleted(goal.quest) or LaterNamesakeTaken(goal.quest)
	end
	if k == "turnin" then return C_QuestLog.IsQuestFlaggedCompleted(goal.quest) or LaterNamesakeTaken(goal.quest) end
	if k == "objective" or k == "kill" or (k == "collect" and goal.objective) then
		-- a quest ready to turn in counts all its objectives done, as Zygor does: on retail the objective list can
		-- still say 0/1 when the quest is complete (seen with "Arrive at Talonstrike Terrace")
		if C_QuestLog.IsQuestFlaggedCompleted(goal.quest) or C_QuestLog.ReadyForTurnIn(goal.quest) then return true end
		local o = Objective(goal)
		-- a line for part of the objective ("|count 3" in Zygor) is done once the objective has reached that many
		if o and goal.need then return (o.numFulfilled or 0) >= goal.need end
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
	if k == "skill" then
		-- a profession's skill reached, or (a rank trained) its cap raised to `cap`
		local rank, maxRank = Conditions.Skill(goal.skill)
		if goal.cap then return (maxRank or 0) >= goal.cap end
		return (rank or 0) >= (goal.level or 1)
	end
	if k == "level" then
		local lvl = UnitLevel("player")
		return lvl > goal.level or (lvl == goal.level and UnitXP("player") >= (goal.xp or 0))
	end
	if k == "home" then
		local place = goal.text:match("to (.+)$")
		return place ~= nil and (GetBindLocation() or "") == place:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	end
	if goal.flight and FlightKnown(goal, step) then return true end
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
	elseif goal.kind == "skill" and not goal.cap and (goal.level or 1) > 1 then
		return math.min(Conditions.Skill(goal.skill) or 0, goal.level) .. "/" .. goal.level
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

-- Open guides ("tabs", as Zygor has them; here switched in the window title's menu): several guides open at once (a
-- leveling guide, a dungeon, a profession), one of them shown.
-- Each tab keeps its guide (by name where the guide has one: titles may repeat across groups, Zygor's are the last part
-- of its path) and the step it was on: charDB.tabs, with charDB.tab the one shown. A tab with no guide yet is empty.
---@return ObviGuideTab[]
local function Tabs()
	local db = ns.charDB
	if not db then return {} end
	if not db.tabs then
		-- from before tabs: the one guide followed becomes the first tab
		db.tabs = { { guide = db.guide, step = db.step } }
		db.tab, db.guide, db.step = 1, nil, nil
	end
	if #db.tabs == 0 then db.tabs[1] = {} end
	db.tab = math.max(1, math.min(db.tab or 1, #db.tabs))
	return db.tabs
end

local function Changed()
	local tab = Tabs()[ns.charDB and ns.charDB.tab or 1]
	-- (a tab whose guide isn't here, its pack not loaded, keeps it)
	if tab and guide then tab.guide, tab.step = guide.name or guide.title, index end
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
-- Loading screens: while one shows, and for a moment after it, the quest log can be empty or half filled (seen
-- entering a follower dungeon: the steps for its quest looked as if they didn't apply and were passed over). No
-- moving on until the game has settled; then one check.
local SETTLE = 2
local settling = false
ns:On("LOADING_SCREEN_ENABLED", function() settling = true end)
ns:On("LOADING_SCREEN_DISABLED", function()
	settling = true
	C_Timer.After(SETTLE, function() settling = false Engine.Update() end)
end)

function Engine.Advance()
	if not guide or ended or settling then return end
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
	-- a catch-up guide goes back to the guide it was made for (Catchup.lua)
	if guide and guide.back then ns.Catchup.Return(guide) return end
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
	ns:Fire("OBVIGUIDE_LOADED", g)   -- (the guide picker's "Recent")
	Changed()
	Engine.Advance()
end

--- The open tabs, and which one is shown.
---@return ObviGuideTab[] tabs, integer shown
function Engine.Tabs()
	local tabs = Tabs()
	return tabs, ns.charDB and ns.charDB.tab or 1
end

-- shows what the shown tab holds: its guide at its step, or nothing (an empty tab)
local function ShowTab()
	local tab = Tabs()[ns.charDB.tab]
	local g = tab and tab.guide and ns.FindGuide(tab.guide)
	if g then
		guide, index = g, math.max(1, math.min(tab.step or 1, #g.steps))
	else
		guide, index = nil, 1
	end
	paused, ended = false, false
	Changed()
	Engine.Advance()
	ns:Fire("OBVIGUIDE_UPDATE")
end

--- Shows another tab.
---@param i integer
function Engine.SwitchTab(i)
	if not ns.charDB or not Tabs()[i] or i == ns.charDB.tab then return end
	ns.charDB.tab = i
	ShowTab()
end

--- Closes a tab (the last one left is emptied instead).
---@param i integer
function Engine.CloseTab(i)
	if not ns.charDB then return end
	local tabs = Tabs()
	if not tabs[i] then return end
	table.remove(tabs, i)
	if #tabs == 0 then tabs[1] = {} end
	local shown = ns.charDB.tab
	if i < shown or shown > #tabs then shown = shown - 1 end
	ns.charDB.tab = math.max(1, shown)
	ShowTab()
end

--- Opens a guide picked from the list: switches to its tab if it's open already, or else opens it from its first
--- step (the engine moves on past the steps already done) in a new tab beside the others, or in place of the one
--- shown (an empty one is always filled).
---@param title string
---@param beside? boolean
function Engine.Open(title, beside)
	local g = ns.FindGuide(title)
	local tabs = Tabs()
	for i, tab in ipairs(tabs) do
		if g and tab.guide and ns.FindGuide(tab.guide) == g then
			if i == ns.charDB.tab then Engine.Load(title, 1) else Engine.SwitchTab(i) end
			return
		end
	end
	if beside and g and ns.charDB and tabs[ns.charDB.tab].guide then
		table.insert(tabs, {})
		ns.charDB.tab = #tabs
	end
	Engine.Load(title, 1)
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

--- Straight to a step by its number (typed into the step counter), held there like a step chosen with the arrows.
---@param n integer
function Engine.GoTo(n)
	if not guide then return end
	index = math.max(1, math.min(math.floor(n), #guide.steps))
	ended, paused = false, true
	Changed()
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

-- a step that turns done in front of the player stays a moment, so its last line's "done" effect is seen
local open           -- the current step, while it isn't done yet
local lingering = false

function Engine.Update()
	local _, step = Engine.Current()
	if step and not lingering then
		local _, done = Engine.StepState(step)
		if not done then
			open = step
		elseif open == step then
			open, lingering = nil, true
			C_Timer.After(1, function()
				lingering = false
				Engine.Advance()
				ns:Fire("OBVIGUIDE_UPDATE")
			end)
		end
	end
	if not lingering then Engine.Advance() end
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
	"HEARTHSTONE_BOUND", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
	-- profession skill ups and training (an event this client lacks is skipped by ns:On)
	"SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRADE_SKILL_LIST_UPDATE" }) do
	ns:On(event, function() Engine.Update() end)
end

-- a "train at"/"sell to" line (goal.closes) is done once that NPC's trainer or merchant window is closed again, as Zygor
-- does: the NPC is noted when the window opens (its creature id, from the GUID's 6th field)
local openedBy = {} ---@type table<string, integer|false>   window kind -> the NPC who opened it
local function Opened(kind)
	local guid = UnitGUID("npc")
	local id = guid and not (issecretvalue and issecretvalue(guid)) and tonumber((select(6, strsplit("-", guid))))
	openedBy[kind] = id or false
end
local function Closed(kind)
	local who = openedBy[kind]
	openedBy[kind] = nil
	if who == nil then return end
	local _, step = Engine.Current()
	if not step then return end
	for _, g in ipairs(step.goals) do
		if g.closes == kind and Engine.IsVisible(g) and (not (g.target and g.target.id) or g.target.id == who) then
			Marks()[MarkKey(step, g)] = true
		end
	end
	Engine.Update()
end
ns:On("TRAINER_SHOW", function() Opened("trainer") end)
ns:On("TRAINER_CLOSED", function() Closed("trainer") end)
ns:On("MERCHANT_SHOW", function() Opened("vendor") end)
ns:On("MERCHANT_CLOSED", function() Closed("vendor") end)

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
	if guide or not inWorld or not ns.charDB then return end
	local tab = Tabs()[ns.charDB.tab]
	if tab and tab.guide and ns.FindGuide(tab.guide) then Engine.Load(tab.guide, tab.step) end
end
ns:On("PLAYER_ENTERING_WORLD", function() inWorld = true Restore() end)
ns:On("OBVIGUIDE_GUIDES_ADDED", Restore)

C_Timer.NewTicker(0.5, CheckArrival)

--- What the engine makes of the current step, line by line, for /og step: each line's kind, whether it's visible and
--- done, its manual tick, and for a flight path line what every map asked lists for it (fresh from the game).
---@return string
function Engine.DebugStep()
	local g, step = Engine.Current()
	if not (g and step) then return "no step" end
	local out = { ("%s, step %d"):format(g.title, step.index) }
	local applies, done = Engine.StepState(step)
	out[#out + 1] = ("applies %s, done %s, paused %s"):format(tostring(applies), tostring(done), tostring(paused))
	for _, goal in ipairs(step.goals) do
		local key = MarkKey(step, goal)
		out[#out + 1] = ("- [%s] %s | visible %s, complete %s, ticked %s%s"):format(goal.kind, tostring(goal.text),
			tostring(Engine.IsVisible(goal)), tostring(Engine.IsComplete(goal, step)), tostring(key and Marks()[key]),
			goal.done and ", has a done condition" or "")
		if goal.flight then
			local map = (goal.point and goal.point.map) or (step.dest and step.dest.map)
			out[#out + 1] = ("  flight %q, map %s"):format(goal.flight, tostring(map))
			local saved = {}
			for name in pairs(Seen()) do saved[#saved + 1] = name end
			out[#out + 1] = "  seen known: " .. (#saved > 0 and table.concat(saved, ", ") or "none")
			local want = goal.flight:gsub(", .*", ""):lower()
			local info, seen = map and C_Map.GetMapInfo(map), 0
			while info and seen < 8 do
				local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, info.mapID)
				local hits = {}
				for _, node in ipairs(ok and nodes or {}) do
					if node.name and node.name:lower():find(want, 1, true) then
						hits[#hits + 1] = ("%s (id %s, undiscovered %s, state %s, faction %s)"):format(node.name,
							tostring(node.nodeID), tostring(node.isUndiscovered), tostring((node --[[@as table]]).state), tostring(node.faction))
					end
				end
				out[#out + 1] = ("  map %d %s: %d nodes, matches: %s"):format(info.mapID, tostring(info.name),
					ok and nodes and #nodes or 0, #hits > 0 and table.concat(hits, "; ") or "none")
				if (info.parentMapID or 0) == 0 then break end
				info, seen = C_Map.GetMapInfo(info.parentMapID), seen + 1
			end
		end
	end
	return table.concat(out, "\n")
end
