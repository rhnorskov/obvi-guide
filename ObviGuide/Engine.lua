-- Engine: follows the guides of this character's guide windows, each its own (a follower per window, see Follower
-- below), all at once. It decides which goals are visible and done from the game's state, moves each window on to its
-- next step that applies, and remembers manual ticks and reached waypoints.
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

local followers = {} ---@type ObviGuideFollower[]   one per guide window, the first window's first
local active ---@type ObviGuideFollower?   the one the waypoint, the action keys and the map pins follow

-- Which guide a step or line is in: each guide a window follows notes its own (Own). One no window follows counts as
-- the active window's.
local stepOwner = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideStep, ObviGuideGuide>
local goalOwner = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGoal, ObviGuideGuide>
local owned = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideStep[], boolean>

---@param g ObviGuideGuide
local function Own(g)
	if owned[g.steps] then return end
	owned[g.steps] = true
	for _, s in ipairs(g.steps) do
		stepOwner[s] = g
		for _, list in ipairs({ s.goals, s.side }) do
			for _, goal in ipairs(list) do
				goalOwner[goal] = g
				for _, w in ipairs(goal.with or {}) do goalOwner[w] = g end
			end
		end
	end
end

--- The guide a step or line is in (the active window's when no window follows it).
---@param step? ObviGuideStep
---@param goal? ObviGuideGoal
---@return ObviGuideGuide?
function Engine.GuideOf(step, goal)
	return step and stepOwner[step] or goal and goalOwner[goal] or active and active.guide or nil
end

--- The window following a guide: the active one if it does, else the first that does.
---@param g? ObviGuideGuide
---@return ObviGuideFollower?
local function FollowerOf(g)
	if not g then return nil end
	if active and active.guide == g then return active end
	for _, f in ipairs(followers) do if f.guide == g then return f end end
end

local COMPLETABLE = { accept = true, turnin = true, objective = true, kill = true, collect = true, equip = true,
	cast = true, learn = true, level = true, home = true, hearth = true, ["goto"] = true, confirm = true, skill = true,
	challenge = true, sell = true }

--- Whether a line counts towards its step being done: one the game can check (or that is ticked off), or any line
--- with its own done condition (a Use line ticked once the recipe it uses is known); not an optional one.
---@param g ObviGuideGoal
---@return boolean
local function Counts(g)
	return not g.optional and (COMPLETABLE[g.kind] or g.done ~= nil)
end

-- manual ticks and reached waypoints: charDB.marks[guide title]["step:goal"] = true
---@param g? ObviGuideGuide
local function Marks(g)
	if not (g and ns.charDB) then return {} end
	ns.charDB.marks = ns.charDB.marks or {}
	ns.charDB.marks[g.title] = ns.charDB.marks[g.title] or {}
	return ns.charDB.marks[g.title]
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

--- Yards between the player and a point, or nil when they are not on the same continent.
---@param p ObviGuidePoint
local function Distance(p)
	local c1, w1 = ns.Travel.PlayerWorld()
	local c2, w2 = ns.Travel.World(p)
	if not (w1 and w2) or c1 ~= c2 then return nil end
	local dx, dy = w1.x - w2.x, w1.y - w2.y
	return math.sqrt(dx * dx + dy * dy)
end

-- how near another window's step's flight master must be for a flight path learned now to be its
local FLIGHT_NEAR = 60

ns:On("UI_INFO_MESSAGE", function(_, _, message)
	if message ~= _G["ERR_NEWTAXIPATH"] then return end
	wipe(discovered)
	-- learned just now: the flight lines of the active window's step count as done, whatever the flight map lists (and
	-- of another window's step, those whose flight master is right here), and their flight points are remembered as
	-- known (Zygor notes the flight master's node the same way)
	for _, f in ipairs(followers) do
		local _, step = f:Current()
		if step then
			for _, g in ipairs(step.goals) do
				local key = g.flight and MarkKey(step, g)
				local at = g.point or step.dest
				local d = f ~= active and at and Distance(at)
				if key and (f == active or (d and d <= FLIGHT_NEAR)) then
					Marks(f.guide)[key] = true
					Seen()[FlightName(g.flight)] = true
				end
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

-- Whether a quest can be taken as far as its pre-quests go (QuestieDB knows them; without it, always). A pre-quest in
-- the log counts: the guide turns it in first, often in the same step. Breadcrumbs and pre-quests for other races and
-- classes don't count. Of alternatives, one is enough. So a chain begun in a guide you skipped (The Legend of Stalvan,
-- for one who did dungeons instead) isn't asked for later on.
local preQuests = {} ---@type table<integer, {all: integer[], any: integer[]}|false>

---@param q integer
local function Had(q) return C_QuestLog.IsQuestFlaggedCompleted(q) or C_QuestLog.IsOnQuest(q) end

-- a pre-quest is done once it's turned in, or ready to be (the guide turns it in first, often in the same step); one
-- still in progress is not (The Night Watch 57 in the log: 58 isn't given until it's turned in)
---@param q integer
local function PreDone(q)
	return C_QuestLog.IsQuestFlaggedCompleted(q) or (C_QuestLog.IsOnQuest(q) and C_QuestLog.ReadyForTurnIn(q))
end

-- whether a mask has a flag (one bit), in plain arithmetic: QuestieDB's race masks go past 32 bits (4294967373 for
-- the Alliance), where bit.band would cut them off
---@param mask number
---@param flag number
local function HasFlag(mask, flag) return math.floor(mask / flag) % 2 == 1 end

--- Whether QuestieDB has the quest as a breadcrumb (it leads to another quest and is never needed). Not set, it says
--- 0, which Lua counts as true: a quest id it must be.
---@param DB table
---@param q integer
function Engine.Breadcrumb(DB, q)
	local b = DB.Quest.breadcrumbForQuestId(q)
	return type(b) == "number" and b > 0
end

--- Whether QuestieDB has the quest for this character's race and class (nothing said: for everyone).
---@param DB table
---@param q integer
function Engine.ForMe(DB, q)
	local races = DB.Quest.requiredRaces(q)
	if races and races ~= 0 then
		local _, _, raceId = UnitRace("player")
		local flag = DB.Enum.raceMaskById[raceId]
		if flag and not HasFlag(races, flag) then return false end
	end
	local classes = DB.Quest.requiredClasses(q)
	if classes and classes ~= 0 then
		local _, _, classId = UnitClass("player")
		if not HasFlag(classes, 2 ^ (classId - 1)) then return false end
	end
	return true
end

-- The guide's own word, for a quest QuestieDB knows no pre-quests of (WoW Forever's new chains, "A Friend of the Family"
-- 98191): a quest accepted in the step that turns in a quest of the same title continues that one. Per guide: each such
-- quest's namesakes turned in beside it, worked out the first time it's asked.
local chained = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGuide, table<integer, integer[]>>

