-- Recorder: while recording, what the player does goes into the draft as builder lines. Quests accepted and turned
-- in (at the NPC, with where the player stood), quest objectives completed, flight paths learned, the hearthstone
-- bound and used. Actions at the same NPC, close together, share a step. Only what the builder can say is recorded.
local _, ns = ...
---@cast ns ObviScribeNS

---@class ObviScribeRecorder
local Recorder = {}
ns.Recorder = Recorder

local NEAR = 10            -- yards: an action further from the step's spot than this starts a new step
local NPC_MEMORY = 10      -- seconds the last NPC talked to is remembered (the quest window may close first)
local HEARTHSTONE_SPELL = 8690
local isSecret = _G["issecretvalue"] ---@type (fun(v: any): boolean)?

---@class ObviScribeNpc
---@field name? string
---@field id? integer
---@field object? boolean   a quest object rather than a creature: the quest only, no Talk line

local lastNpc ---@type ObviScribeNpc?
local lastNpcTime = 0
local snapshot = {} ---@type table<integer, {finished: boolean, n: integer}[]>   quest -> its objectives last seen
local started = {} ---@type table<integer, {map: integer, x: number, y: number}>   where a quest's progress began
local titles = {} ---@type table<integer, string>

--- Whether recording is on.
---@return boolean
function Recorder.IsOn() return ns.db and ns.db.recording or false end

--- Where the player is: map and 0-100 coordinates (nothing in an instance).
---@return integer? map, number? x, number? y
local function Here()
	local map = C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	if not (map and pos) then return nil end
	local x, y = pos:GetXY()
	-- two decimals, as the map shows them and guides write them
	return map, math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100
end

Recorder.Here = Here

--- Yards between two map spots, or nil when they are not on the same continent.
---@return number?
local function Distance(map1, x1, y1, map2, x2, y2)
	local c1, w1 = C_Map.GetWorldPosFromMapPos(map1, CreateVector2D(x1 / 100, y1 / 100))
	local c2, w2 = C_Map.GetWorldPosFromMapPos(map2, CreateVector2D(x2 / 100, y2 / 100))
	if not (w1 and w2) or c1 ~= c2 then return nil end
	local dx, dy = w1.x - w2.x, w1.y - w2.y
	return math.sqrt(dx * dx + dy * dy)
end

--- Who the player is talking to: a creature (name and id from its GUID), an object, or nil.
---@return ObviScribeNpc?
local function LiveNpc()
	if not UnitExists("npc") then return nil end
	local name, guid = UnitName("npc"), UnitGUID("npc")
	if isSecret and (isSecret(name) or isSecret(guid)) then return nil end
	if type(guid) ~= "string" then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	if kind == "Creature" or kind == "Vehicle" then return { name = name, id = tonumber(id) } end
	return { object = true }
end

local function RememberNpc()
	local npc = LiveNpc()
	if npc then lastNpc, lastNpcTime = npc, GetTime() end
end

--- The NPC an action happens at: the one talked to now, or a moment ago.
---@return ObviScribeNpc?
local function Npc()
	local npc = LiveNpc()
	if npc then return npc end
	if lastNpc and GetTime() - lastNpcTime <= NPC_MEMORY then return lastNpc end
end

---@param step ObviScribeStep
---@return ObviScribeLine?
local function GotoOf(step)
	for i = #step.lines, 1, -1 do if step.lines[i].op == "Goto" then return step.lines[i] end end
end

