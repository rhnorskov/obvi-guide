-- Builder: ObviGuide's own guide format. A guide pack calls ObviGuide.Guide(function(g) ... end) and fills the guide in
-- with Lua calls (docs/api.lua has the API, docs/FORMAT.md what it means). The calls are recorded as written, then
-- turned into the same neutral model the RestedXP reader makes, so guides in either format show and behave alike.
local _, ns = ...
---@cast ns ObviGuideNS

local Conditions = ns.Conditions
local Colors = ns.Colors
local HEARTHSTONE = 6948   -- item id

-- ---------------------------------------------------------------------------------------------------------------
-- Conditions: "Alliance and not Shaman", "Horde/Shaman", "level >= 10", "items 123 < 5" -> condition trees

-- words followed by one id, and the test they make
local ID_WORDS = { onquest = "onquest", ready = "ready", done = "done", knows = "knows", area = "area", map = "map",
	aura = "aura" }

---@param s string
---@return string[]? tokens, string? err
local function Tokens(s)
	local list, pos = {}, 1
	while pos <= #s do
		local _, e = s:find("^%s+", pos)
		if e then
			pos = e + 1
		else
			local tok = s:match("^[()/]", pos) or s:match("^[<>]=?", pos) or s:match("^%d+", pos) or s:match("^%a+", pos)
			if not tok then return nil, ("unexpected '%s'"):format(s:sub(pos, pos)) end
			table.insert(list, tok)
			pos = pos + #tok
		end
	end
	return list
end

--- A condition string as a condition tree, or nil and what is wrong with it.
---@param s string
---@return ObviGuideCond?, string?
local function Compile(s)
	local toks, err = Tokens(s)
	if not toks then return nil, err end
	local i = 1
	local function peek() return toks[i] and toks[i]:lower() end
	local function take() i = i + 1 return toks[i - 1] end
	local function number()
		local n = tonumber(toks[i] or "")
		if not n then error(("a number is missing after '%s'"):format(toks[i - 1] or ""), 0) end
		i = i + 1
		return n
	end
	-- a count compared with < <= > >=, as the "less than" or "at least" tests the engine has
	local function compare(what)
		local op = take()
		if not (op == "<" or op == "<=" or op == ">" or op == ">=") then error(what .. " needs <, <=, > or >= and a number", 0) end
		local n = number()
		if op == "<" then return "<", n elseif op == "<=" then return "<", n + 1
		elseif op == ">=" then return ">=", n else return ">=", n + 1 end
	end
	local Or
	local function Atom()
		local tok = take()
		if not tok then error("it ends too early", 0) end
		local w = tok:lower()
		if w == "(" then
			local c = Or()
			if take() ~= ")" then error("a ')' is missing", 0) end
			return c
		end
		if w == "not" then return { "not", Atom() } end
		if w == "alliance" or w == "horde" then return { "faction", w == "alliance" and "Alliance" or "Horde" } end
		if w == "nomap" then return { "nomap" } end
		if ID_WORDS[w] then return { ID_WORDS[w], number() } end
		if w == "level" then
			local op, n = compare("level")
			return op == "<" and { "level<", n } or { "level>", n - 1 }
		end
		if w == "items" then
			local id = number()
			local op, n = compare("items")
			return { "items" .. op, id, n }
		end
		local class = Conditions.ClassToken(tok)
		if class then return { "class", class } end
		if Conditions.RACES[w] then return { "race", w == "undead" and "scourge" or w } end
		error(("unknown word '%s'"):format(tok), 0)
	end
	local function And()
		local c = { "and", Atom() }
		while peek() == "and" do take() table.insert(c, Atom()) end
		return #c == 2 and c[2] or c
	end
	Or = function()
		local c = { "or", And() }
		while peek() == "or" or peek() == "/" do take() table.insert(c, And()) end
		return #c == 2 and c[2] or c
	end
	local ok, res = pcall(function()
		local c = Or()
		if toks[i] then error(("unexpected '%s'"):format(toks[i]), 0) end
		return c
	end)
	if not ok then return nil, tostring(res) end
	return res
