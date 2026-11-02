-- Import: a guide Obvi Guide has loaded (its own format, RestedXP or Zygor), turned back into a draft, so it can be
-- edited, tested and exported like a recorded one. It works from Obvi Guide's guide model (what the window shows),
-- not from the guide's text: every step and line is written again as the builder calls that make the same model.
-- What the builder can't say is kept as a note "(not supported: ...)", never dropped. Plain Lua, no game API.
local _, ns = ...
---@cast ns ObviScribeNS

---@class ObviScribeModelGoal
---@field kind string
---@field text string
---@field [string] any

---@class ObviScribeModelStep
---@field goals ObviScribeModelGoal[]
---@field side ObviScribeModelGoal[]
---@field tips {text: string, after?: ObviScribeModelGoal}[]
---@field path {map: integer, x: number, y: number, radius?: number}[]
---@field dest? {map: integer, x: number, y: number, radius?: number}
---@field label? string
---@field cond? table
---@field skip? table
---@field [string] any

---@class ObviScribeModel
---@field title string
---@field group? string
---@field next? string
---@field cond? table
---@field steps ObviScribeModelStep[]

-- the colours Obvi Guide draws markers in (its Core.lua ns.Colors), back to the marker
local KIND_OF_COLOR = { ff00ff25 = "Npc", ffff5040 = "Mob", ff00bbff = "Item", ffdb7fff = "Object", ffffa500 = "Warn",
	ffffd100 = "Buy" }

-- model fields the builder writes itself (or parsers keep for their own use): not guide content
local STEP_FIELDS = { index = true, goals = true, side = true, tips = true, path = true, dest = true, label = true,
	cond = true, skip = true, target = true, untilStep = true, hasCompletable = true, talk = true, sideOf = true,
	mobs = true, condText = true, nexts = true, conds = true, sticky = true }
-- the goal fields each kind's line writes (besides kind, text and cond); any other is reported
local function Set(...) local t = {} for _, k in ipairs({ ... }) do t[k] = true end return t end
local GOAL_FIELDS = {
	talk = Set("id", "target"), accept = Set("quest", "target"), turnin = Set("quest", "target"),
	objective = Set("quest", "objective", "target"), kill = Set("quest", "objective", "count", "id", "mobName", "target"),
	collect = Set("id", "count", "quest", "objective", "target"), use = Set("id"), equip = Set("id"), cast = Set("id"),
	learn = Set("id"), hearth = Set("id"), home = Set(), level = Set("level", "xp"), skill = Set("skill", "level", "cap"),
	confirm = Set(), fly = Set(), text = Set(),
	killtext = Set("id", "count", "mobName", "target"),   -- a Kill line without a quest objective
}
local COMMON = Set("kind", "text", "cond")
-- how the builder words each kind's line
local VERBS = { collect = "Collect ", kill = "Kill ", use = "Use ", equip = "Equip ", cast = "Cast ", talk = "Talk to ",
	accept = "Accept ", turnin = "Turn in ", home = "Set your Hearthstone to ", level = "Reach level " }

---@alias ObviScribeIds table<string, table<string, integer>>   marker kind -> name -> id

-- ---------------------------------------------------------------------------------------------------------------
-- Text: "Kill |cffff5040Kobold|r" -> { "Kill ", g.Mob("Kobold", id) }

