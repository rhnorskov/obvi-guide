-- Obvi Guide: Scribe, core: the shared namespace, a small event hub, the saved drafts, and handing a draft to Obvi Guide
-- (Test). A draft is a list of steps, each a list of lines in the form Obvi Guide's builder takes (see Export.lua).
local ADDON, ns = ...
---@cast ns ObviScribeNS

---@alias ObviScribeOp "Goto"|"Path"|"Talk"|"Accept"|"Turnin"|"Quest"|"Kill"|"Collect"|"Use"|"Equip"|"Cast"|"Learn"|"Hearth"|"Home"|"Fly"|"Level"|"Skill"|"Train"|"Do"|"Say"|"Note"

--- A marker inside a line's text, as the builder writes it: g.Npc(name, id), g.Warn(...)
---@class ObviScribeMarker
---@field m "Npc"|"Mob"|"Item"|"Spell"|"Object"|"Warn"|"Buy"
---@field name? string
---@field id? integer
---@field parts? (string|ObviScribeMarker)[]   Warn, Buy: their text

--- One line, as the builder call it becomes (s:Goto(map, x, y), s:Talk(g.Npc(name, id)), s:Kill(g.Mob(name, id),
--- {count, quest, objective})...): the method, and its arguments as fields.
---@class ObviScribeLine
---@field op ObviScribeOp
---@field map? integer        Goto, Path: uiMapID
---@field x? number           Goto, Path: 0-100, as the map shows it
---@field y? number
---@field radius? integer     Goto: yards
---@field name? string        Talk, Kill, Collect, Use, Equip, Cast, Learn: who or what
---@field id? integer         its creature, item or spell id
---@field count? integer      Kill, Collect
---@field quest? integer      Accept, Turnin, Quest; Kill, Collect: the quest objective that counts
---@field objective? integer
---@field title? string       Accept, Turnin
---@field text? string        Quest, Do, Say, Note: the text (the player may edit it)
---@field parts? (string|ObviScribeMarker)[]   the text instead, when it has markers in it (from an opened guide)
---@field place? string       Home, Hearth, Fly
---@field level? integer      Level, Skill
---@field skill? string       Skill, Train: the profession's English name
---@field cap? integer        Train: the skill cap the rank brings
---@field xp? integer
---@field only? string        the line's condition (:Only)

---@class ObviScribeStep
---@field lines ObviScribeLine[]
---@field label? string
---@field only? string        the step's condition
---@field skip? string        counts as done while this holds
---@field side? string        a side box (g:Side) instead of a step: the label of the step it lasts until, or "next"
---@field npc? string         who the step is at (creature id, or name), so the next action there joins it
---@field quest? integer      a step of one quest's objectives: that quest
---@field closed? boolean     nothing more is recorded into it (a hearth, a "Goto here")

---@class ObviScribeDraft
---@field name string
---@field steps ObviScribeStep[]
---@field group? string       the guide's folder in an export (Test puts it under "Drafts")
---@field next? string
---@field only? string

---@class ObviScribeDB
---@field drafts ObviScribeDraft[]
---@field current integer      the draft being edited
---@field recording? boolean
---@field window? {point: string, relPoint: string, x: number, y: number, w: number, h: number}

---@class ObviScribeNS
---@field db ObviScribeDB
---@field Export fun(draft: ObviScribeDraft, opts?: ObviScribeExportOptions): string
---@field EDITABLE table<string, boolean>
---@field Recorder ObviScribeRecorder
---@field Editor ObviScribeEditor
---@field Copy fun(title: string, text: string)
---@field On fun(self: ObviScribeNS, event: string, fn: ObviScribeHandler)
---@field Fire fun(self: ObviScribeNS, event: string, ...: any)
---@field Print fun(fmt: string, ...: any)
---@field Changed fun(recorded?: boolean)
---@field FreeName fun(base: string, except?: ObviScribeDraft): string
---@field NewDraft fun(name?: string): ObviScribeDraft
---@field Draft fun(): ObviScribeDraft
---@field DeleteDraft fun()
---@field DraftId fun(d: ObviScribeDraft): string
---@field Register fun(d: ObviScribeDraft, quiet?: boolean): boolean
---@field Test fun()
---@field LINES ObviScribeLineType[]
---@field LineType fun(op: string): ObviScribeLineType?
---@field Call fun(l: ObviScribeLine): string?
---@field FromModel fun(guide: ObviScribeModel): ObviScribeDraft
---@field OpenGuide fun(guide: table)
---@field Form ObviScribeForm
---@field UnitCreature fun(unit: string): {name: string, id?: integer}?

---@alias ObviScribeHandler fun(event: string, ...: any)

local handlers = {} ---@type table<string, ObviScribeHandler[]>
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...) ns:Fire(event, ...) end)

--- Game events and our own ("OBVISCRIBE_...") through one hub.
---@param event string
---@param fn ObviScribeHandler
function ns:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		if not event:find("^OBVISCRIBE_") and C_EventUtils.IsEventValid(event) then frame:RegisterEvent(event) end
	end
	table.insert(handlers[event], fn)
end

