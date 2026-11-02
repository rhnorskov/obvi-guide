-- Editor: the draft's steps and lines in a window styled like Obvi Guide's (the damage meter's header bar,
-- background and resize handle). The dropdown switches, makes and deletes drafts, opens a guide Obvi Guide has loaded
-- as a new draft, and sets the guide's options. Steps are added (after the one clicked), moved, merged, deleted and
-- given a label, a condition or made a side box; lines are added from every kind the builder has, changed in a form,
-- moved (also into the step above or below) and deleted, and plain text is edited in place. The buttons record, add
-- a goto, add a step, test the draft in Obvi Guide and export it.
local _, ns = ...
---@cast ns ObviScribeNS

---@class ObviScribeEditor
local Editor = {}
ns.Editor = Editor

local HEADER = 32
local STEP_ROW, LINE_ROW, STEP_GAP = 24, 22, 6
local DEFAULT_W, DEFAULT_H = 440, 520
local BG_ALPHA = 0.85   -- more solid than Obvi Guide's window: this one is for reading and typing
local MenuUtil = _G["MenuUtil"] ---@type {CreateContextMenu: fun(owner: any, gen: fun(owner: any, root: any))}
local COLOR = { Npc = "ff00ff25", Mob = "ffff5040", Item = "ff00bbff", Object = "ffdb7fff", Warn = "ffffa500", Buy = "ffffd100" }

---@class ObviScribeRow : Frame
---@field label FontString
---@field edit EditBox
---@field bg Texture
---@field buttons Button[]
---@field first Button       the leftmost button (the text ends there)
---@field step integer
---@field line? integer

---@class ObviScribeDropdown : DropdownButton
---@field SetupMenu fun(self: ObviScribeDropdown, generator: fun(owner: any, root: any))
---@field GenerateMenu fun(self: ObviScribeDropdown)

local frame ---@type Frame
local scroll ---@type ScrollFrame
local content ---@type Frame
local dropdown ---@type ObviScribeDropdown
local nameBox ---@type EditBox
local recordButton ---@type Button
local openButton ---@type Button
local status ---@type FontString
local stepRows, lineRows = {}, {} ---@type ObviScribeRow[], ObviScribeRow[]
local focused ---@type EditBox?   a line's text being edited: the list is not redrawn under it
local dirty = false
local selected ---@type integer?   the step clicked last: "Add step" adds after it

-- ---------------------------------------------------------------------------------------------------------------
-- What lines say in the list

---@param kind string
---@param name? string
---@param id? integer
local function Named(kind, name, id)
	return "|c" .. COLOR[kind] .. tostring(name) .. "|r" .. (id and (" |cff888888(" .. id .. ")|r") or "")
end

--- Text with markers, as the list shows it.
---@param parts (string|ObviScribeMarker)[]
---@return string
local function PartsText(parts)
	local out = {}
	for _, p in ipairs(parts) do
		if type(p) == "string" then table.insert(out, p)
		elseif p.parts then table.insert(out, "|c" .. (COLOR[p.m] or "ffffffff") .. PartsText(p.parts) .. "|r")
		elseif COLOR[p.m] then table.insert(out, "|c" .. COLOR[p.m] .. tostring(p.name) .. "|r")
		else table.insert(out, tostring(p.name)) end
	end
	return table.concat(out)
end