--- Rendered text back into plain strings and markers (ids from the names the guide uses elsewhere).
---@param text string
---@param ids ObviScribeIds
---@return any[]
local function Parts(text, ids)
	local parts = {}
	local function plain(s)
		if s == "" then return end
		if type(parts[#parts]) == "string" then parts[#parts] = parts[#parts] .. s else table.insert(parts, s) end
	end
	local function marker(kind, name)
		if kind == "Warn" or kind == "Buy" then table.insert(parts, { m = kind, parts = { name } }) return end
		table.insert(parts, { m = kind, name = name, id = ids[kind] and ids[kind][name] })
	end
	local pos = 1
	while true do
		local s = text:find("|[cT]", pos)
		if not s then plain(text:sub(pos)) break end
		plain(text:sub(pos, s - 1))
		-- an item or spell with its icon: |T...|t[name]
		local _, e, inner = text:find("^|T[^|]*|t%[(.-)%]", s)
		if e then
			local c, n = inner:match("^|c(%x%x%x%x%x%x%x%x)(.-)|r$")
			if c and KIND_OF_COLOR[c:lower()] then marker(KIND_OF_COLOR[c:lower()], n)
			elseif not inner:find("|", 1, true) then marker("Spell", inner)
			else plain(text:sub(s, e)) end
			pos = e + 1
		else
			local _, e2, c, n = text:find("^|c(%x%x%x%x%x%x%x%x)(.-)|r", s)
			if e2 and KIND_OF_COLOR[c:lower()] then
				marker(KIND_OF_COLOR[c:lower()], n)
				pos = e2 + 1
			else
				plain(text:sub(s, s + 1))
				pos = s + 2
			end
		end
	end
	return parts
end

--- The first marker in rendered text (a line's item or spell), or a marker with the plain text as its name.
---@param text string
---@param kind string
---@param ids ObviScribeIds
local function MarkerIn(text, kind, ids)
	for _, p in ipairs(Parts(text, ids)) do
		if type(p) == "table" and p.name then return { m = kind, name = p.name, id = p.id } end
	end
	return { m = kind, name = text, id = ids[kind] and ids[kind][text] }
end

local function Plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("[%[%]]", "")) end

--- The names the guide gives ids to, by kind, so markers found in text get their ids back.
---@param guide ObviScribeModel
---@return ObviScribeIds
local function Ids(guide)
	local ids = { Npc = {}, Mob = {}, Item = {}, Spell = {} }
	local function target(t)
		if t and t.name and t.id then ids[t.enemy and "Mob" or "Npc"][t.name] = ids[t.enemy and "Mob" or "Npc"][t.name] or t.id end
	end
	local function each(fn)
		for _, step in ipairs(guide.steps) do
			target(step.target)
			for _, g in ipairs(step.goals) do fn(g) end
			for _, g in ipairs(step.side) do fn(g) end
		end
	end
	each(function(g)
		target(g.target)
		for _, t in ipairs(g.targets or {}) do target(t) end
		if g.kind == "kill" and g.mobName and g.id then ids.Mob[g.mobName] = ids.Mob[g.mobName] or g.id end
	end)
	local ITEM, SPELL = { use = true, collect = true, equip = true }, { cast = true, learn = true }
	each(function(g)
		local kind = (ITEM[g.kind] and "Item") or (SPELL[g.kind] and "Spell")
		if kind and g.id then
			local name = Plain((g.text:gsub("^%a+ ", "")))
			ids[kind][name] = ids[kind][name] or g.id
		end
	end)
	return ids
end

-- ---------------------------------------------------------------------------------------------------------------
-- Conditions: trees back into the builder's words

local WORD = { onquest = true, ready = true, done = true, knows = true, area = true }

--- A condition tree as a condition string; an error for a test the builder has no word for.
---@param c table
---@return string
local function CondText(c)
	local op = c[1]
	local function wrap(sub)
		local s = CondText(sub)
		return (sub[1] == "and" or sub[1] == "or") and ("(" .. s .. ")") or s
	end
	if op == "and" or op == "or" then
		local out = {}
		for i = 2, #c do table.insert(out, wrap(c[i])) end
		return table.concat(out, " " .. op .. " ")
	elseif op == "not" then return "not " .. wrap(c[2])
	elseif op == "faction" or op == "class" or op == "race" then return tostring(c[2])
	elseif op == "level<" then return "level < " .. c[2]
	elseif op == "level>" then return "level > " .. c[2]
	elseif op == "items>=" then return ("items %d >= %d"):format(c[2], c[3])
	elseif op == "items<" then return ("items %d < %d"):format(c[2], c[3])
	elseif op == "nomap" then return "nomap"
	elseif op == "skill>=" then return ("skill %s >= %d"):format(c[2], c[3])
	elseif op == "skill<" then return ("skill %s < %d"):format(c[2], c[3])
	elseif WORD[op] then return op .. " " .. c[2]
	elseif op == "aura" and not c[3] then return "aura " .. c[2]
	elseif op == "map" then
		if #c == 2 then return "map " .. c[2] end
		local out = {}
		for i = 2, #c do table.insert(out, "map " .. c[i]) end
		return "(" .. table.concat(out, " or ") .. ")"
	end
	error(op, 0)
end

--- A condition as a string, or nil and a description of what can't be written.
---@param c? table
---@return string?, string?
local function Cond(c)
	if not c then return nil end
	local ok, s = pcall(CondText, c)
	if ok then return s end
	return nil, ("a condition with '%s'"):format(tostring(s))
end

-- ---------------------------------------------------------------------------------------------------------------
-- Goals -> lines

---@param what string
---@return ObviScribeLine
local function Unsupported(what) return { op = "Note", text = "(not supported: " .. what .. ")" } end

--- The goal a side task was copied from (the builder copies each side task into every step it is shown with).
local function Original(g)
	local mt = getmetatable(g)
	local base = mt and rawget(mt, "__index")
	return type(base) == "table" and base or g
end

--- Sets a line's text: plain text as `text`, text with markers in it as `parts`.
---@param line ObviScribeLine
---@param text string
---@param ids ObviScribeIds
---@return ObviScribeLine
local function WithText(line, text, ids)
	local parts = Parts(text, ids)
	if #parts == 1 and type(parts[1]) == "string" then line.text = parts[1]
	elseif #parts > 1 or type(parts[1]) == "table" then line.parts = parts end
	return line
end

---@param op ObviScribeOp
---@param text string
---@param ids ObviScribeIds
local function TextLine(op, text, ids) return WithText({ op = op }, text, ids) end

--- Simple values of model fields, for a note.
local function Show(v)
	if type(v) == "table" then
		if v.name then return tostring(v.name) end
		if v.map then return ("%s %.2f, %.2f"):format(v.map, (v.x or 0) * 100, (v.y or 0) * 100) end
		return "..."
	end
	return tostring(v)
end

--- One goal as draft lines (the line, then notes for what of it can't be written).
---@param g ObviScribeModelGoal
---@param ids ObviScribeIds
---@param dest? table   the step's spot: a line's own spot that is the same adds nothing
---@return ObviScribeLine[]
local function GoalLines(g, ids, dest)
	local k, text, line = g.kind, g.text or "", nil ---@type string, string, ObviScribeLine?
	if k == "talk" then
		local t = g.target or MarkerIn((text:gsub("^Talk to ", "")), "Npc", ids)
		line = { op = "Talk", name = t.name, id = t.id or g.id }
	elseif k == "accept" or k == "turnin" then
		local title = text:gsub(k == "accept" and "^Accept " or "^Turn in ", "") ---@type string?
		if title == "quest " .. tostring(g.quest) then title = nil end
		line = { op = k == "accept" and "Accept" or "Turnin", quest = g.quest, title = title }
	elseif k == "objective" then
		line = { op = "Quest", quest = g.quest, objective = g.objective }
		if text ~= ("Quest %s, objective %s"):format(tostring(g.quest), tostring(g.objective)) then WithText(line, text, ids) end
	elseif k == "kill" or (k == "text" and g.mobName) then
		line = { op = "Kill", name = g.mobName or (g.target and g.target.name) or Plain(text), id = g.id or (g.target and g.target.id),
			count = g.count or (k == "text" and tonumber(text:match("^Kill (%d+) ")) or nil),
			quest = k == "kill" and g.quest or nil, objective = k == "kill" and g.objective or nil }
	elseif k == "collect" then
		local item = MarkerIn((text:gsub("^Collect ", "")), "Item", ids)
		line = { op = "Collect", name = item.name, id = g.id or item.id, count = g.count ~= 1 and g.count or nil,
			quest = g.quest, objective = g.objective }
	elseif k == "use" or k == "equip" or k == "cast" or k == "learn" then
		local m = MarkerIn((text:gsub("^%a+ ", "")), (k == "cast" or k == "learn") and "Spell" or "Item", ids)
		line = { op = k:sub(1, 1):upper() .. k:sub(2), name = m.name, id = g.id or m.id }
	elseif k == "hearth" then
		line = { op = "Hearth", place = text:match("^Hearth to (.+)$") }
	elseif k == "home" then
		local place = text:match("to (.+)$")
		if place then line = { op = "Home", place = place } end
	elseif k == "fly" then
		line = { op = "Fly", place = text:match("^Fly to (.+)$") or Plain(text) }
	elseif k == "skill" then
		-- Train (learn the profession, or a rank: up to a cap) or Skill (reach a level), told apart by the text
		if g.cap or text:find("^Learn ") then line = { op = "Train", skill = g.skill, cap = g.cap }
		else line = { op = "Skill", skill = g.skill, level = g.level } end
	elseif k == "level" then
		line = { op = "Level", level = g.level, xp = g.xp }
	elseif k == "confirm" then
		line = TextLine("Do", text, ids)
	elseif k == "text" then
		line = TextLine("Say", text, ids)
	end
	local out = {}
	if not line then
		table.insert(out, Unsupported(("a '%s' line: %s"):format(k, Plain(text))))
		return out
	end
	local only, why = Cond(g.cond)
	line.only = only
	table.insert(out, line)
	if why then table.insert(out, Unsupported(why .. " on '" .. Plain(text) .. "'")) end
	-- the builder words these lines itself: other wording (Zygor's "Buy ..." for a collect line) can't be kept
	local verb = VERBS[k]
	if verb and text:sub(1, #verb) ~= verb then
		table.insert(out, Unsupported(("the wording '%s'"):format(Plain(text))))
	end
	for key, v in pairs(Original(g)) do
		local own = GOAL_FIELDS[(k == "text" and g.mobName) and "killtext" or k] or {}
		local fine = COMMON[key] or own[key] or (key == "targets" and #v <= 1)
			or (key == "point" and dest and v.map == dest.map and v.x == dest.x and v.y == dest.y)
		if not fine then table.insert(out, Unsupported(("%s = %s on '%s'"):format(key, Show(v), Plain(text)))) end
	end
	return out
end

-- ---------------------------------------------------------------------------------------------------------------
-- Steps

local AUTO_GOTO, AUTO_CONFIRM = "Go to the marked spot", "Continue when ready"

---@param p {map: integer, x: number, y: number, radius?: number}
---@param op "Goto"|"Path"
---@return ObviScribeLine
local function Point(p, op)
	return { op = op, map = p.map, x = p.x * 100, y = p.y * 100, radius = op == "Goto" and p.radius or nil }
end

--- A step's lines: notes before everything, the way (Path, Goto), then each goal with the notes that follow it.
---@param step ObviScribeModelStep
---@param ids ObviScribeIds
---@return ObviScribeStep
local function StepOf(step, ids)
	local lines = {}
	local function add(list) for _, l in ipairs(list) do table.insert(lines, l) end end
	local isGoal = {}
	for _, g in ipairs(step.goals) do isGoal[g] = true end
	-- the notes after a goal; nil: the notes before every goal (also those after something that isn't one of the
	-- step's goals, as older Obvi Guide builds had for a note after a Goto that followed a Path)
	local function tipsAfter(goal)
		for _, tip in ipairs(step.tips) do
			local after = isGoal[tip.after] and tip.after or nil
			if after == goal then table.insert(lines, TextLine("Note", tip.text, ids)) end
		end
	end
	-- the goals the builder adds by itself: arriving (a step that is only travel) and "Continue when ready"
	local autoGoto, autoConfirm
	for i, g in ipairs(step.goals) do
		if g.kind == "goto" and g.text == AUTO_GOTO and step.dest and g.point == step.dest then autoGoto = g end
		if g.kind == "confirm" and g.text == AUTO_CONFIRM and i == #step.goals and not g.cond and #step.goals > 1 then autoConfirm = g end
	end
	tipsAfter(nil)
	for _, p in ipairs(step.path or {}) do table.insert(lines, Point(p, "Path")) end
	if step.dest then
		local l = Point(step.dest, "Goto")
		if autoGoto then
			local only, why = Cond(autoGoto.cond)
			l.only = only
			table.insert(lines, l)
			if why then table.insert(lines, Unsupported(why .. " on the step's spot")) end
			tipsAfter(autoGoto)
		else
			table.insert(lines, l)
		end
	end
	for _, g in ipairs(step.goals) do
		if g ~= autoGoto and g ~= autoConfirm then
			if g.kind == "goto" then
				table.insert(lines, Unsupported("another spot to go to, " .. Show(g.point)))
			else
				add(GoalLines(g, ids, step.dest))
			end
			tipsAfter(g)
		end
	end
	-- a step with nothing else keeps its "Continue when ready", so it stays a step
	if #lines == 0 then table.insert(lines, { op = "Do", text = AUTO_CONFIRM }) end

	local out = { lines = lines, label = step.label } ---@type ObviScribeStep
	local why
	out.only, why = Cond(step.cond)
	if why then table.insert(lines, 1, Unsupported(why .. " on the step")) end
	out.skip, why = Cond(step.skip)
	if why then table.insert(lines, 1, Unsupported(why .. " as the step's skip")) end
	for key, v in pairs(step) do
		if not STEP_FIELDS[key] then
			table.insert(lines, Unsupported(("the step's %s (%s)"):format(key, type(v) == "table" and (#v .. " of them") or tostring(v))))
		end
	end
	return out
end

--- A guide from Obvi Guide's model as a draft. Side tasks become side boxes again: one box for the tasks shown
--- from the same step to the same step without a break, lasting until "next" or the label of its last step (given
--- one if needed). A task shown again after a break (a Zygor sticky stopped and started again) gets another box.
---@param guide ObviScribeModel
---@return ObviScribeDraft
function ns.FromModel(guide)
	local ids = Ids(guide)
	local steps = guide.steps
	-- each side task's runs: from the first to the last step it is shown with, without a break
	local open, order = {}, {} ---@type table<table, table>, table[]
	for i, step in ipairs(steps) do
		for _, g in ipairs(step.side) do
			local o = Original(g)
			local r = open[o]
			if not r or r.last ~= i - 1 then
				r = { first = i, last = i, goal = g }
				open[o] = r
				table.insert(order, r)
			end
			r.last = i
		end
	end
	local boxes = {} ---@type table<integer, {key: string, untilStep: string, goals: table[]}[]>   first step -> boxes
	local byKey = {}
	local labels = {} ---@type table<integer, string>   labels the boxes need on steps that have none
	for _, r in ipairs(order) do
		local key = r.first .. ":" .. r.last
		local box = byKey[key]
		if not box then
			local untilStep = "next"
			if r.last > r.first then
				untilStep = steps[r.last].label or labels[r.last] or ("side until " .. r.last)
				if not steps[r.last].label then labels[r.last] = untilStep end
			end
			box = { key = key, untilStep = untilStep, goals = {} }
			byKey[key] = box
			boxes[r.first] = boxes[r.first] or {}
			table.insert(boxes[r.first], box)
		end
		table.insert(box.goals, r.goal)
	end

	local d = { name = guide.title, steps = {}, group = guide.group, next = guide.next } ---@type ObviScribeDraft
	local why
	d.only, why = Cond(guide.cond)
	for i, step in ipairs(steps) do
		-- (a note in a side box would be a side task of its own: what a side task can't say goes into the step)
		local sideNotes = {}
		for _, box in ipairs(boxes[i] or {}) do
			local lines = {}
			for _, g in ipairs(box.goals) do
				for _, l in ipairs(GoalLines(g, ids)) do
					if l.op == "Note" and l.text and l.text:find("^%(not supported: ") then
						l.text = "(not supported in a side task: " .. l.text:sub(#"(not supported: " + 1)
						table.insert(sideNotes, l)
					else
						table.insert(lines, l)
					end
				end
			end
			table.insert(d.steps, { lines = lines, side = box.untilStep })
		end
		local s = StepOf(step, ids)
		s.label = s.label or labels[i]
		for _, l in ipairs(sideNotes) do table.insert(s.lines, l) end
		table.insert(d.steps, s)
	end
	if why and d.steps[1] then table.insert(d.steps[1].lines, 1, Unsupported(why .. " on the guide")) end
	return d
end