---@param event string
function ns:Fire(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end

---@param fmt string
function ns.Print(fmt, ...)
	print("|cff4fc3f7Obvi Guide: Scribe|r: " .. (select("#", ...) > 0 and fmt:format(...) or fmt))
end

--- Something in the draft changed: the editor redraws (and scrolls to the end when it was recorded).
---@param recorded? boolean
function ns.Changed(recorded) ns:Fire("OBVISCRIBE_CHANGED", recorded) end

--- A name no other draft has: "Draft", "Draft 2"...
---@param base string
---@param except? ObviScribeDraft
---@return string
function ns.FreeName(base, except)
	local name, n = base, 1
	local function taken()
		for _, d in ipairs(ns.db.drafts) do if d ~= except and d.name == name then return true end end
	end
	while taken() do n = n + 1 name = base .. " " .. n end
	return name
end

---@param name? string
---@return ObviScribeDraft
function ns.NewDraft(name)
	local d = { name = ns.FreeName(name or "Draft"), steps = {} }
	table.insert(ns.db.drafts, d)
	ns.db.current = #ns.db.drafts
	ns.Changed()
	return d
end

--- The draft being edited (a new one when there is none).
---@return ObviScribeDraft
function ns.Draft()
	local d = ns.db.drafts[ns.db.current]
	if d then return d end
	if #ns.db.drafts > 0 then ns.db.current = 1 return ns.db.drafts[1] end
	return ns.NewDraft()
end

--- Deletes the draft being edited. (It stays in Obvi Guide's list until /reload.)
function ns.DeleteDraft()
	table.remove(ns.db.drafts, ns.db.current)
	ns.db.current = math.max(1, ns.db.current - 1)
	ns.Draft()
	ns.Changed()
end

--- The id the draft has in Obvi Guide, so adding it again replaces it.
---@param d ObviScribeDraft
function ns.DraftId(d) return "ObviScribe: " .. d.name end

--- Hands the draft to Obvi Guide as the guide "Drafts\<name>", through the same Lua Export makes (so what is tested
--- is what gets exported). Returns whether it was added.
---@param d ObviScribeDraft
---@param quiet? boolean   say nothing about an empty draft
---@return boolean
function ns.Register(d, quiet)
	local any = false
	for _, s in ipairs(d.steps) do if #s.lines > 0 then any = true break end end
	if not any then
		if not quiet then ns.Print("the draft '%s' has no lines yet", d.name) end
		return false
	end
	local code = ns.Export(d, { group = "Drafts", id = ns.DraftId(d) })
	-- the chunk name says it comes from ObviScribe, which is how Obvi Guide tells who added a guide
	local fn, err = loadstring(code, "@Interface\\AddOns\\ObviScribe\\Draft.lua")
	if not fn then ns.Print("could not read the draft: %s", tostring(err)) return false end
	local ok, res = pcall(fn)
	if not ok then ns.Print("could not add the draft: %s", tostring(res)) return false end
	return true
end

--- Test: the draft into Obvi Guide, opened at its first step.
function ns.Test()
	local d = ns.Draft()
	if not ns.Register(d) then return end
	if ObviGuide.Load then
		ObviGuide.Load(ns.DraftId(d))
	else
		ns.Print("this Obvi Guide can't open it for you; pick Drafts\\%s in its guide list", d.name)
	end
end

--- Open a guide: one Obvi Guide has loaded (any format), as a new draft "<title> (copy)".
---@param guide table   from ObviGuide.List
function ns.OpenGuide(guide)
	local model = ObviGuide.Read and ObviGuide.Read(guide)
	if not model or #model.steps == 0 then ns.Print("could not read the guide '%s'", tostring(guide.title)) return end
	local d = ns.FromModel(model --[[@as ObviScribeModel]])
	d.name = ns.FreeName(model.title .. " (copy)")
	table.insert(ns.db.drafts, d)
	ns.db.current = #ns.db.drafts
	local lines, notes = 0, 0
	for _, s in ipairs(d.steps) do
		for _, l in ipairs(s.lines) do
			lines = lines + 1
			if l.op == "Note" and l.text and l.text:find("^%(not supported") then notes = notes + 1 end
		end
	end
	ns.Print("opened '%s' as the draft '%s': %d steps, %d lines", model.title, d.name, #d.steps, lines)
	if notes > 0 then ns.Print("%d of them are notes \"(not supported: ...)\" for what a guide in this form can't say", notes) end
	ns.Changed()
end

ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	ObviScribeDB = ObviScribeDB or {}
	ns.db = ObviScribeDB
	ns.db.drafts = ns.db.drafts or {}
	ns.db.current = ns.db.current or 1
end)

-- every draft is in Obvi Guide's list from the start, so a draft being followed is picked up again after a reload
ns:On("PLAYER_LOGIN", function()
	for _, d in ipairs(ns.db.drafts) do ns.Register(d, true) end
end)

-- /scribe toggles the window; "/scribe open" opens it with the "Open guide" menu
SLASH_OBVISCRIBE1 = "/scribe"
local slashCmdList = _G["SlashCmdList"] ---@type table<string, fun(msg: string)>
slashCmdList.OBVISCRIBE = function(msg)
	if (msg or ""):lower():match("^%s*open") then ns.Editor.OpenGuide() else ns.Editor.Toggle() end
end