end

---@class ObviGuideBuildContext
---@field title string
---@field reported table<string, boolean>   bad condition strings already reported

--- A condition from the guide; a bad one is reported (once) and then ignored, so it never hides anything.
---@param s any
---@param ctx ObviGuideBuildContext
---@return ObviGuideCond?
local function Cond(s, ctx)
	if s == nil or s == "" then return nil end
	local c, err
	if type(s) == "string" then c, err = Compile(s) else err = "not a string" end
	if not c then
		local key = tostring(s)
		if not ctx.reported[key] then
			ctx.reported[key] = true
			ns.Print("%s: can't read the condition \"%s\" (%s); it is ignored", ctx.title, key, err or "?")
		end
	end
	return c
end

-- ---------------------------------------------------------------------------------------------------------------
-- Markers: what a word in the text is (an NPC, an item...), drawn in the colours RestedXP guides use

---@class ObviGuideMarkerImpl
---@field kind "npc"|"mob"|"item"|"spell"|"object"|"warn"|"buy"
---@field name string
---@field id? integer
---@field parts? any[]   for warn and buy: their text

local MARKER_COLOR = { npc = Colors.FRIENDLY, mob = Colors.ENEMY, item = Colors.LOOT, object = Colors.PICK,
	warn = Colors.WARN, buy = Colors.BUY }

local Marker = {}

local function IsMarker(v) return getmetatable(v) == Marker end

---@param m ObviGuideMarkerImpl
---@return string
local function Render(m)
	local color = MARKER_COLOR[m.kind]
	if m.parts then
		-- each plain piece in the marker's colour; markers inside keep their own (colour codes don't nest)
		local out = {}
		for _, p in ipairs(m.parts) do
			if IsMarker(p) then table.insert(out, Render(p))
			elseif tostring(p) ~= "" then table.insert(out, "|c" .. color .. tostring(p) .. "|r") end
		end
		return table.concat(out)
	end
	-- the written name for now; the game's own name by id (in the player's language) comes later
	local name = color and ("|c" .. color .. m.name .. "|r") or m.name
	local icon
	if m.id and m.kind == "item" then icon = C_Item.GetItemIconByID(m.id)
	elseif m.id and m.kind == "spell" then icon = C_Spell.GetSpellTexture(m.id) end
	if icon then return "|T" .. icon .. ":0|t[" .. name .. "]" end
	return name
end
Marker.__tostring = Render

---@return ObviGuideMarkerImpl
local function NewMarker(kind, name, id)
	if type(name) ~= "string" then error(("a %s needs a name"):format(kind), 3) end
	return setmetatable({ kind = kind, name = name, id = tonumber(id) }, Marker)
end

---@return ObviGuideMarkerImpl
local function TextMarker(kind, ...)
	return setmetatable({ kind = kind, name = "", parts = { ... } }, Marker)
end

--- Text arguments joined, and the first enemy they name (a line about it targets it).
---@return string text, ObviGuideMarkerImpl? mob
local function Text(...)
	local out, mob = {}, nil
	local function walk(n, ...)
		for k = 1, n do
			local v = select(k, ...)
			if IsMarker(v) then
				table.insert(out, Render(v))
				if v.kind == "mob" then mob = mob or v end
				if v.parts and not mob then
					local _, inner = Text(unpack(v.parts))
					mob = inner
				end
			elseif v ~= nil then
				table.insert(out, tostring(v))
			end
		end
	end
	walk(select("#", ...), ...)
	return table.concat(out), mob
end

--- The marker a line needs (g.Npc(...) for Talk...); a plain name will do too.
---@return ObviGuideMarkerImpl
local function Need(v, kind, line)
	if IsMarker(v) then return v end
	if type(v) == "string" then return NewMarker(kind, v) end
	error(("%s needs a name or a marker such as g.%s(...)"):format(line, kind:sub(1, 1):upper() .. kind:sub(2)), 3)
end