--- A line's text, plain, for the form (markers by their names).
---@param l ObviScribeLine
---@return string?
local function PlainText(l)
	if not l.parts then return l.text end
	return (PartsText(l.parts):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

---@param l ObviScribeLine
local function Objective(l)
	if not l.quest then return "" end
	return (" |cff888888[quest %d/%s]|r"):format(l.quest, tostring(l.objective or 1))
end

--- What a line says in the list (for lines edited in place, the part before the text box).
---@param l ObviScribeLine
---@return string
local function Describe(l)
	local op = l.op
	local s
	if op == "Goto" or op == "Path" then
		local info = l.map and C_Map.GetMapInfo(l.map)
		s = ("%s %s %.2f, %.2f"):format(op == "Goto" and "Go to" or "Path:", info and info.name or ("map " .. tostring(l.map)),
			l.x or 0, l.y or 0) .. (l.radius and (" |cff888888(within " .. l.radius .. " yd)|r") or "")
	elseif op == "Talk" then s = "Talk to " .. Named("Npc", l.name, l.id)
	elseif op == "Accept" or op == "Turnin" then
		s = ("%s %s |cff888888(%s)|r"):format(op == "Accept" and "Accept" or "Turn in", l.title or "quest", tostring(l.quest))
	elseif op == "Quest" then
		local title = l.quest and C_QuestLog.GetTitleForQuestID(l.quest)
		s = ("%s, objective %d:"):format(title or ("quest " .. tostring(l.quest)), l.objective or 1)
		if l.parts then s = s .. " " .. PartsText(l.parts) end
	elseif op == "Kill" or op == "Collect" then
		s = op .. " " .. (l.count and (l.count .. " ") or "") .. Named(op == "Kill" and "Mob" or "Item", l.name, l.id) .. Objective(l)
	elseif op == "Use" or op == "Equip" then s = op .. " " .. Named("Item", l.name, l.id)
	elseif op == "Cast" or op == "Learn" then s = op .. " " .. tostring(l.name) .. (l.id and (" |cff888888(" .. l.id .. ")|r") or "")
	elseif op == "Home" then s = "Make " .. tostring(l.place) .. " your home"
	elseif op == "Hearth" then s = "Hearth" .. (l.place and (" to " .. l.place) or "")
	elseif op == "Fly" then s = "Fly to " .. tostring(l.place)
	elseif op == "Level" then s = "Reach level " .. tostring(l.level) .. (l.xp and (" and " .. l.xp .. " XP") or "")
	elseif op == "Skill" then s = ("Reach %s %s"):format(tostring(l.skill), tostring(l.level))
	elseif op == "Train" then s = "Train " .. tostring(l.skill) .. (l.cap and (" up to " .. l.cap) or "")
	elseif op == "Do" or op == "Say" or op == "Note" then
		s = op .. ":" .. (l.parts and (" " .. PartsText(l.parts)) or "")
	else s = op end
	if l.only then s = s .. " |cff888888[only if " .. l.only .. "]|r" end
	return s
end

--- A line is edited in place when it is plain free text.
---@param l ObviScribeLine
local function InPlace(l) return ns.EDITABLE[l.op] and not l.parts end

local function Tooltip(widget, text)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(text)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

---@param parent Frame
---@param text string
---@param width number
---@param tip? string
---@param onClick fun(self: Button)
---@return Button
local function Button(parent, text, width, tip, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate") --[[@as Button]]
	b:SetSize(width, 20)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	if tip then Tooltip(b, tip) end
	return b
end

-- ---------------------------------------------------------------------------------------------------------------
-- Changing the draft

local function Steps() return ns.Draft().steps end

--- Empty fields become nil.
local function Blank(v) if v == "" then return nil end return v end

local function MoveStep(i, dir)
	local steps, j = Steps(), i + dir
	if not steps[j] then return end
	steps[i], steps[j] = steps[j], steps[i]
	selected = j
	ns.Changed()
end

local function MergeStep(i)
	local steps = Steps()
	local prev, step = steps[i - 1], steps[i]
	if not (prev and step) then return end
	for _, l in ipairs(step.lines) do table.insert(prev.lines, l) end
	table.remove(steps, i)
	selected = i - 1
	ns.Changed()
end

local function DeleteStep(i)
	table.remove(Steps(), i)
	selected = nil
	ns.Changed()
end

local function DeleteLine(i, j)
	local step = Steps()[i]
	if step then table.remove(step.lines, j) end
	ns.Changed()
end

--- A line one place up or down; past the first or last line of its step, into the step above or below.
local function MoveLine(i, j, dir)
	local steps = Steps()
	local step = steps[i]
	local l = step and step.lines[j]
	if not l then return end
	local k = j + dir
	if step.lines[k] then
		step.lines[j], step.lines[k] = step.lines[k], l
	else
		local other = steps[i + dir]
		if not other then return end
		table.remove(step.lines, j)
		if dir < 0 then table.insert(other.lines, l) else table.insert(other.lines, 1, l) end
	end
	ns.Changed()
end

--- The form for a line: a new one of `type` into step i, or line j of step i.
---@param i integer
---@param j? integer
---@param type ObviScribeLineType
local function LineForm(i, j, type)
	local step = Steps()[i]
	if not step then return end
	local old = j and step.lines[j]
	local values = {}
	if old then
		for k, v in pairs(old) do values[k] = v end
		values.text = PlainText(old)
	elseif type.preset then
		for k, v in pairs(type.preset) do values[k] = v end
	end
	local fields = {}
	for _, f in ipairs(type.fields) do table.insert(fields, f) end
	table.insert(fields, ns.Form.ONLY)
	ns.Form.Open({
		title = (old and "Change: " or "Add: ") .. type.label,
		fields = fields, values = values, helpers = type.helpers,
		hint = (old and old.parts) and "Changing the text drops its markers (names in colour)." or nil,
		onSave = function(v)
			local l = { op = type.op } ---@type ObviScribeLine
			for k, x in pairs(v) do l[k] = x end
			-- text with markers stays as it was unless it was changed
			if old and old.parts and v.text == PlainText(old) then l.text, l.parts = nil, old.parts end
			if not ns.Call(l) then return "this line is missing something" end
			local lines = Steps()[i] and Steps()[i].lines
			if not lines then return "the step is gone" end
			if j and lines[j] == old then lines[j] = l else table.insert(lines, l) end
			ns.Changed()
		end,
	})
end

--- The "Add line" menu: every kind of line.
local function AddLineMenu(i, owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, t in ipairs(ns.LINES) do root:CreateButton(t.label, function() LineForm(i, nil, t) end) end
	end)
end

local STEP_FIELDS = {
	{ key = "label", label = "Label", type = "text" },
	ns.Form.ONLY,
	{ key = "skip", label = "Done if (condition)", type = "text" },
	{ key = "side", label = "Side box until", type = "text" },
}
local STEP_HINT = "Side box until: a later step's label, or \"next\"; empty for a step."

--- The form for a step's options: label, condition, skip, side box.
---@param i integer
local function StepForm(i)
	local step = Steps()[i]
	if not step then return end
	ns.Form.Open({
		title = "Step " .. i, fields = STEP_FIELDS, values = step, hint = STEP_HINT,
		onSave = function(v)
			step.label, step.only, step.skip, step.side = Blank(v.label), Blank(v.only), Blank(v.skip), Blank(v.side)
			ns.Changed()
		end,
	})
end

--- "Add step": a new step after the one clicked last (or at the end), with its options and a goto if filled in.
local function AddStep()
	local fields = {}
	for _, f in ipairs(STEP_FIELDS) do table.insert(fields, f) end
	local gotoType = ns.LineType("Goto") --[[@as ObviScribeLineType]]
	for k = 1, 3 do
		local f = gotoType.fields[k]
		table.insert(fields, { key = f.key, label = "Goto: " .. f.label, type = f.type })
	end
	ns.Form.Open({
		title = "Add step", fields = fields, helpers = { "here" },
		hint = "The goto is optional (\"Here\" fills it in). " .. STEP_HINT,
		onSave = function(v)
			if (v.map or v.x or v.y) and not (v.map and v.x and v.y) then return "the goto needs a map, X and Y" end
			local step = { lines = {}, label = Blank(v.label), only = Blank(v.only), skip = Blank(v.skip), side = Blank(v.side) }
			if v.map then table.insert(step.lines, { op = "Goto", map = v.map, x = v.x, y = v.y }) end
			local steps = Steps()
			local at = (selected and steps[selected]) and selected + 1 or #steps + 1
			table.insert(steps, at, step)
			selected = at
			ns.Changed(at > #steps - 1)
		end,
	})
end

--- The guide's options: folder, next guide, condition.
local function GuideForm()
	local d = ns.Draft()
	ns.Form.Open({
		title = "Guide: " .. d.name,
		fields = {
			{ key = "group", label = "Folder (export)", type = "text" },
			{ key = "next", label = "Next guide (title or id)", type = "text" },
			ns.Form.ONLY,
		},
		values = d,
		hint = "Test always lists the draft under Drafts.",
		onSave = function(v)
			d.group, d.next, d.only = Blank(v.group), Blank(v.next), Blank(v.only)
			ns.Changed()
		end,
	})
end

-- ---------------------------------------------------------------------------------------------------------------
-- Rows

---@param row ObviScribeRow
---@param specs {[1]: string, [2]: string, [3]: fun(row: ObviScribeRow, button: Button)}[]   text, tooltip, action
---@param width number
local function RowButtons(row, specs, width)
	row.buttons = {}
	local anchor
	for k = #specs, 1, -1 do
		local spec = specs[k]
		local b = Button(row, spec[1], width, spec[2], function(self) spec[3](row, self) end)
		if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -2, 0) else b:SetPoint("RIGHT", -2, 0) end
		anchor = b
		table.insert(row.buttons, 1, b)
	end
	return anchor
end

---@return ObviScribeRow
local function StepRow(n)
	local row = stepRows[n]
	if row then return row end
	row = CreateFrame("Frame", nil, content) --[[@as ObviScribeRow]]
	row:SetHeight(STEP_ROW)
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.label:SetPoint("LEFT", 6, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	local first = RowButtons(row, {
		{ "+", "Add a line", function(r, b) AddLineMenu(r.step, b) end },
		{ "o", "Step options: label, condition, side box", function(r) StepForm(r.step) end },
		{ "^", "Move up", function(r) MoveStep(r.step, -1) end },
		{ "v", "Move down", function(r) MoveStep(r.step, 1) end },
		{ "M", "Merge with the step above", function(r) MergeStep(r.step) end },
		{ "x", "Delete this step", function(r) DeleteStep(r.step) end },
	}, 24)
	row.label:SetPoint("RIGHT", first, "LEFT", -4, 0)
	-- clicking the step's bar selects it: "Add step" adds after it
	row:EnableMouse(true)
	row:SetScript("OnMouseDown", function(self)
		selected = self.step
		Editor.Refresh()
	end)
	stepRows[n] = row
	return row
end

---@return ObviScribeRow
local function LineRow(n)
	local row = lineRows[n]
	if row then return row end
	row = CreateFrame("Frame", nil, content) --[[@as ObviScribeRow]]
	row:SetHeight(LINE_ROW)
	local first = RowButtons(row, {
		{ "e", "Change this line", function(r)
			local l = r.line and Steps()[r.step] and Steps()[r.step].lines[r.line]
			local t = l and ns.LineType(l.op)
			if t then LineForm(r.step, r.line, t) end
		end },
		{ "^", "Move up (past the first line: into the step above)", function(r) if r.line then MoveLine(r.step, r.line, -1) end end },
		{ "v", "Move down (past the last line: into the step below)", function(r) if r.line then MoveLine(r.step, r.line, 1) end end },
		{ "x", "Delete this line", function(r) if r.line then DeleteLine(r.step, r.line) end end },
	}, 20)
	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate") --[[@as EditBox]]
	edit:SetHeight(18)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlightSmall")
	edit:SetPoint("LEFT", row.label, "RIGHT", 10, 0)
	edit:SetPoint("RIGHT", first, "LEFT", -6, 0)
	local function Line()
		local step = Steps()[row.step]
		return step and row.line and step.lines[row.line]
	end
	edit:SetScript("OnEditFocusGained", function(self) focused = self end)
	edit:SetScript("OnEditFocusLost", function(self)
		local l = Line()
		if l then l.text = self:GetText() end
		focused = nil
		if dirty then Editor.Refresh() end
	end)
	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEscapePressed", function(self)
		local l = Line()
		self:SetText(l and l.text or "")
		self:ClearFocus()
	end)
	row.edit = edit
	row.first = first
	lineRows[n] = row
	return row
end

---@param row ObviScribeRow
---@param y number
local function Place(row, y)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
	row:SetPoint("RIGHT", content, "RIGHT")
	row:Show()
end

---@param step ObviScribeStep
---@param i integer
---@param last boolean
local function StepTitle(step, i, last)
	local s = step.side and ("Side tasks |cff888888(until " .. step.side .. ")|r") or ("Step " .. i)
	if step.label then s = s .. "  |cffffffff" .. step.label .. "|r" end
	if step.only then s = s .. "  |cff888888only if " .. step.only .. "|r" end
	if step.skip then s = s .. "  |cff888888done if " .. step.skip .. "|r" end
	if #step.lines == 0 then
		s = s .. (last and "  |cff888888(empty: what is recorded next goes here)|r" or "  |cff888888(empty)|r")
	end
	return s
end

--- Draws the draft's steps again (later, while a line's text is being edited).
---@param toEnd? boolean   scroll to the last step (something was added there)
function Editor.Refresh(toEnd)
	if not frame or not frame:IsShown() then return end
	if focused then dirty = true return end
	dirty = false
	local d = ns.Draft()
	nameBox:SetText(d.name)
	dropdown:GenerateMenu()
	local on = ns.Recorder.IsOn()
	recordButton:SetText(on and "Stop" or "Record")
	status:SetText(on and "|cffff4040Recording|r" or "")
	for _, r in ipairs(stepRows) do r:Hide() end
	for _, r in ipairs(lineRows) do r:Hide() end
	if selected and not d.steps[selected] then selected = nil end
	local y, nStep, nLine = 0, 0, 0
	if #d.steps == 0 then
		nLine = 1
		local row = LineRow(1)
		row.step, row.line = 0, nil
		row.label:SetText("|cff888888Press Record and play, or Add step to write the guide by hand.|r")
		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", 16, 0)
		row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.edit:Hide()
		for _, b in ipairs(row.buttons) do b:Hide() end
		Place(row, 0)
		y = LINE_ROW
	end
	for i, step in ipairs(d.steps) do
		nStep = nStep + 1
		local srow = StepRow(nStep)
		srow.step = i
		srow.label:SetText(StepTitle(step, i, i == #d.steps))
		if i == selected then srow.bg:SetColorTexture(1, 0.82, 0, 0.25)
		elseif step.side then srow.bg:SetColorTexture(0.4, 0.6, 1, 0.12)
		else srow.bg:SetColorTexture(1, 0.82, 0, 0.08) end
		srow.buttons[5]:SetEnabled(i > 1)   -- merge
		Place(srow, y)
		y = y + STEP_ROW
		for j, l in ipairs(step.lines) do
			nLine = nLine + 1
			local row = LineRow(nLine)
			row.step, row.line = i, j
			row.label:SetText(Describe(l))
			for _, b in ipairs(row.buttons) do b:Show() end
			row.buttons[1]:SetEnabled(ns.LineType(l.op) ~= nil)
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", 16, 0)
			if InPlace(l) then
				row.edit:SetText(l.text or "")
				row.edit:SetCursorPosition(0)
				row.edit:Show()
			else
				row.label:SetPoint("RIGHT", row.first, "LEFT", -6, 0)
				row.edit:Hide()
			end
			Place(row, y)
			y = y + LINE_ROW
		end
		y = y + STEP_GAP
	end
	content:SetHeight(math.max(y, 1))
	if toEnd then C_Timer.After(0, function() scroll:SetVerticalScroll(scroll:GetVerticalScrollRange()) end) end
end

-- ---------------------------------------------------------------------------------------------------------------
-- The window

local function SavePosition()
	local point, _, relPoint, x, y = frame:GetPoint()
	ns.db.window = { point = point, relPoint = relPoint, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight() }
end

local function Rename(self)
	local d = ns.Draft()
	local text = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
	if text ~= "" and text ~= d.name then d.name = ns.FreeName(text, d) end
	self:SetText(d.name)
	dropdown:GenerateMenu()
end

--- "Open guide": Obvi Guide's guides by folder (folders in folders, as its guide list has them), into a menu.
---@param sub any   the menu (or submenu) to fill
local function GuideMenu(sub)
	local guides = ObviGuide.List and ObviGuide.List() or {}
	if #guides == 0 then sub:CreateTitle("No guides loaded") return end
	sub:CreateTitle("Open a guide as a new draft")
	local menus = { [""] = sub }
	local function Folder(path)
		if menus[path] then return menus[path] end
		local parent, last = path:match("^(.*)\\([^\\]+)$")
		local m = Folder(parent or ""):CreateButton(last or path)
		if m.SetScrollMode then m:SetScrollMode(500) end
		menus[path] = m
		return m
	end
	if sub.SetScrollMode then sub:SetScrollMode(500) end
	for _, g in ipairs(guides) do
		Folder(g.group or ""):CreateButton(g.title, function() ns.OpenGuide(g) end)
	end
end

local function SetupDraftMenu(_, root)
	for i, d in ipairs(ns.db.drafts) do
		root:CreateRadio(d.name, function() return ns.db.current == i end, function()
			ns.db.current, selected = i, nil
			ns.Changed()
		end)
	end
	root:CreateDivider()
	root:CreateButton("New draft", function() selected = nil ns.NewDraft() end)
	GuideMenu(root:CreateButton("Open guide"))
	root:CreateButton("Guide options (folder, next, condition)", GuideForm)
	root:CreateButton("Delete this draft", function() _G["StaticPopup_Show"]("OBVISCRIBE_DELETE", ns.Draft().name) end)
end

_G["StaticPopupDialogs"]["OBVISCRIBE_DELETE"] = {
	text = "Delete the draft '%s'?",
	button1 = _G["YES"], button2 = _G["NO"],
	OnAccept = function() selected = nil ns.DeleteDraft() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

local function Build()
	frame = CreateFrame("Frame", "ObviScribeFrame", UIParent)
	frame:SetSize(DEFAULT_W, DEFAULT_H)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(400, 260, 1000, 1200)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	table.insert(_G["UISpecialFrames"], "ObviScribeFrame")   -- Escape closes it

	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	bg:SetAtlas("damagemeters-background")
	bg:SetAllPoints()
	bg:SetAlpha(BG_ALPHA)

	-- header: the damage meter's bar; drag it to move the window
	local header = CreateFrame("Frame", nil, frame)
	header:SetHeight(HEADER)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() frame:StartMoving() end)
	header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() SavePosition() end)
	local bar = header:CreateTexture(nil, "BACKGROUND")
	bar:SetAtlas("ui-damagemeters-header-bar")
	bar:SetAllPoints()
	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
	title:SetPoint("LEFT", 10, 2)
	title:SetText("Obvi Guide: Scribe")
	local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
	close:SetPoint("RIGHT", -2, 2)
	-- the template hides its parent, which is the header here: close the whole window instead
	close:SetScript("OnClick", function() frame:Hide() end)
	-- "Open guide": any guide Obvi Guide has loaded, as a new draft (also /scribe open)
	openButton = Button(header, "Open guide...", 96, "Open a guide Obvi Guide has loaded as a new draft, to change it",
		function(self) MenuUtil.CreateContextMenu(self, function(_, root) GuideMenu(root) end) end)
	openButton:SetPoint("RIGHT", close, "LEFT", -2, 0)
	status = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("RIGHT", openButton, "LEFT", -6, 0)

	-- the draft: which one (dropdown, with the draft and guide actions) and its name (the guide's title)
	dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate") --[[@as ObviScribeDropdown]]
	dropdown:SetWidth(150)
	dropdown:SetPoint("TOPLEFT", 8, -HEADER - 6)
	dropdown:SetupMenu(SetupDraftMenu)
	nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
	nameBox:SetHeight(20)
	nameBox:SetAutoFocus(false)
	nameBox:SetPoint("LEFT", dropdown, "RIGHT", 12, 0)
	nameBox:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	nameBox:SetScript("OnEscapePressed", function(self) self:SetText(ns.Draft().name) self:ClearFocus() end)
	nameBox:SetScript("OnEditFocusLost", Rename)
	Tooltip(nameBox, "The draft's name: the guide's title")

	-- the buttons
	local row = CreateFrame("Frame", nil, frame)
	row:SetHeight(22)
	row:SetPoint("TOPLEFT", 8, -HEADER - 34)
	row:SetPoint("RIGHT", -8, 0)
	recordButton = Button(row, "Record", 70, "Record quests, objectives, flight paths and your hearthstone into this draft",
		function() ns.Recorder.Toggle() end)
	recordButton:SetPoint("LEFT")
	local gotoButton = Button(row, "Goto here", 76, "A step that only leads here", function() ns.Recorder.GotoHere() end)
	gotoButton:SetPoint("LEFT", recordButton, "RIGHT", 4, 0)
	local addButton = Button(row, "Add step", 70, "A new step after the step clicked last (or at the end)", AddStep)
	addButton:SetPoint("LEFT", gotoButton, "RIGHT", 4, 0)
	local exportButton = Button(row, "Export", 60, "The draft as guide Lua, to copy into a guide pack", function()
		local d = ns.Draft()
		ns.Copy("Scribe: " .. d.name, ns.Export(d))
	end)
	exportButton:SetPoint("RIGHT")
	local testButton = Button(row, "Test", 50, "Open the draft in Obvi Guide (Drafts folder); again after edits",
		function() ns.Test() end)
	testButton:SetPoint("RIGHT", exportButton, "LEFT", -4, 0)

	-- the note box at the bottom: Enter (or the button) adds the note to the last step
	local note = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
	note:SetHeight(20)
	note:SetAutoFocus(false)
	note:SetPoint("BOTTOMLEFT", 14, 10)
	note:SetPoint("BOTTOMRIGHT", -74, 10)
	local function AddNote()
		ns.Recorder.Note(note:GetText())
		note:SetText("")
		note:ClearFocus()
	end
	note:SetScript("OnEnterPressed", AddNote)
	note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local noteButton = Button(frame, "Note", 56, "Add the text as a note to the last step", AddNote)
	noteButton:SetPoint("BOTTOMRIGHT", -10, 10)

	-- the steps
	scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate") --[[@as ScrollFrame]]
	scroll:SetPoint("TOPLEFT", 8, -HEADER - 62)
	scroll:SetPoint("BOTTOMRIGHT", -30, 38)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(DEFAULT_W - 38, 1)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)

	-- the damage meter's resize handle
	local resize = CreateFrame("Button", nil, frame)
	resize:SetSize(24, 24)
	resize:SetPoint("BOTTOMRIGHT", 4, -4)
	resize:SetNormalAtlas("damagemeters-scalehandle")
	resize:SetHighlightAtlas("damagemeters-scalehandle-hover")
	resize:SetPushedAtlas("damagemeters-scalehandle-pressed")
	resize:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() SavePosition() end)

	local saved = ns.db.window
	if saved then
		frame:ClearAllPoints()
		frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
		frame:SetSize(math.max(400, saved.w or DEFAULT_W), saved.h or DEFAULT_H)
	end
	frame:SetScript("OnShow", function() Editor.Refresh() end)
end

function Editor.Toggle()
	if not frame then Build() frame:Show() return end
	frame:SetShown(not frame:IsShown())
end

--- The window, with the "Open guide" menu open (/scribe open).
function Editor.OpenGuide()
	if not frame then Build() end
	frame:Show()
	openButton:Click()
end

ns:On("OBVISCRIBE_CHANGED", function(_, recorded) Editor.Refresh(recorded) end)