--- The step an action goes in: the last one when it is at the same NPC and close by (or an empty one made with
--- "New step"); otherwise a new step here, with a Goto and (at a creature) a Talk line.
---@param npc? ObviScribeNpc
---@return ObviScribeStep
local function StepFor(npc)
	local d = ns.Draft()
	local key = npc and not npc.object and (npc.id and tostring(npc.id) or npc.name) or ""
	local map, x, y = Here()
	local step = d.steps[#d.steps] ---@type ObviScribeStep?
	if step and #step.lines > 0 then
		local near = true
		local at = GotoOf(step)
		if at and map then near = (Distance(at.map, at.x, at.y, map, x, y) or math.huge) <= NEAR end
		if not step.closed and not step.quest and step.npc == key and near then return step end
		step = nil
	end
	if not step then
		step = { lines = {} }
		table.insert(d.steps, step)
	end
	step.npc = key
	if map then table.insert(step.lines, { op = "Goto", map = map, x = x, y = y }) end
	if npc and npc.name and not npc.object then table.insert(step.lines, { op = "Talk", name = npc.name, id = npc.id }) end
	return step
end

---@param step ObviScribeStep
---@param line ObviScribeLine
local function Add(step, line)
	-- the same action twice in a row (an event fired twice) is written once
	local last = step.lines[#step.lines]
	if last and last.op == line.op and last.quest == line.quest and last.objective == line.objective and last.text == line.text
		and last.place == line.place and line.op ~= "Note" then return end
	table.insert(step.lines, line)
	ns.Changed(true)
end

---@param quest integer
---@return string?
local function Title(quest)
	return titles[quest] or C_QuestLog.GetTitleForQuestID(quest)
end

--- "Kobold Vermin slain: 3/10" -> "Kobold Vermin slain"
---@param s? string
---@return string
local function Clean(s)
	s = (s or ""):gsub("%d+%s*/%s*%d+", ""):gsub("^[%s:]+", ""):gsub("[%s:]+$", "")
	return s
end

--- A quest objective completed: into the step of that quest's objectives (a new one, where its progress began).
---@param quest integer
---@param index integer
---@param text? string
local function Objective(quest, index, text)
	local d = ns.Draft()
	local step
	for i = #d.steps, 1, -1 do if d.steps[i].quest == quest then step = d.steps[i] break end end
	if not step then
		step = { lines = {}, quest = quest }
		local at = started[quest]
		local map, x, y = Here()
		if at then map, x, y = at.map, at.x, at.y end
		if map then table.insert(step.lines, { op = "Goto", map = map, x = x, y = y }) end
		table.insert(d.steps, step)
	end
	Add(step, { op = "Quest", quest = quest, objective = index, text = Clean(text) })
end

--- Compares every quest's objectives with how they were last seen. Quests seen for the first time are only noted
--- (an objective already done when a quest is accepted was not done here).
---@param record boolean
local function Scan(record)
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		local quest = info and not info.isHeader and not info.isHidden and info.questID
		if info and quest and quest > 0 then
			titles[quest] = info.title
			local old, new = snapshot[quest], {}
			for k, o in ipairs(C_QuestLog.GetQuestObjectives(quest) or {}) do
				local n = o.numFulfilled or 0
				new[k] = { finished = o.finished and true or false, n = n }
				local was = old and old[k]
				if record and was then
					if n > was.n and not started[quest] then
						local map, x, y = Here()
						if map and x and y then started[quest] = { map = map, x = x, y = y } end
					end
					if new[k].finished and not was.finished then Objective(quest, k, o.text) end
				end
			end
			snapshot[quest] = new
		end
	end
end

--- Recording on or off.
function Recorder.Toggle()
	ns.db.recording = not ns.db.recording
	if ns.db.recording then
		wipe(snapshot)
		wipe(started)
		Scan(false)
		ns.Print("recording into '%s'", ns.Draft().name)
	else
		ns.Print("recording stopped")
	end
	ns.Changed()
end

--- A step that is only a place to go: the player's spot.
function Recorder.GotoHere()
	local map, x, y = Here()
	if not map then ns.Print("no map position here") return end
	local d = ns.Draft()
	local step = d.steps[#d.steps]
	if not step or #step.lines > 0 then
		step = { lines = {} }
		table.insert(d.steps, step)
	end
	step.lines[1] = { op = "Goto", map = map, x = x, y = y }
	step.closed = true
	ns.Changed(true)
end

--- A note on the last step.
---@param text string
function Recorder.Note(text)
	if not text or text:match("^%s*$") then return end
	local d = ns.Draft()
	local step = d.steps[#d.steps]
	if not step then step = StepFor(nil) end
	Add(step, { op = "Note", text = text })
end

for _, event in ipairs({ "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
	"TAXIMAP_OPENED", "MERCHANT_SHOW" }) do
	ns:On(event, RememberNpc)
end

-- (Forever and retail pass the quest id; older clients passed the log index first)
ns:On("QUEST_ACCEPTED", function(_, a, b)
	if not Recorder.IsOn() then return end
	local quest = b or a
	Add(StepFor(Npc()), { op = "Accept", quest = quest, title = Title(quest) })
	Scan(false)
end)

ns:On("QUEST_TURNED_IN", function(_, quest)
	if not Recorder.IsOn() then return end
	Add(StepFor(Npc()), { op = "Turnin", quest = quest, title = Title(quest) })
	snapshot[quest], started[quest] = nil, nil
end)

ns:On("QUEST_LOG_UPDATE", function() if Recorder.IsOn() then Scan(true) end end)
ns:On("UNIT_QUEST_LOG_CHANGED", function(_, unit) if unit == "player" and Recorder.IsOn() then Scan(true) end end)

-- a flight path learned: the builder has no flight-path line, so a line to tick off at the flight master
ns:On("UI_INFO_MESSAGE", function(_, _, message)
	if not Recorder.IsOn() or message ~= _G["ERR_NEWTAXIPATH"] then return end
	Add(StepFor(Npc()), { op = "Do", text = "Get the flight path" })
end)

ns:On("HEARTHSTONE_BOUND", function()
	if not Recorder.IsOn() then return end
	local place = GetBindLocation()
	if place and place ~= "" then Add(StepFor(Npc()), { op = "Home", place = place }) end
end)

-- the hearthstone used: a step of its own (no Goto: the player is where they left from)
ns:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spell)
	if unit ~= "player" or not Recorder.IsOn() or (isSecret and isSecret(spell)) or spell ~= HEARTHSTONE_SPELL then return end
	local d = ns.Draft()
	local step = d.steps[#d.steps]
	if not step or #step.lines > 0 then
		step = { lines = {} }
		table.insert(d.steps, step)
	end
	step.closed = true
	Add(step, { op = "Hearth", place = GetBindLocation() })
end)

ns:On("PLAYER_LOGIN", function() if Recorder.IsOn() then Scan(false) end end)