-- ---------------------------------------------------------------------------------------------------------------
-- The builders guide packs fill in. Lines are only recorded here; Finish turns them into the model.

---@class ObviGuideLineImpl
---@field op string          the method that made it ("Goto", "Talk", ...)
---@field only? any          its condition, as written
---@field text? string
---@field mob? ObviGuideMarkerImpl
---@field marker? ObviGuideMarkerImpl
---@field [string] any

local LineMT = { __index = {} }
function LineMT.__index:Only(cond)
	self.only = cond
	return self
end

---@class ObviGuideLinesImpl
---@field only? any
---@field label? string
---@field skip? any
---@field _lines ObviGuideLineImpl[]

local Lines = {}
local LinesMT = { __index = Lines }

---@param self ObviGuideLinesImpl
---@return ObviGuideLineImpl
local function Add(self, line)
	table.insert(self._lines, setmetatable(line, LineMT))
	return line
end

function Lines:Goto(map, x, y, radius)
	return Add(self, { op = "Goto", map = map, x = x, y = y, radius = radius })
end
function Lines:Path(map, x, y) return Add(self, { op = "Path", map = map, x = x, y = y }) end
function Lines:Talk(npc) return Add(self, { op = "Talk", marker = Need(npc, "npc", "Talk") }) end
function Lines:Accept(quest, title) return Add(self, { op = "Accept", quest = quest, title = title }) end
function Lines:Turnin(quest, title) return Add(self, { op = "Turnin", quest = quest, title = title }) end
function Lines:Quest(quest, objective, ...)
	local text, mob = Text(...)
	return Add(self, { op = "Quest", quest = quest, objective = objective, text = text, mob = mob })
end
function Lines:Kill(mob, options) return Add(self, { op = "Kill", marker = Need(mob, "mob", "Kill"), options = options or {} }) end
function Lines:Collect(item, options)
	return Add(self, { op = "Collect", marker = Need(item, "item", "Collect"), options = options or {} })
end
function Lines:Use(item) return Add(self, { op = "Use", marker = Need(item, "item", "Use") }) end
function Lines:Equip(item) return Add(self, { op = "Equip", marker = Need(item, "item", "Equip") }) end
function Lines:Cast(spell) return Add(self, { op = "Cast", marker = Need(spell, "spell", "Cast") }) end
function Lines:Learn(spell) return Add(self, { op = "Learn", marker = Need(spell, "spell", "Learn") }) end
function Lines:Hearth(place) return Add(self, { op = "Hearth", place = place }) end
function Lines:Home(place) return Add(self, { op = "Home", place = place }) end
function Lines:Fly(place) return Add(self, { op = "Fly", place = place }) end
function Lines:Level(level, xp) return Add(self, { op = "Level", level = level, xp = xp }) end
function Lines:Do(...) local text, mob = Text(...) return Add(self, { op = "Do", text = text, mob = mob }) end
function Lines:Say(...) local text, mob = Text(...) return Add(self, { op = "Say", text = text, mob = mob }) end
function Lines:Note(...) local text, mob = Text(...) return Add(self, { op = "Note", text = text, mob = mob }) end

---@class ObviGuideGuideImpl
---@field title? string
---@field group? string
---@field next? string
---@field id? string
---@field only? any
---@field _items {lines: ObviGuideLinesImpl, untilStep?: string}[]   steps and side boxes, in order

local Guide = {}
local GuideMT = { __index = Guide }

function Guide:Step(build)
	local s = setmetatable({ _lines = {} }, LinesMT)
	build(s)
	table.insert(self._items, { lines = s })
end

function Guide:Side(untilStep, build)
	if type(untilStep) ~= "string" then error("g:Side needs the label of the step it lasts until (or \"next\")", 2) end
	local s = setmetatable({ _lines = {} }, LinesMT)
	build(s)
	table.insert(self._items, { lines = s, untilStep = untilStep })
end