---@param text? string
local function LineTitle(text)
	text = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return (text:gsub("^Accept%s+", ""):gsub("^Turn in%s+", ""):lower())
end

---@param q integer
---@param g? ObviGuideGuide   (the active window's guide when not given)
---@return integer[]?
function Engine.ChainedIn(q, g)
	local of = g or active and active.guide
	if not of then return nil end
	local map = chained[of]
	if not map then
		map = {}
		for _, s in ipairs(of.steps) do
			local turnins = {} ---@type table<string, integer[]>
			for _, g in ipairs(s.goals) do
				if g.kind == "turnin" and g.quest then
					local t = LineTitle(g.text)
					turnins[t] = turnins[t] or {}
					table.insert(turnins[t], g.quest)
				end
			end
			for _, g in ipairs(s.goals) do
				local before = g.kind == "accept" and g.quest and turnins[LineTitle(g.text)]
				if before then
					for _, p in ipairs(before) do
						if p ~= g.quest then map[g.quest] = map[g.quest] or {} table.insert(map[g.quest], p) end
					end
				end
			end
		end
		chained[of] = map
	end
	return map[q]
end

-- WoW Forever's chains QuestieDB doesn't link up yet (from Wowhead's series), where the guide's titles don't tell
-- either: quest -> its pre-quest
local KNOWN = {
	[98189] = 286,     -- Return the Statuette, after Return the Statuette (Menethil)
	[98190] = 98189,   -- A Friend of the Family, after Return the Statuette
	[98191] = 98190,   -- A Friend of the Family, after A Friend of the Family
	[98219] = 98191,   -- The Shamed Lieutenant, after A Friend of the Family
}

--- A quest's pre-quests: all of `all`, and one of `any` (if any); nil when nothing is known. The guide's word for it
--- (ChainedIn) is the given guide's, else the active window's.
---@param q integer
---@param g? ObviGuideGuide
---@return {all: integer[], any: integer[]}?
local function PreOf(q, g)
	local pre = preQuests[q]
	if pre == nil then
		local DB = _G["LibQuestieDB"] ---@type table?
		if DB and DB.Quest then
			pre = false
			local ok, all, any = pcall(function() return DB.Quest.preQuestGroup(q), DB.Quest.preQuestSingle(q) end)
			if ok then
				local function keep(list)
					local out = {}
					for _, p in ipairs(list or {}) do
						if not Engine.Breadcrumb(DB, p) and Engine.ForMe(DB, p) then out[#out + 1] = p end
					end
					return out
				end
				pre = { all = keep(all), any = keep(any) }
			end
			preQuests[q] = pre
		end
		-- (without QuestieDB nothing is remembered: it may come later)
	end
	if pre and (#pre.all > 0 or #pre.any > 0) then return pre end
	if KNOWN[q] then return { all = { KNOWN[q] }, any = {} } end
	local inGuide = Engine.ChainedIn(q, g)
	if inGuide then return { all = {}, any = inGuide } end
	return nil
end

Engine.PreQuests = PreOf

-- the share of a quest's XP a character gets that is this many levels above the quest (classic rules: full up to 5)
local XP_SHARE = { [6] = 0.8, [7] = 0.6, [8] = 0.4, [9] = 0.2 }

--- The XP a quest gives this character now (QuestieDB's quest XP, less for a quest far below your level), or nil when
--- it isn't known. None at the level cap.
---@param q integer
---@return integer?
function Engine.QuestXP(q)
	local DB = _G["LibQuestieDB"] ---@type table?
	if not DB then return nil end
	local ok, entry = pcall(function() return DB.Support.Get("QuestXP").db[q] end)
	if not (ok and type(entry) == "table" and entry[2]) then return nil end
	local me = UnitLevel("player")
	if me >= (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60) then return 0 end
	local above = me - (entry[1] or me)
	local share = above <= 5 and 1 or XP_SHARE[above] or 0.1
	return math.floor(entry[2] * share + 0.5)
end

---@param q integer
local function NameOf(q)
	local DB = _G["LibQuestieDB"] ---@type table?
	return (DB and DB.Quest and DB.Quest.name(q)) or C_QuestLog.GetTitleForQuestID(q) or ("quest " .. q)
end

--- A quest's name as Obvi Guide says it, with its place when it's one of a chain of quests of the same name (as
--- Wowhead's series has it): "The Night Watch (part 2)". The part is counted back through its pre-quests of that
--- name; the first one is "part 1" when the next in its chain has the name too.
---@param q integer
---@return string
function Engine.QuestLabel(q)
	local name = NameOf(q)
	local part, cur = 1, q
	for _ = 1, 20 do
		local pre, back = PreOf(cur), nil
		for _, list in ipairs(pre and { pre.all, pre.any } or {}) do
			for _, p in ipairs(list) do if NameOf(p) == name then back = p break end end
			if back then break end
		end
		if not back then break end
		part, cur = part + 1, back
	end
	if part == 1 then
		local DB = _G["LibQuestieDB"] ---@type table?
		local ok, after = pcall(function() return DB and DB.Quest.nextQuestInChain(q) end)
		if not (ok and type(after) == "number" and after > 0 and NameOf(after) == name) then return name end
	end
	return ("%s (part %d)"):format(name, part)
end

---@param q integer
---@param g? ObviGuideGuide   the guide asking (see PreOf)
---@return boolean
function Engine.CanTake(q, g)
	local pre = PreOf(q, g)
	if not pre then return true end
	for _, p in ipairs(pre.all) do if not PreDone(p) then return false end end
	if #pre.any == 0 then return true end
	for _, p in ipairs(pre.any) do if PreDone(p) then return true end end
	return false
end

--- For an accept line left out because the quest can't be taken yet: what it waits for, so the window can show the
--- line greyed out with it: "needs Blessed Arm", or "finish The Night Watch first" when that one is in the log (then
--- also true: its step isn't skipped, you're on the way). A turn-in line left out because the quest isn't in your log
--- (it was given in a guide you skipped): "not in your quest log". Nil for any other line.
---@param goal ObviGuideGoal
---@return string?, boolean?
function Engine.Locked(goal)
	if not goal.quest or Had(goal.quest) or not Conditions.Eval(goal.cond) then return nil end
	local g = Engine.GuideOf(nil, goal)
	if goal.kind == "turnin" then
		-- (not when this guide gives it on the way: at the step its window is on or later, before the turn-in)
		local a, at = Engine.AcceptedAt(goal.quest, g), Engine.StepOf(goal, g)
		local f = FollowerOf(g)
		if a and at and a <= at and a >= (f and f.index or 1) then return nil end
		return "not in your quest log", false
	end
	if goal.kind ~= "accept" then return nil end
	if Engine.CanTake(goal.quest, g) then return nil end
	local pre = PreOf(goal.quest, g)
	local names = {}
	local function add(p) names[#names + 1] = Engine.QuestLabel(p) end
	local waiting = false
	for _, p in ipairs(pre and pre.all or {}) do
		if not PreDone(p) then add(p) waiting = waiting or C_QuestLog.IsOnQuest(p) end
	end
	local list = table.concat(names, " and ")
	if #names == 0 then
		for _, p in ipairs(pre and pre.any or {}) do add(p) waiting = waiting or C_QuestLog.IsOnQuest(p) end
		list = table.concat(names, " or ")
	end
	if waiting then return "finish " .. list .. " first", true end
	return "needs " .. list, false
end

-- Per guide: the step each goal is in, and the first step that accepts each quest; worked out the first time asked.
local places = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGuide, {goal: table<ObviGuideGoal, integer>, accept: table<integer, integer>}>

---@param guide? ObviGuideGuide
---@return {goal: table<ObviGuideGoal, integer>, accept: table<integer, integer>}?
local function Places(guide)
	if not guide then return nil end
	local p = places[guide]
	if not p then
		p = { goal = {}, accept = {} }
		for i, s in ipairs(guide.steps) do
			for _, g in ipairs(s.goals) do
				p.goal[g] = i
				if g.kind == "accept" and g.quest and not p.accept[g.quest] then p.accept[g.quest] = i end
			end
		end
		places[guide] = p
	end
	return p
end

--- The step a goal is in, in a guide (by default the one it's in); nil: not one of its steps.
---@param goal ObviGuideGoal
---@param g? ObviGuideGuide
---@return integer?
function Engine.StepOf(goal, g) local p = Places(g or Engine.GuideOf(nil, goal)) return p and p.goal[goal] end

--- The first step of a guide (the active window's) that accepts a quest (nil: none).
---@param quest integer
---@param g? ObviGuideGuide
---@return integer?
function Engine.AcceptedAt(quest, g) local p = Places(g or active and active.guide) return p and p.accept[quest] end

--- The "Quests missing a prerequisite" setting: "show" them (the default), skip them when catching up is "notworth"
--- it, or skip "all" of them. (Once a checkbox: ticked was skipping them all.)
---@return "show"|"notworth"|"all"
function Engine.SkipMissing()
	local db = ns.db
	if not db then return "show" end
	return db.skipMissing or (db.skipLocked and "all") or "show"
end

---@param goal ObviGuideGoal
---@return boolean
function Engine.IsVisible(goal)
	if not Conditions.Eval(goal.cond) then return false end
	-- a "Sell …" line: only while you have more than the guide still needs, and vendors buy it
	if goal.kind == "sell" then
		if C_Item.GetItemCount(goal.id) <= (goal.keep or 0) then return false end
		local price = select(11, C_Item.GetItemInfo(goal.id))
		return price == nil or price > 0
	end
	-- the NPC at one of a step's places to choose from: only at the one chosen
	if goal.option and not goal.option.chosen then return false end
	-- (the "Skip hearthstone steps" setting: hearth and set-hearth lines left out, so a step with nothing else is
	-- skipped)
	if (goal.kind == "hearth" or goal.kind == "home") and ns.db and ns.db.skipHearth then return false end
	if goal.kind == "accept" and goal.quest and not Had(goal.quest)
		and not Engine.CanTake(goal.quest, Engine.GuideOf(nil, goal)) then
		return false
	end
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
---@param guide? ObviGuideGuide   the guide the line is in
---@return boolean
local function LaterNamesakeTaken(quest, guide)
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

--- Whether a side task (its box: the lines of one g:Side) is still shown: while one of its lines that can be done is
--- shown and not done. Once they're done or hidden, the whole task goes, its notes and plain lines with it. A task
--- with only notes and plain lines is always shown.
---@param box ObviGuideGoal[]
---@param step ObviGuideStep
---@return boolean
function Engine.SideOpen(box, step)
	local any = false
	for _, g in ipairs(box) do
		if Counts(g) then
			any = true
			if Engine.IsVisible(g) and not Engine.IsComplete(g, step) then return true end
		end
	end
	return not any
end

-- Collect lines for a skill range that have been met: the need drops at each skill point, the bags at each craft (and
-- a yellow craft gives no point), so such a line would flick on and off while you make things. Once met it stays
-- ticked until you run out of the item; a new step starts afresh.
local met = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGoal, boolean>

--- How many a collect line needs now: its count, or for a line with a skill range, what the points left in it need
--- (60 for 1-30, at 15: 30; none once past it).
---@param goal ObviGuideGoal
---@return integer
function Engine.Need(goal)
	local n, r = goal.count or 1, goal.range
	-- (the reagents for the parts still to make: N of an item, so many each)
	local p = goal.toMake
	if p then return math.max(0, p.count - C_Item.GetItemCount(p.item)) * p.each end
	if not r or r[3] <= r[2] then return n end
	local skill = Conditions.Skill(r[1]) or 0
	local left = math.min(r[3] - r[2], math.max(0, r[3] - math.max(skill, r[2])))
	return math.ceil(n * left / (r[3] - r[2]))
end

---@param goal ObviGuideGoal
---@param step ObviGuideStep
---@return boolean
function Engine.IsComplete(goal, step)
	if goal.done and Conditions.Eval(goal.done) then return true end
	-- a step whose skip holds is done, its click-when-done lines with it (ticked when you go back to it); lines the
	-- game can check (equipped, a skill, a quest) show what's true
	if step and step.skip and goal.kind == "confirm" and Conditions.Eval(step.skip) then return true end
	if goal.with then
		-- (a line that isn't shown, as a turn-in only for those who have the quest, doesn't hold it up)
		for _, w in ipairs(goal.with) do
			if Engine.IsVisible(w) and not Engine.IsComplete(w, step) then return false end
		end
		return true
	end
	local k = goal.kind
	local guide = Engine.GuideOf(step, goal)
	if k == "accept" then
		return C_QuestLog.IsOnQuest(goal.quest) or C_QuestLog.IsQuestFlaggedCompleted(goal.quest)
			or LaterNamesakeTaken(goal.quest, guide)
	end
	if k == "turnin" then return C_QuestLog.IsQuestFlaggedCompleted(goal.quest) or LaterNamesakeTaken(goal.quest, guide) end
	if k == "objective" or k == "kill" or (k == "collect" and goal.objective) then
		if C_QuestLog.IsQuestFlaggedCompleted(goal.quest) then return true end
		local o = Objective(goal)
		-- a quest ready to turn in counts its objectives done, as Zygor does: on retail the objective list can still
		-- say 0/1 when the quest is complete (seen with "Arrive at Talonstrike Terrace"). Not a line the game doesn't
		-- track, though: such a quest says complete from the start (resurrecting Henze Faulk with the Symbol of Life),
		-- so the line waits for the turn-in.
		if o and C_QuestLog.ReadyForTurnIn(goal.quest) then return true end
		-- a line for part of the objective ("|count 3" in Zygor) is done once the objective has reached that many
		if o and goal.need then return (o.numFulfilled or 0) >= goal.need end
		return o and o.finished or false
	end
	if k == "sell" then return C_Item.GetItemCount(goal.id) <= (goal.keep or 0) end
	if k == "collect" then
		local have = C_Item.GetItemCount(goal.id)
		if have >= Engine.Need(goal) then
			if goal.range then met[goal] = true end
			return true
		end
		if met[goal] and have > 0 then return true end
		met[goal] = nil
		return false
	end
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
		return key ~= nil and Marks(guide)[key] == true
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
	elseif goal.kind == "sell" and goal.id then   -- (how many to sell)
		return tostring(math.max(0, C_Item.GetItemCount(goal.id) - (goal.keep or 0)))
	elseif goal.kind == "collect" and goal.id then   -- (also a count of 1: "Buy Soothing Spices (0/1)")
		local need, have = Engine.Need(goal), C_Item.GetItemCount(goal.id)
		-- (a met scaled line, a little short while you make things: just what you have)
		if met[goal] and have < need then return tostring(have) end
		return math.min(have, need) .. "/" .. need
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
	-- a quest missing a prerequisite keeps its step, greyed out, as the "Quests missing a prerequisite" setting says:
	-- shown (the default), skipped when catching up isn't worth it, or skipped; one whose prerequisite is in the log,
	-- always
	local mode = Engine.SkipMissing()
	local function keep(g, waiting)
		if waiting or mode == "show" then return true end
		if mode == "all" then return false end
		return not (ns.Catchup and g.quest and ns.Catchup.Verdict(g.quest) == "not")
	end
	for _, g in ipairs(step.goals) do
		local locked, waiting
		if not Engine.IsVisible(g) then locked, waiting = Engine.Locked(g) end
		if locked and keep(g, waiting) then
			any, done = true, false
		elseif Counts(g) and Engine.IsVisible(g) then
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

-- Followers: what each guide window follows, its guide and where it is in it, all at the same time. A window has
-- tabs (as Zygor has them; switched in the window title's menu): several guides open in it (a leveling guide, a
-- dungeon, a profession), one of them shown. Each tab keeps its guide (by name where the guide has one: titles may
-- repeat across groups, Zygor's are the last part of its path) and the step it was on, in the window's slot: the first
-- window's is charDB itself (charDB.tabs, with charDB.tab the one shown), the others' are in charDB.windows. A tab with
-- no guide yet is empty. Every window moves on as its steps are done; the active one (the window last used) is the one
-- the waypoint, the action keys and the map pins follow.
---@class ObviGuideFollower
---@field slot ObviGuideWindowSave   its tabs, saved
---@field guide? ObviGuideGuide
---@field index integer            its step
---@field ended boolean            the guide is finished: the window shows its end (and the next guide) instead of a step
---@field paused boolean           going back pauses auto-advance (see Advance)
---@field reached integer          the furthest step the guide itself has gone to (while not paused)
---@field replan boolean           a guide in any order: the route is planned again when it's opened
---@field open? ObviGuideStep      its step, while it isn't done yet
---@field lingering boolean        its step turned done in front of the player: it stays a moment
---@field closed? boolean          its window was closed
local Follower = {}
Follower.__index = Follower

---@param slot ObviGuideWindowSave
---@return ObviGuideFollower
local function NewFollower(slot)
	local f = setmetatable({ slot = slot, index = 1, ended = false, paused = false, reached = 0, replan = false,
		lingering = false }, Follower)
	return f --[[@as ObviGuideFollower]]
end

-- the active window, saved by its place among the windows (charDB.focus)
local function SaveFocus()
	if not ns.charDB then return end
	for i, f in ipairs(followers) do if f == active then ns.charDB.focus = i > 1 and i or nil end end
end

--- The followers, one per guide window: made from the saved windows the first time they're asked for, once the saved
--- variables are there.
---@return ObviGuideFollower[]
local function Followers()
	local db = ns.charDB
	if followers[1] or not db then return followers end
	followers[1] = NewFollower(db)
	for _, slot in ipairs(db.windows or {}) do followers[#followers + 1] = NewFollower(slot) end
	active = followers[math.max(1, math.min(db.focus or 1, #followers))]
	return followers
end

--- The guide windows' followers, the first window's first.
---@return ObviGuideFollower[]
function Engine.Followers() return Followers() end

--- The active window's follower (nil until the saved variables are there).
---@return ObviGuideFollower?
function Engine.Active()
	Followers()
	return active
end

--- Makes a window the active one, quietly (what the caller does next shows its step); returns whether it changed.
---@param f ObviGuideFollower
---@return boolean
local function SetActive(f)
	if active == f then return false end
	active = f
	SaveFocus()
	return true
end

--- Makes a window the active one: the waypoint, the action keys and the map pins follow its step from now on.
---@param f ObviGuideFollower
function Engine.Focus(f)
	if f.closed or not SetActive(f) then return end
	local _, step = f:Current()
	ns.Travel.Show(step)
	ns:Fire("OBVIGUIDE_STEP", f)
end

--- The guide, and its current step (none once the guide has ended).
---@return ObviGuideGuide?, ObviGuideStep?
function Follower:Current()
	local g = self.guide
	return g, g and not self.ended and g.steps[self.index] or nil
end

--- The window's tabs, and which one is shown.
---@return ObviGuideTab[] tabs, integer shown
function Follower:Tabs()
	local slot = self.slot
	if not slot.tabs then
		-- from before tabs: the one guide followed becomes the first tab
		slot.tabs = { { guide = slot.guide, step = slot.step } }
		slot.tab, slot.guide, slot.step = 1, nil, nil
	end
	if #slot.tabs == 0 then slot.tabs[1] = {} end
	slot.tab = math.max(1, math.min(slot.tab or 1, #slot.tabs))
	return slot.tabs, slot.tab
end

--- What each window follows that has a guide: its guide and its step (none once ended), the active window's first.
---@return {guide: ObviGuideGuide, step?: ObviGuideStep}[]
function Engine.Following()
	local list = {}
	local function add(f)
		local g, step = f:Current()
		if g then list[#list + 1] = { guide = g, step = step } end
	end
	if Engine.Active() then add(active) end
	for _, f in ipairs(followers) do if f ~= active then add(f) end end
	return list
end

--- Where to get a collect line's item (goal.places): the nearest one on your continent, else the first; nil without any.
---@param goal ObviGuideGoal
---@return {point: ObviGuidePoint, name?: string}?
function Engine.NearestPlace(goal)
	local best, bestD
	for _, p in ipairs(goal.places or {}) do
		local d = Distance(p.point)
		if not best or (d and (not bestD or d < bestD)) then best, bestD = p, d end
	end
	return best
end

--- For a step with places to choose from (step.options, e.g. several trainers): the nearest one that applies becomes
--- its waypoint, its NPC the one the action key targets and its talk line the one shown. Nearest as the crow flies,
--- on your continent; when none is, the first that applies. Picked when the step comes up and when you enter
--- another zone, so it doesn't flip back and forth on the way. Returns whether the choice changed.
---@param step? ObviGuideStep
---@return boolean
function Engine.Pick(step)
	local options = step and step.options
	if not (step and options) then return false end
	local best, bestD
	for i, o in ipairs(options) do
		if Conditions.Eval(o.cond) then
			local d = Distance(o.point)
			if not best or (d and (not bestD or d < bestD)) then best, bestD = i, d end
		end
	end
	best = best or 1
	if options[best].chosen then return false end
	for i, o in ipairs(options) do o.chosen = i == best end
	step.dest = options[best].point
	step.target = options[best].target or step.target
	return true
end

-- a scaled material line met in a step its window has left starts afresh (the windows' current steps keep theirs)
local function ForgetMet()
	local current = {} ---@type table<ObviGuideGoal, boolean>
	for _, f in ipairs(followers) do
		local _, step = f:Current()
		for _, list in ipairs(step and { step.goals, step.side } or {}) do
			for _, g in ipairs(list) do current[g] = true end
		end
	end
	for g in pairs(met) do if not current[g] then met[g] = nil end end
end

--- The step changed: the tab remembers it, its place to go is picked, and the active window's step gets the waypoint.
function Follower:Changed()
	ForgetMet()
	if not self.paused then self.reached = math.max(self.reached, self.index) end
	local tabs, shown = self:Tabs()
	local tab, g = tabs[shown], self.guide
	-- (a tab whose guide isn't here, its pack not loaded, keeps it)
	if tab and g then tab.guide, tab.step, tab.reached = g.name or g.title, self.index, self.reached end
	local _, step = self:Current()
	Engine.Pick(step)
	if self == active then ns.Travel.Show(step) end
	ns:Fire("OBVIGUIDE_STEP", self)
end

-- a step with places to choose from picks again in another zone (you may have come nearer another of them)
ns:On("ZONE_CHANGED_NEW_AREA", function()
	for _, f in ipairs(followers) do
		local _, step = f:Current()
		if Engine.Pick(step) then
			if f == active then ns.Travel.Show(step) end
			ns:Fire("OBVIGUIDE_STEP", f)
		end
	end
end)

--- Where a map point is in the world: the continent and yards, or nil where the game can't say.
---@param map integer
---@param x number   0-1
---@param y number   0-1
---@return integer?, number?, number?
local function World(map, x, y)
	local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
	if ok and continent and pos then return continent, pos.x, pos.y end
end

--- For a guide whose steps can be done in any order: the step to go to first on the shortest way from where you
--- are through all the steps left to do. The way is planned as the guide's maker plans it: always on to the
--- nearest, then untangled (any stretch turned round where that makes it shorter). nil when no step is left; the
--- first step left, in the guide's order, when where you are or where they are isn't known.
---@param g ObviGuideGuide
---@return integer?
local function FirstStop(g)
	local left = {} ---@type {i: integer, x: number?, y: number?}[]
	for i, s in ipairs(g.steps) do
		local applies, done = Engine.StepState(s)
		if applies and not done then table.insert(left, { i = i }) end
	end
	if #left == 0 then return nil end
	local here = C_Map.GetBestMapForUnit("player") --[[@as integer?]]
	local at = here and C_Map.GetPlayerMapPosition(here, "player")
	local continent, px, py
	if here and at then continent, px, py = World(here, at.x, at.y) end
	if not continent then return left[1].i end
	-- the steps on this continent (with a spot); the others wait until you get there
	local stops = {} ---@type {i: integer, x: number, y: number}[]
	for _, l in ipairs(left) do
		local d = g.steps[l.i].dest
		local c, x, y
		if d then c, x, y = World(d.map, d.x, d.y) end
		if c == continent then table.insert(stops, { i = l.i, x = x, y = y }) end
	end
	if #stops == 0 then return left[1].i end
	local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
	-- nearest first, from here
	local route, from = { { x = px, y = py } }, { x = px, y = py }
	while #stops > 0 do
		local best, bestD = 1, math.huge
		for k, s in ipairs(stops) do
			local dd = dist(from, s)
			if dd < bestD then best, bestD = k, dd end
		end
		from = table.remove(stops, best)
		table.insert(route, from)
	end
	-- untangle: turn round the stretch i..j when its ends join up shorter that way (here, route[1], stays first)
	local n, better, rounds = #route, true, 0
	while better and rounds < 50 do
		better, rounds = false, rounds + 1
		for i = 2, n - 1 do
			for j = i + 1, n do
				local gain = dist(route[i - 1], route[i]) - dist(route[i - 1], route[j])
				if j < n then gain = gain + dist(route[j], route[j + 1]) - dist(route[i], route[j + 1]) end
				if gain > 0.01 then
					local a, b = i, j
					while a < b do route[a], route[b] = route[b], route[a] a, b = a + 1, b - 1 end
					better = true
				end
			end
		end
	end
	return route[2].i
end

--- Whether the guide is finished, and the title of the guide that follows it (when we have it).
---@return boolean ended, string? nextTitle
function Follower:Ended()
	local g = self.guide
	local nxt = self.ended and g and g.next and ns.FindGuide(g.next)
	return self.ended, nxt and nxt.title or nil
end

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

--- Moves forward past steps that don't apply or are done. A step meant for this character that is done (or has
--- nothing left to do) may jump elsewhere instead (Zygor's "|next"); the step it lands on starts afresh, without the
--- ticks of an earlier visit, as Zygor has it (so a menu step you come back to asks again).
--- Going back pauses auto-advance, as Zygor does: it stays paused until the step you're on is not done (from then on
--- finishing it moves on as usual), so a finished step you went back to stays put.
function Follower:Advance()
	local guide = self.guide
	if not guide or self.ended or settling or self.closed then return end
	if self.paused then
		local applies, done = Engine.StepState(guide.steps[self.index])
		if applies and not done then self.paused = false end
		return
	end
	-- a guide in any order (exploration): once the step is done, or the guide has just been opened, on to the first
	-- stop of the shortest way from here through the steps left
	if guide.nearest then
		local applies, done = Engine.StepState(guide.steps[self.index])
		if self.replan or not applies or done then
			self.replan = false
			local to = FirstStop(guide)
			if to then
				if to ~= self.index then
					self.index = to
					self:Changed()
				end
				return
			end
		end
	end
	local start = self.index
	local landed = {}   -- each jump target once, so two done steps can't send us round in circles
	while self.index <= #guide.steps do
		local step = guide.steps[self.index]
		local applies, done = Engine.StepState(step)
		if applies and not done then break end
		local to = step.jumps and Conditions.Eval(step.cond) and Engine.JumpOf(step)
		if to and guide.steps[to] and not landed[to] then
			landed[to] = true
			self.index = to
			local marks, prefix = Marks(guide), to .. ":"
			for key in pairs(marks) do if key:sub(1, #prefix) == prefix then marks[key] = nil end end
		else
			self.index = self.index + 1
		end
	end
	if self.index > #guide.steps then
		-- the guide is finished: its end is shown, with the next guide to continue with (not loaded on its own, so
		-- the player sees the guide ended rather than another one starting)
		self.index = #guide.steps
		self.ended = true
		self:Changed()
		return
	end
	if self.index ~= start then self:Changed() end
end

--- From a finished guide on to the one that follows it (the end's button, or the next arrow).
function Follower:Continue()
	local g = self.guide
	-- a catch-up guide goes back to the guide it was made for (Catchup.lua, in the active window)
	if g and g.back then
		SetActive(self)
		ns.Catchup.Return(g)
		return
	end
	local _, nextTitle = self:Ended()
	if nextTitle then self:Load(nextTitle, 1) end
end

---@param title string
---@param step? integer
function Follower:Load(title, step)
	local g = ns.FindGuide(title)
	if not g then ns.Print("no guide called '%s'", title) return end
	Own(g)
	self.guide, self.index = g, math.max(1, math.min(step or 1, #g.steps))
	self.paused, self.ended, self.reached = false, false, 0
	self.replan = true
	ns:Fire("OBVIGUIDE_LOADED", g)   -- (the guide picker's "Recent")
	self:Changed()
	self:Advance()
end

--- Shows what the shown tab holds: its guide at its step, or nothing (an empty tab).
function Follower:ShowTab()
	local tabs, shown = self:Tabs()
	local tab = tabs[shown]
	local g = tab and tab.guide and ns.FindGuide(tab.guide)
	if g then
		Own(g)
		self.guide, self.index = g, math.max(1, math.min(tab.step or 1, #g.steps))
	else
		self.guide, self.index = nil, 1
	end
	-- (a step you went back to stays one: the furthest step is kept with the tab)
	local reached = tab and tab.reached or 0
	self.paused, self.ended, self.reached = self.index < reached, false, reached
	self:Changed()
	self:Advance()
	ns:Fire("OBVIGUIDE_UPDATE")
end

--- Shows another tab.
---@param i integer
function Follower:SwitchTab(i)
	local tabs, shown = self:Tabs()
	if not tabs[i] or i == shown then return end
	self.slot.tab = i
	self:ShowTab()
end

--- Closes a tab. The last one left in the first window is emptied instead; another window closes with it.
---@param i integer
function Follower:CloseTab(i)
	local tabs, shown = self:Tabs()
	if not tabs[i] then return end
	if #tabs == 1 and self ~= followers[1] then Engine.CloseWindow(self) return end
	table.remove(tabs, i)
	if #tabs == 0 then tabs[1] = {} end
	if i < shown or shown > #tabs then shown = shown - 1 end
	self.slot.tab = math.max(1, shown)
	self:ShowTab()
end

--- Opens another guide window, empty (its guide is picked next), and returns its follower.
---@return ObviGuideFollower?
function Engine.NewWindow()
	local db = ns.charDB
	if not db then return nil end
	Followers()
	db.windows = db.windows or {}
	local slot = { tabs = { {} }, tab = 1 } ---@type ObviGuideWindowSave
	table.insert(db.windows, slot)
	local f = NewFollower(slot)
	table.insert(followers, f)
	ns:Fire("OBVIGUIDE_WINDOWS")
	return f
end

--- Closes a guide window with its tabs (not the first window). If it was the active one, the first window is now.
---@param f ObviGuideFollower
function Engine.CloseWindow(f)
	local db = ns.charDB
	if not db or f == followers[1] or f.closed then return end
	for i, other in ipairs(followers) do if other == f then table.remove(followers, i) break end end
	for i, slot in ipairs(db.windows or {}) do if slot == f.slot then table.remove(db.windows, i) break end end
	if db.windows and #db.windows == 0 then db.windows = nil end
	f.closed = true
	ns:Fire("OBVIGUIDE_WINDOWS")
	if active == f then
		active = nil
		Engine.Focus(followers[1])
	else
		SaveFocus()
	end
end

--- Moves a window's tab out into a window of its own, which becomes the active one.
---@param f ObviGuideFollower
---@param i integer
function Engine.MoveTab(f, i)
	local tabs, shown = f:Tabs()
	if #tabs < 2 or not tabs[i] then return end
	local to = Engine.NewWindow()
	if not to then return end
	to.slot.tabs = { table.remove(tabs, i) }
	local moved = i == shown
	if i < shown or shown > #tabs then shown = shown - 1 end
	f.slot.tab = math.max(1, shown)
	SetActive(to)
	if moved then f:ShowTab() end   -- (the tab next to it shows in its place)
	to:ShowTab()
end

--- Opens a guide picked from the list: switches to its tab if it's open already (in any window), or else opens it
--- from its first step (the engine moves on past the steps already done) in a window (`into`, else the active one):
--- in a new tab beside the others, or in place of the one shown (an empty one is always filled); with beside
--- "window", in a new window of its own. The window it's in becomes the active one.
---@param title string
---@param beside? boolean|"window"
---@param into? ObviGuideFollower
function Engine.Open(title, beside, into)
	local g = ns.FindGuide(title)
	if not g then ns.Print("no guide called '%s'", title) return end
	for _, f in ipairs(Followers()) do
		local tabs, shown = f:Tabs()
		for i, tab in ipairs(tabs) do
			if tab.guide and ns.FindGuide(tab.guide) == g then
				SetActive(f)
				if i == shown then f:Load(title, 1) else f:SwitchTab(i) end
				return
			end
		end
	end
	local f = into or active
	if beside == "window" then f = Engine.NewWindow() end
	if not f or f.closed then return end
	SetActive(f)
	local tabs, shown = f:Tabs()
	if beside == true and tabs[shown].guide then
		table.insert(tabs, {})
		f.slot.tab = #tabs
	end
	f:Load(title, 1)
end

--- One step by hand (the window's arrows, the keybinds): the next or previous step meant for this character (its
--- condition holds), done or not. It pauses auto-advance (see Advance), so a finished step stays put; finishing an
--- unfinished one moves on as usual.
---@param dir integer  1 or -1
function Follower:Step(dir)
	local guide = self.guide
	if not guide then return end
	-- at the guide's end: back shows its last step again, next goes on to the following guide
	if self.ended then
		if dir > 0 then self:Continue() return end
		-- (the last step meant for this character: the guide's own last one may be for paladins only)
		for i = #guide.steps, 1, -1 do
			if Conditions.Eval(guide.steps[i].cond) and #guide.steps[i].goals > 0 then self.index = i break end
		end
		self.ended, self.paused = false, true
		self:Changed()
		return
	end
	local i = self.index + dir
	while guide.steps[i] do
		-- (a step with no lines only jumps elsewhere)
		if Conditions.Eval(guide.steps[i].cond) and #guide.steps[i].goals > 0 then
			self.index = i
			self.paused = true
			self:Changed()
			return
		end
		i = i + dir
	end
	-- next past the last step: the guide's end
	if dir > 0 then
		self.ended = true
		self:Changed()
	end
end

--- Whether you're back from the furthest step the guide has gone to (you went back with the arrows or the counter):
--- that step's number, or nil when you're on it (or past it).
---@return integer?
function Follower:Behind()
	if self.guide and not self.ended and self.index < self.reached then return self.reached end
	return nil
end

--- Straight to a step by its number (typed into the step counter), held there like a step chosen with the arrows.
---@param n integer
function Follower:GoTo(n)
	local guide = self.guide
	if not guide then return end
	self.index = math.max(1, math.min(math.floor(n), #guide.steps))
	self.ended, self.paused = false, true
	self:Changed()
end

--- Fast forward or back (right-click on the arrows, as in Zygor): forward to the next unfinished step, back to the
--- nearest earlier unfinished one (or the first step).
---@param dir integer  1 or -1
function Follower:Jump(dir)
	local guide = self.guide
	if not guide then return end
	if self.ended then self:Step(dir) return end
	if dir > 0 then
		self.paused = false
		local start = self.index
		self.index = math.min(self.index + 1, #guide.steps)
		self:Advance()
		if self.index ~= start then self:Changed() end
		return
	end
	local target
	for i = self.index - 1, 1, -1 do
		local applies, done = Engine.StepState(guide.steps[i])
		if applies and not done then target = i break end
	end
	if not target then
		for i = 1, self.index - 1 do
			if Conditions.Eval(guide.steps[i].cond) and #guide.steps[i].goals > 0 then target = i break end
		end
	end
	if not target then return end
	self.index = target
	self.paused = true
	self:Changed()
end

-- a step that turns done in front of the player stays a moment, so its last line's "done" effect is seen
function Follower:Update()
	local _, step = self:Current()
	if step and not self.lingering then
		local _, done = Engine.StepState(step)
		if not done then
			self.open = step
		elseif self.open == step then
			self.open, self.lingering = nil, true
			C_Timer.After(1, function()
				self.lingering = false
				self:Advance()
				ns:Fire("OBVIGUIDE_UPDATE")
			end)
		end
	end
	if not self.lingering then self:Advance() end
end

-- The active window's, for what follows one guide: the keybinds, the guide picker, Catchup, /og step.

--- The active window's guide, and its current step (none once the guide has ended).
---@return ObviGuideGuide?, ObviGuideStep?
function Engine.Current()
	local f = Engine.Active()
	if f then return f:Current() end
	return nil, nil
end

--- Whether the active window's guide is finished, and the title of the guide that follows it.
---@return boolean ended, string? nextTitle
function Engine.Ended()
	local f = Engine.Active()
	if f then return f:Ended() end
	return false, nil
end

function Engine.Continue()
	local f = Engine.Active()
	if f then f:Continue() end
end

--- Loads a guide in the active window's shown tab, at a step.
---@param title string
---@param step? integer
function Engine.Load(title, step)
	local f = Engine.Active()
	if f then f:Load(title, step) end
end

--- The active window's tabs, and which one is shown.
---@return ObviGuideTab[] tabs, integer shown
function Engine.Tabs()
	local f = Engine.Active()
	if f then return f:Tabs() end
	return {}, 1
end

---@param i integer
function Engine.SwitchTab(i)
	local f = Engine.Active()
	if f then f:SwitchTab(i) end
end

---@param i integer
function Engine.CloseTab(i)
	local f = Engine.Active()
	if f then f:CloseTab(i) end
end

---@param dir integer  1 or -1
function Engine.Step(dir)
	local f = Engine.Active()
	if f then f:Step(dir) end
end

---@return integer?
function Engine.Behind()
	local f = Engine.Active()
	if f then return f:Behind() end
	return nil
end

---@param n integer
function Engine.GoTo(n)
	local f = Engine.Active()
	if f then f:GoTo(n) end
end

---@param dir integer  1 or -1
function Engine.Jump(dir)
	local f = Engine.Active()
	if f then f:Jump(dir) end
end

--- Every window moves on past what's done (after a setting changed).
function Engine.Advance()
	for _, f in ipairs(Followers()) do f:Advance() end
end

--- Ticks off a 'confirm' goal (or any goal the window lets the player click), in its step (the active window's
--- step when not given).
---@param goal ObviGuideGoal
---@param step? ObviGuideStep
function Engine.Tick(goal, step)
	if not step then step = select(2, Engine.Current()) end
	local key = step and MarkKey(step, goal)
	if key then
		local marks = Marks(Engine.GuideOf(step, goal))
		marks[key] = not marks[key]
	end
	Engine.Update()
end

--- Every window's step checked against the game again, each moving on where it's done.
function Engine.Update()
	for _, f in ipairs(Followers()) do f:Update() end
	ns:Fire("OBVIGUIDE_UPDATE")
end

-- reached waypoints of 'goto' goals are marked as the player arrives (in any window's step)
local function CheckArrival()
	for _, f in ipairs(followers) do
		local _, step = f:Current()
		for _, g in ipairs(step and step.goals or {}) do
			---@cast step ObviGuideStep
			if g.kind == "goto" and g.point and Engine.IsVisible(g) and not Engine.IsComplete(g, step) then
				local d = Distance(g.point)
				if d and d <= (g.point.radius or 10) then
					Marks(f.guide)[MarkKey(step, g)] = true
					Engine.Update()
					return
				end
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
-- does: the NPC is noted when the window opens (its creature id, from the GUID's 6th field). In the active window's
-- step any such line; in another window's, one naming that NPC.
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
	for _, f in ipairs(followers) do
		local _, step = f:Current()
		for _, g in ipairs(step and step.goals or {}) do
			local id = g.target and g.target.id
			if g.closes == kind and Engine.IsVisible(g) and (id == who or (not id and f == active)) then
				Marks(f.guide)[MarkKey(step, g)] = true
			end
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
	for _, f in ipairs(followers) do
		local _, step = f:Current()
		for _, g in ipairs(step and step.goals or {}) do
			if g.kind == "hearth" and Engine.IsVisible(g) then Marks(f.guide)[MarkKey(step, g)] = true end
		end
	end
	Engine.Update()
end)

-- the guides the windows followed are picked up again once in the world, or when their pack adds them later (a pack
-- that hands over guides only after another addon has loaded its own)
local inWorld = false
local function Restore()
	if not inWorld or not ns.charDB then return end
	for _, f in ipairs(Followers()) do
		local tabs, shown = f:Tabs()
		local tab = tabs[shown]
		if not f.guide and tab and tab.guide and ns.FindGuide(tab.guide) then f:Load(tab.guide, tab.step) end
	end
end
ns:On("PLAYER_ENTERING_WORLD", function() inWorld = true Restore() end)
ns:On("OBVIGUIDE_GUIDES_ADDED", Restore)

C_Timer.NewTicker(0.5, CheckArrival)

--- What the engine makes of the active window's step, line by line, for /og step: each line's kind, whether it's
--- visible and done, its manual tick, and for a flight path line what every map asked lists for it (fresh from the game).
---@return string
function Engine.DebugStep()
	local g, step = Engine.Current()
	if not (g and step) then return "no step" end
	local out = { ("%s, step %d"):format(g.title, step.index) }
	local applies, done = Engine.StepState(step)
	local f, n = Engine.Active(), 0
	for i, o in ipairs(followers) do if o == f then n = i end end
	out[#out + 1] = ("applies %s, done %s, paused %s, window %d of %d"):format(tostring(applies), tostring(done),
		tostring(f and f.paused), n, #followers)
	for _, goal in ipairs(step.goals) do
		local key = MarkKey(step, goal)
		out[#out + 1] = ("- [%s] %s | visible %s, complete %s, ticked %s%s"):format(goal.kind, tostring(goal.text),
			tostring(Engine.IsVisible(goal)), tostring(Engine.IsComplete(goal, step)), tostring(key and Marks(g)[key]),
			goal.done and ", has a done condition" or "")
		if goal.kind == "accept" and goal.quest then
			local pre = PreOf(goal.quest, g)
			out[#out + 1] = ("  quest %d: can take %s, pre-quests all {%s} any {%s}%s"):format(goal.quest,
				tostring(Engine.CanTake(goal.quest)), pre and table.concat(pre.all, ", ") or "-",
				pre and table.concat(pre.any, ", ") or "-", _G["LibQuestieDB"] and "" or ", no QuestieDB")
			local DB = _G["LibQuestieDB"] ---@type table?
			if DB and DB.Quest then
				local raw = {}
				for _, p in ipairs(DB.Quest.preQuestSingle(goal.quest) or {}) do
					raw[#raw + 1] = ("%d (races %s, breadcrumb %s, for me %s, done %s)"):format(p,
						tostring(DB.Quest.requiredRaces(p)),
						tostring(DB.Quest.breadcrumbForQuestId(p)),
						tostring(Engine.ForMe(DB, p)), tostring(PreDone(p)))
				end
				local _, _, raceId = UnitRace("player")
				out[#out + 1] = ("  race %s (flag %s); single pre-quests: %s"):format(tostring(raceId),
					tostring(DB.Enum.raceMaskById[raceId]), #raw > 0 and table.concat(raw, "; ") or "none")
			end
		end
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
