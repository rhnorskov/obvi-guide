-- Export: a draft as Obvi Guide builder Lua, ObviGuide.Guide(function(g) ... end), ready to paste into a guide pack
-- (a small addon with "## Dependencies: ObviGuide", like Obvi Guide: Dungeons). Test runs the same text, so a draft
-- is shown in game exactly as its export would be. Also the line types the editor offers, with their fields.
-- Plain Lua with no game API, so it can be tried outside the game.
local _, ns = ...
---@cast ns ObviScribeNS

---@class ObviScribeExportOptions
---@field group? string   the guide's folder in the guide list (instead of the draft's own)
---@field id? string      the guide's id (Obvi Guide replaces a guide added again with the same id)

---@class ObviScribeField
---@field key string
---@field label string
---@field type "int"|"num"|"text"
---@field required? boolean

---@class ObviScribeLineType
---@field op ObviScribeOp
---@field label string                 in the "Add line" menu
---@field fields ObviScribeField[]
---@field helpers? string[]            the form's fill-in buttons: here, target, quest, objective, item, spell, bind
---@field preset? table                fields a menu entry starts with (Flight path: a Do line with its text)

local function F(key, label, type, required) return { key = key, label = label, type = type, required = required } end
local MAP, X, Y = F("map", "Map id", "int", true), F("x", "X (0-100)", "num", true), F("y", "Y (0-100)", "num", true)
local NAME, ID = F("name", "Name", "text", true), F("id", "Id", "int")
local COUNT, QUEST, OBJ = F("count", "Count", "int"), F("quest", "Quest id", "int"), F("objective", "Objective", "int")
local TEXT = F("text", "Text", "text", true)

-- the lines the builder has (docs/api.lua), in the order the "Add line" menu shows them
---@type ObviScribeLineType[]
ns.LINES = {
	{ op = "Goto", label = "Goto (the step's spot)", fields = { MAP, X, Y, F("radius", "Radius (yards)", "int") }, helpers = { "here" } },
	{ op = "Path", label = "Path (a point on the way)", fields = { MAP, X, Y }, helpers = { "here" } },
	{ op = "Talk", label = "Talk to an NPC", fields = { NAME, ID }, helpers = { "target" } },
	{ op = "Accept", label = "Accept a quest", fields = { F("quest", "Quest id", "int", true), F("title", "Title", "text") }, helpers = { "quest" } },
	{ op = "Turnin", label = "Turn in a quest", fields = { F("quest", "Quest id", "int", true), F("title", "Title", "text") }, helpers = { "quest" } },
	{ op = "Quest", label = "Quest objective", fields = { F("quest", "Quest id", "int", true), F("objective", "Objective", "int", true),
		F("text", "Text (optional)", "text") }, helpers = { "objective" } },
	{ op = "Kill", label = "Kill", fields = { NAME, ID, COUNT, QUEST, OBJ }, helpers = { "target", "objective" } },
	{ op = "Collect", label = "Collect items", fields = { NAME, ID, COUNT, QUEST, OBJ }, helpers = { "item", "objective" } },
	{ op = "Use", label = "Use an item", fields = { NAME, ID }, helpers = { "item" } },
	{ op = "Equip", label = "Equip an item", fields = { NAME, ID }, helpers = { "item" } },
	{ op = "Cast", label = "Cast a spell", fields = { NAME, ID }, helpers = { "spell" } },
	{ op = "Learn", label = "Learn a spell", fields = { NAME, ID }, helpers = { "spell" } },
	{ op = "Home", label = "Home (set the hearthstone)", fields = { F("place", "Inn", "text", true) }, helpers = { "bind" } },
	{ op = "Hearth", label = "Hearth", fields = { F("place", "To (optional)", "text") }, helpers = { "bind" } },
	{ op = "Fly", label = "Fly", fields = { F("place", "To", "text", true) } },
	{ op = "Do", label = "Flight path (a line to tick off)", fields = { TEXT }, preset = { text = "Get the flight path" } },
	{ op = "Level", label = "Reach a level", fields = { F("level", "Level", "int", true), F("xp", "XP (optional)", "int") } },
	{ op = "Train", label = "Train a profession", fields = { F("skill", "Profession (English)", "text", true), F("cap", "Skill cap (75/150/225/300)", "int") } },
	{ op = "Skill", label = "Reach a skill level", fields = { F("skill", "Profession (English)", "text", true), F("level", "Skill level", "int", true) } },
	{ op = "Do", label = "Do (tick off)", fields = { TEXT } },
	{ op = "Say", label = "Say (plain text)", fields = { TEXT } },
	{ op = "Note", label = "Note", fields = { TEXT } },
}

--- The line type for a line's op (the first entry with it).
---@param op string
---@return ObviScribeLineType?
function ns.LineType(op)
	for _, t in ipairs(ns.LINES) do if t.op == op and not t.preset then return t end end
end

-- lines whose plain text the editor lets the player change in place
ns.EDITABLE = { Quest = true, Do = true, Say = true, Note = true }

---@param s any
---@return string
local function Q(s) return (("%q"):format(tostring(s or "")):gsub("\\\n", "\\n")) end

--- A coordinate with at most four decimals: 48.17, 42.1, 50 (converted Zygor points have more).
---@param n number
---@return string
local function Num(n)
	local s = ("%.4f"):format(tonumber(n) or 0)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	return s
end

local Text