function Guide.Npc(name, id) return NewMarker("npc", name, id) end
function Guide.Mob(name, id) return NewMarker("mob", name, id) end
function Guide.Item(name, id) return NewMarker("item", name, id) end
function Guide.Spell(name, id) return NewMarker("spell", name, id) end
function Guide.Object(name) return NewMarker("object", name) end
function Guide.Warn(...) return TextMarker("warn", ...) end
function Guide.Buy(...) return TextMarker("buy", ...) end

-- ---------------------------------------------------------------------------------------------------------------
-- Recorded lines -> the model, as the RestedXP reader builds it for the same lines

-- lines a step waits for (as RestedXP's reader counts them; arriving at a goto counts only on its own)
local COMPLETABLE = { accept = true, turnin = true, objective = true, kill = true, collect = true, equip = true,
	cast = true, learn = true, level = true, home = true, hearth = true, confirm = true }

---@param m ObviGuideMarkerImpl
---@param enemy? boolean
local function TargetOf(m, enemy)
	return { name = m.name, id = m.id, enemy = enemy or nil }
end

--- One line -> a goal (nil for goto, path and note lines, which the step handles itself).
---@param l ObviGuideLineImpl
---@return ObviGuideGoal?
local function Goal(l)
	local op, m = l.op, l.marker --[[@as ObviGuideMarkerImpl]]   -- the lines that use it always have one
	if op == "Talk" then
		return { kind = "talk", id = m.id, text = "Talk to " .. Render(m), target = TargetOf(m) }
	elseif op == "Accept" or op == "Turnin" then
		local verb = op == "Accept" and "Accept " or "Turn in "
		return { kind = op:lower(), quest = l.quest, text = verb .. (l.title or ("quest " .. tostring(l.quest))) }
	elseif op == "Quest" then
		-- the objective's own text needs the quest in the log; until that is looked up, a stand-in
		local text = l.text ~= "" and l.text or ("Quest %s, objective %s"):format(tostring(l.quest), tostring(l.objective))
		return { kind = "objective", quest = l.quest, objective = l.objective or 1, text = text }
	elseif op == "Kill" then
		local o = l.options
		if o.quest then
			return { kind = "kill", quest = o.quest, objective = o.objective or 1, count = o.count, id = m.id,
				mobName = m.name, text = "Kill " .. Render(m), target = TargetOf(m, true) }
		end
		-- without a quest objective nothing tells when it's done: a line that only targets
		local text = (o.count and ("Kill %d "):format(o.count) or "Kill ") .. Render(m)
		return { kind = "text", id = m.id, mobName = m.name, text = text, target = TargetOf(m, true) }
	elseif op == "Collect" then
		local o = l.options
		if not (m.id or o.objective) then return { kind = "confirm", text = "Collect " .. Render(m) } end
		return { kind = "collect", id = m.id, count = o.count or 1, quest = o.quest, objective = o.objective,
			text = "Collect " .. Render(m) }
	elseif op == "Use" then
		return { kind = "use", id = m.id, text = "Use " .. Render(m) }
	elseif op == "Equip" or op == "Cast" or op == "Learn" then
		-- these are checked by id; without one the player ticks them off
		return { kind = m.id and op:lower() or "confirm", id = m.id, text = op .. " " .. Render(m) }
	elseif op == "Hearth" then
		return { kind = "hearth", id = HEARTHSTONE, text = l.place and ("Hearth to " .. l.place) or "Use your Hearthstone" }
	elseif op == "Home" then
		-- the engine compares the place after "to" with the game's bind location
		return { kind = "home", text = "Set your Hearthstone to " .. tostring(l.place) }
	elseif op == "Fly" then
		return { kind = "confirm", text = "Fly to " .. tostring(l.place) }
	elseif op == "Level" then
		return { kind = "level", level = l.level, xp = l.xp, text = "Reach level " .. tostring(l.level) }
	elseif op == "Do" then
		return { kind = "confirm", text = l.text }
	elseif op == "Say" then
		return { kind = "text", text = l.text }
	end
end

---@class ObviGuideBuiltStep : ObviGuideStep
---@field untilStep? string   for a side box: the label of the step it lasts until ("next": the next step)

--- A step's (or side box's) lines -> a step.
---@param lines ObviGuideLinesImpl
---@param untilStep? string
---@param ctx ObviGuideBuildContext
---@return ObviGuideBuiltStep
local function BuildStep(lines, untilStep, ctx)
	---@type ObviGuideBuiltStep
	local step = { index = 0, goals = {}, side = {}, tips = {}, path = {}, label = lines.label, untilStep = untilStep }
	local hasCompletable = false
	local last          -- the line a note follows: the last goal, or a goto line's stand-in (its goal comes below)
	local talk          -- the NPC of the last Talk line, which accept and turn-in lines target
	local firstTalk     -- the step's NPC
	local firstMob      -- the first enemy the step names
	local points, isPoint = {}, {} ---@type table[], table<any, table>
	for _, l in ipairs(lines._lines) do
		local cond = Cond(l.only, ctx)
		local goal
		if l.op == "Goto" or l.op == "Path" then
			local p = { map = l.map, x = (tonumber(l.x) or 0) / 100, y = (tonumber(l.y) or 0) / 100, radius = l.radius }
			local pt = { p = p, path = l.op == "Path", cond = cond, prev = isPoint[last] and isPoint[last].prev or last }
			table.insert(points, pt)
			isPoint[pt] = pt
			last = pt
		elseif l.op == "Note" and not cond and not untilStep then
			table.insert(step.tips, { text = l.text, after = last })
		elseif l.op == "Note" then
			-- a note with a condition is a line of its own, as RestedXP's reader does it; so is any note in a side
			-- box, as the window shows side boxes without notes
			goal = { kind = "text", text = l.text }
		else
			goal = Goal(l)
		end
		if goal then
			goal.cond = cond
			if (goal.kind == "accept" or goal.kind == "turnin") and talk then goal.target = talk end
			if goal.kind == "talk" then
				talk = goal.target
				firstTalk = firstTalk or goal.target
			end
			if (goal.kind == "objective" or goal.kind == "collect") and l.mob then goal.target = TargetOf(l.mob, true) end
			table.insert(step.goals, goal)
			last = goal
			if COMPLETABLE[goal.kind] then hasCompletable = true end
		end
		firstMob = firstMob or (l.marker and l.marker.kind == "mob" and l.marker) or l.mob
	end

	-- who the action key targets: the step's NPC, else the first thing it kills, else the first enemy it names
	if firstTalk then
		step.target = firstTalk
	else
		for _, g in ipairs(step.goals) do
			if g.mobName then step.target = g.target break end
		end
		if not step.target and firstMob then step.target = TargetOf(firstMob, true) end
	end
	for _, g in ipairs(step.goals) do
		if not g.target and (g.kind == "objective" or g.kind == "collect" or g.kind == "accept" or g.kind == "turnin") then
			g.target = step.target
		end
	end

	-- destination: the last Goto; earlier ones and Path lines are points along the way
	local dest
	for _, pt in ipairs(points) do if not pt.path then dest = pt end end
	for _, pt in ipairs(points) do if pt ~= dest then table.insert(step.path, pt.p) end end
	local gotoGoal
	if dest then
		step.dest = dest.p
		if not hasCompletable then
			-- a step that is only travel: arriving completes it
			gotoGoal = { kind = "goto", point = dest.p, text = "Go to the marked spot", cond = dest.cond }
			table.insert(step.goals, gotoGoal)
			hasCompletable = true
		end
	end
	-- notes that followed a goto line follow its goal, or (without one) the line before the goto
	for _, tip in ipairs(step.tips) do
		if isPoint[tip.after] then tip.after = gotoGoal or isPoint[tip.after].prev end
	end
	if not hasCompletable and not untilStep then
		table.insert(step.goals, { kind = "confirm", text = "Continue when ready" })
	end
	step.cond = Cond(lines.only, ctx)
	if not untilStep then step.skip = Cond(lines.skip, ctx) end
	return step
end

--- What a step works on, as keys: quest objectives ("quest/objective") and the quests it accepts or turns in
--- ("accept:quest", "turnin:quest"), so a side box that repeats a step's own talk/turn-in isn't shown with it.
---@param step ObviGuideStep
local function ObjectivesOf(step)
	local keys = {}
	for _, g in ipairs(step.goals) do
		if g.quest and (g.kind == "objective" or g.kind == "kill" or (g.kind == "collect" and g.objective)) then
			keys[g.quest .. "/" .. (g.objective or 1)] = true
		elseif g.quest and (g.kind == "accept" or g.kind == "turnin") then
			keys[g.kind .. ":" .. g.quest] = true
		end
	end
	return keys
end

local function Shares(a, b)
	for k in pairs(a) do if b[k] then return true end end
	return false
end

--- Side boxes go into the steps they accompany: from the next step up to and including their untilStep.
---@param steps ObviGuideBuiltStep[]
---@param ctx ObviGuideBuildContext
---@return ObviGuideStep[]
local function Assemble(steps, ctx)
	local function lastOf(i, untilStep)
		local nextReal
		for k = i + 1, #steps do
			local s = steps[k]
			if not s.untilStep then
				nextReal = nextReal or k
				if untilStep ~= "next" and s.label == untilStep then return k end
			end
		end
		if untilStep ~= "next" then ns.Print("%s: no step labelled '%s' after a side box; it lasts one step", ctx.title, untilStep) end
		return nextReal or #steps
	end
	local out, active = {}, {}
	for i, s in ipairs(steps) do
		if s.untilStep then
			local side = {}
			for _, g in ipairs(s.goals) do
				local copy = setmetatable({}, { __index = g })
				copy.cond = Conditions.All(s.cond, g.cond)
				table.insert(side, copy)
			end
			if #side > 0 then table.insert(active, { goals = side, last = lastOf(i, s.untilStep), keys = ObjectivesOf(s) }) end
		else
			-- a side box is not shown on a step that works on the same objective itself (that would show it twice)
			local own = ObjectivesOf(s)
			for _, a in ipairs(active) do
				if not Shares(a.keys, own) then for _, g in ipairs(a.goals) do table.insert(s.side, g) end end
			end
			table.insert(out, s)
			s.index = #out
			local still = {}
			for _, a in ipairs(active) do if i < a.last then table.insert(still, a) end end
			active = still
		end
	end
	return out