--- A marker as its builder call: g.Npc("Name", 123), g.Warn("text", g.Mob(...)).
---@param m ObviScribeMarker
---@return string
local function Marker(m)
	if m.parts then return ("g.%s(%s)"):format(m.m, Text(m.parts)) end
	if m.id and m.m ~= "Object" then return ("g.%s(%s, %d)"):format(m.m, Q(m.name), m.id) end
	return ("g.%s(%s)"):format(m.m, Q(m.name))
end

--- Text arguments: strings and markers, comma separated.
---@param parts (string|ObviScribeMarker)[]
---@return string
Text = function(parts)
	local out = {}
	for _, p in ipairs(parts) do table.insert(out, type(p) == "table" and Marker(p) or Q(p)) end
	return table.concat(out, ", ")
end

--- A line's text argument(s), or nil when it has none.
---@param l ObviScribeLine
---@return string?
local function LineText(l)
	if l.parts and #l.parts > 0 then return Text(l.parts) end
	if l.text and l.text ~= "" then return Q(l.text) end
end

--- { count = 3, quest = 7, objective = 1 }, or nil when there is none of them.
---@param l ObviScribeLine
---@return string?
local function Options(l)
	local out = {}
	for _, k in ipairs({ "count", "quest", "objective" }) do
		if l[k] then table.insert(out, ("%s = %d"):format(k, l[k])) end
	end
	if #out > 0 then return "{ " .. table.concat(out, ", ") .. " }" end
end

local MARKER_OF = { Talk = "Npc", Kill = "Mob", Collect = "Item", Use = "Item", Equip = "Item", Cast = "Spell", Learn = "Spell" }

--- One line as its builder call (without the indent), or nil for a line that can't be written (missing data).
---@param l ObviScribeLine
---@return string?
local function Call(l)
	local op, args = l.op, nil
	if op == "Goto" or op == "Path" then
		if not (l.map and l.x and l.y) then return nil end
		args = ("%d, %s, %s"):format(l.map, Num(l.x), Num(l.y))
		if op == "Goto" and l.radius then args = args .. ", " .. l.radius end
	elseif MARKER_OF[op] then
		if not l.name or l.name == "" then return nil end
		args = Marker({ m = MARKER_OF[op], name = l.name, id = l.id })
		local o = (op == "Kill" or op == "Collect") and Options(l)
		if o then args = args .. ", " .. o end
	elseif op == "Accept" or op == "Turnin" then
		if not l.quest then return nil end
		args = tostring(l.quest)
		if l.title and l.title ~= "" then args = args .. ", " .. Q(l.title) end
	elseif op == "Quest" then
		if not (l.quest and l.objective) then return nil end
		args = ("%d, %d"):format(l.quest, l.objective)
		local t = LineText(l)
		if t then args = args .. ", " .. t end
	elseif op == "Home" or op == "Fly" then
		if not l.place or l.place == "" then return nil end
		args = Q(l.place)
	elseif op == "Hearth" then
		args = (l.place and l.place ~= "") and Q(l.place) or ""
	elseif op == "Skill" then
		if not (l.skill and l.level) then return nil end
		args = ("%s, %d"):format(Q(l.skill), l.level)
	elseif op == "Train" then
		if not l.skill or l.skill == "" then return nil end
		args = l.cap and ("%s, %d"):format(Q(l.skill), l.cap) or Q(l.skill)
	elseif op == "Level" then
		if not l.level then return nil end
		args = l.xp and ("%d, %d"):format(l.level, l.xp) or tostring(l.level)
	elseif op == "Do" or op == "Say" or op == "Note" then
		args = LineText(l)
		if not args then return nil end
	else
		return nil
	end
	local code = ("s:%s(%s)"):format(op, args)
	if l.only and l.only ~= "" then code = code .. (":Only(%s)"):format(Q(l.only)) end
	return code
end
ns.Call = Call

--- The draft as builder Lua. Steps without lines are left out.
---@param draft ObviScribeDraft
---@param opts? ObviScribeExportOptions
---@return string
function ns.Export(draft, opts)
	opts = opts or {}
	local out = { "ObviGuide.Guide(function(g)", "\tg.title = " .. Q(draft.name) }
	local group = opts.group or draft.group
	if group then table.insert(out, "\tg.group = " .. Q(group)) end
	if opts.id then table.insert(out, "\tg.id = " .. Q(opts.id)) end
	if draft.next then table.insert(out, "\tg.next = " .. Q(draft.next)) end
	if draft.only and draft.only ~= "" then table.insert(out, "\tg.only = " .. Q(draft.only)) end
	for _, step in ipairs(draft.steps) do
		local calls = {}
		for _, l in ipairs(step.lines) do
			local c = Call(l)
			if c then table.insert(calls, "\t\t" .. c) end
		end
		if #calls > 0 then
			table.insert(out, "")
			if step.side and step.side ~= "" then
				table.insert(out, ("\tg:Side(%s, function(s)"):format(Q(step.side)))
			else
				table.insert(out, "\tg:Step(function(s)")
				if step.label and step.label ~= "" then table.insert(out, "\t\ts.label = " .. Q(step.label)) end
				if step.skip and step.skip ~= "" then table.insert(out, "\t\ts.skip = " .. Q(step.skip)) end
			end
			if step.only and step.only ~= "" then table.insert(out, "\t\ts.only = " .. Q(step.only)) end
			for _, c in ipairs(calls) do table.insert(out, c) end
			table.insert(out, "\tend)")
		end
	end
	table.insert(out, "end)")
	return table.concat(out, "\n") .. "\n"
end