end

---@param g ObviGuideGuideImpl
---@param source string
---@return ObviGuideGuide
local function Finish(g, source)
	if type(g.title) ~= "string" or g.title == "" then error("the guide has no title (g.title)", 0) end
	local ctx = { title = g.title, reported = {} }
	local steps = {}
	for _, item in ipairs(g._items) do table.insert(steps, BuildStep(item.lines, item.untilStep, ctx)) end
	steps = Assemble(steps, ctx)
	if #steps == 0 then error("the guide has no steps", 0) end
	return {
		title = g.title,
		name = g.id,
		group = g.group or "Obvi Guide",
		next = g.next,
		cond = Cond(g.only, ctx),
		format = "obviguide",
		source = source,
		steps = steps,
	}
end

-- ---------------------------------------------------------------------------------------------------------------
-- The public API. docs/api.lua declares it for the editor (the types pack authors see), hence the second definition.

---@param build fun(g: ObviGuideGuideBuilder)
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.Guide(build)
	local source = (debugstack(2, 1, 0) or ""):match("AddOns[\\/]([^\\/]+)") or "?"
	local g = setmetatable({ _items = {} }, GuideMT)
	local ok, res = pcall(build, g --[[@as ObviGuideGuideBuilder]])
	if ok then ok, res = pcall(Finish, g, source) end
	if not ok then
		local title = type(g.title) == "string" and (" '" .. g.title .. "'") or ""
		ns.Print("could not add the guide%s from %s: %s", title, source, tostring(res))
		return
	end
	table.insert(ns.guides, res)
	ns:Fire("OBVIGUIDE_GUIDES_ADDED")
end
