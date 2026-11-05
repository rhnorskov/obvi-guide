-- Form: a small window of labelled fields for adding or changing a line, a step's options or the guide's options.
-- Buttons fill fields in from the game: your position, your target, a quest (and objective) from your quest log, an
-- item (on the cursor, or picked from your bags), a spell (on the cursor, from the spellbook), your hearthstone's inn.
local _, ns = ...
---@cast ns ObviScribeNS

---@class ObviScribeForm
local Form = {}
ns.Form = Form

local WIDTH, ROW, MAX_ROWS = 400, 26, 9
local isSecret = _G["issecretvalue"] ---@type (fun(v: any): boolean)?
local MenuUtil = _G["MenuUtil"] ---@type {CreateContextMenu: fun(owner: any, gen: fun(owner: any, root: any))}

---@class ObviScribeFormRow
---@field label FontString
---@field box EditBox

local frame ---@type Frame
local rows = {} ---@type ObviScribeFormRow[]
local helperButtons = {} ---@type Button[]
local saveButton ---@type Button
local message ---@type FontString
local current ---@type {fields: ObviScribeField[], onSave: fun(values: table): string?}?

--- Puts values into the fields that have them (keys the form doesn't show are ignored).
---@param values table
local function Fill(values)
	if not current then return end
	for i, f in ipairs(current.fields) do
		local v = values[f.key]
		if v ~= nil then rows[i].box:SetText(tostring(v)) end
	end
end

--- The fields' values: numbers for number fields, nil for empty ones; or nil and what is wrong.
---@return table?, string?
local function Values()
	local out = {}
	for i, f in ipairs(current and current.fields or {}) do
		local s = rows[i].box:GetText():gsub("^%s+", ""):gsub("%s+$", "")
		if s ~= "" then
			if f.type == "text" then out[f.key] = s
			else
				local n = tonumber((s:gsub(",", ".")))
				if not n then return nil, f.label .. " must be a number" end
				out[f.key] = f.type == "int" and math.floor(n + 0.5) or n
			end
		elseif f.required then
			return nil, f.label .. " is needed"
		end
	end
	return out
end

-- ---------------------------------------------------------------------------------------------------------------
-- Filling in from the game

--- A unit's name and creature id (from its GUID), or nil.
---@param unit string
---@return {name: string, id?: integer}?
local function UnitCreature(unit)
	if not UnitExists(unit) then return nil end
	local name, guid = UnitName(unit), UnitGUID(unit)
	if isSecret and (isSecret(name) or isSecret(guid)) then return nil end
	local id
	if type(guid) == "string" then
		local kind, _, _, _, _, n = strsplit("-", guid)
		if kind == "Creature" or kind == "Vehicle" then id = tonumber(n) end
	end
	return { name = name, id = id }
end
ns.UnitCreature = UnitCreature

--- "Kobold Vermin slain: 3/10" -> "Kobold Vermin slain"
---@param s? string
---@return string
local function Clean(s)
	s = (s or ""):gsub("%d+%s*/%s*%d+", ""):gsub("^[%s:]+", ""):gsub("[%s:]+$", "")
	return s
end

--- The quests in the log: id and title.
---@return {id: integer, title: string}[]
local function LogQuests()
	local list = {}
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
			table.insert(list, { id = info.questID, title = info.title })
		end
	end
	return list
end

--- The items in the bags, once each: id and name.
---@return {id: integer, name: string}[]
local function BagItems()
	local list, seen = {}, {}
	for bag = 0, 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local id = info and info.itemID
			if id and not seen[id] then
				seen[id] = true
				table.insert(list, { id = id, name = C_Item.GetItemNameByID(id) or info.itemName or ("item " .. id) })
			end
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

--- The item or spell on the cursor (picked up from the bags or the spellbook), taken off it.
---@return "item"|"spell"|nil kind, integer? id, string? name
local function FromCursor()
	local kind, a, _, d = GetCursorInfo()
	if kind == "item" and a then
		ClearCursor()
		return "item", a, C_Item.GetItemNameByID(a)
	elseif kind == "spell" and d then
		ClearCursor()
		return "spell", d, C_Spell.GetSpellName(d)
	end
end

-- the fill-in buttons: label, tooltip, and what they do (fill sets fields; owner is the button, for a menu)
---@type table<string, {text: string, tip: string, run: fun(fill: fun(v: table), owner: Button)}>
local HELPERS = {
	here = { text = "Here", tip = "Your position", run = function(fill)
		local map, x, y = ns.Recorder.Here()
		if map then fill({ map = map, x = x, y = y }) else ns.Print("no map position here") end
	end },
	target = { text = "Target", tip = "Your target's name and id", run = function(fill)
		local t = UnitCreature("target")
		if t then fill(t) else ns.Print("target someone first") end
	end },
	quest = { text = "Quest log", tip = "A quest from your quest log", run = function(fill, owner)
		MenuUtil.CreateContextMenu(owner, function(_, root)
			for _, q in ipairs(LogQuests()) do
				root:CreateButton(q.title, function() fill({ quest = q.id, title = q.title }) end)
			end
		end)
	end },
	objective = { text = "Quest log", tip = "A quest objective from your quest log", run = function(fill, owner)
		MenuUtil.CreateContextMenu(owner, function(_, root)
			for _, q in ipairs(LogQuests()) do
				local sub = root:CreateButton(q.title)
				for i, o in ipairs(C_QuestLog.GetQuestObjectives(q.id) or {}) do
					sub:CreateButton(i .. ". " .. (o.text or ""), function()
						fill({ quest = q.id, objective = i, text = Clean(o.text) })
					end)
				end
			end
		end)
	end },
	item = { text = "Item", tip = "The item on your cursor (pick one up from your bags), or one from your bags",
		run = function(fill, owner)
			local kind, id, name = FromCursor()
			if kind == "item" then fill({ id = id, name = name }) return end
			MenuUtil.CreateContextMenu(owner, function(_, root)
				for _, it in ipairs(BagItems()) do
					root:CreateButton(it.name, function() fill({ id = it.id, name = it.name }) end)
				end
			end)
		end },
	spell = { text = "Spell", tip = "Pick a spell up from your spellbook, then click here", run = function(fill)
		local kind, id, name = FromCursor()
		if kind == "spell" then fill({ id = id, name = name }) else ns.Print("pick a spell up from your spellbook first") end
	end },
	bind = { text = "Your inn", tip = "Where your hearthstone is set", run = function(fill)
		local place = GetBindLocation()
		if place and place ~= "" then fill({ place = place }) end
	end },
}

-- ---------------------------------------------------------------------------------------------------------------
-- The window

local function Build()
	frame = CreateFrame("Frame", "ObviScribeFormFrame", UIParent, "ButtonFrameTemplate") --[[@as Frame]]
	_G["ButtonFrameTemplate_HidePortrait"](frame)
	-- the template's close button hides through HideUIPanel, which does nothing in combat; hide it ourselves (as Esc does)
	frame["CloseButton"]:SetScript("OnClick", function() frame:Hide() end)
	frame:SetWidth(WIDTH)
	frame:SetPoint("CENTER", 0, 80)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	table.insert(_G["UISpecialFrames"], "ObviScribeFormFrame")   -- Escape closes it

	for i = 1, MAX_ROWS do
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", 16, -36 - (i - 1) * ROW)
		label:SetWidth(130)
		label:SetJustifyH("LEFT")
		local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
		box:SetHeight(20)
		box:SetAutoFocus(false)
		box:SetPoint("LEFT", label, "RIGHT", 8, 0)
		box:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
		box:SetScript("OnEnterPressed", function() saveButton:Click() end)
		box:SetScript("OnEscapePressed", function() frame:Hide() end)
		box:SetScript("OnTabPressed", function()
			local nxt = rows[i + 1]
			if nxt and nxt.box:IsShown() then nxt.box:SetFocus() else rows[1].box:SetFocus() end
		end)
		-- an item or spell dropped on a field fills the line in
		box:SetScript("OnReceiveDrag", function()
			local kind, id, name = FromCursor()
			if kind then Fill({ id = id, name = name }) end
		end)
		rows[i] = { label = label, box = box }
	end

	saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
	saveButton:SetSize(80, 22)
	saveButton:SetPoint("BOTTOMRIGHT", -12, 8)
	saveButton:SetText("Save")
	saveButton:SetScript("OnClick", function()
		if not current then return end
		local values, err = Values()
		if values then err = current.onSave(values) end
		if err then message:SetText("|cffff4040" .. err .. "|r") return end
		frame:Hide()
	end)
	local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
	cancel:SetSize(80, 22)
	cancel:SetPoint("RIGHT", saveButton, "LEFT", -6, 0)
	cancel:SetText("Cancel")
	cancel:SetScript("OnClick", function() frame:Hide() end)
	message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	message:SetPoint("BOTTOMLEFT", 16, 14)
	message:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
	message:SetJustifyH("LEFT")
end

---@class ObviScribeFormSpec
---@field title string
---@field fields ObviScribeField[]
---@field values? table           what the fields start with
---@field helpers? string[]       fill-in buttons (see HELPERS)
---@field hint? string            a line under the fields
---@field onSave fun(values: table): string?   returns what is wrong, or nil to close

--- Opens the form.
---@param spec ObviScribeFormSpec
function Form.Open(spec)
	if not frame then Build() end
	if #spec.fields > MAX_ROWS then error("too many fields", 2) end
	current = { fields = spec.fields, onSave = spec.onSave }
	if frame["SetTitle"] then frame["SetTitle"](frame, spec.title) end
	for i, row in ipairs(rows) do
		local f = spec.fields[i]
		row.label:SetShown(f ~= nil)
		row.box:SetShown(f ~= nil)
		if f then
			row.label:SetText(f.label .. (f.required and " |cffff4040*|r" or ""))
			local v = spec.values and spec.values[f.key]
			row.box:SetText(v ~= nil and tostring(v) or "")
			row.box:SetCursorPosition(0)
		end
	end
	local y = -36 - #spec.fields * ROW - 6
	for _, b in ipairs(helperButtons) do b:Hide() end
	local x = 16
	for i, name in ipairs(spec.helpers or {}) do
		local h = HELPERS[name]
		local b = helperButtons[i]
		if not b then
			b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
			b:SetHeight(22)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			-- an item or spell dropped on a fill-in button fills the line in too
			b:SetScript("OnReceiveDrag", function()
				local kind, id, itemName = FromCursor()
				if kind then Fill({ id = id, name = itemName }) end
			end)
			helperButtons[i] = b
		end
		b:SetText(h.text)
		b:SetWidth(b:GetFontString():GetStringWidth() + 24)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", x, y)
		b:SetScript("OnClick", function(self) h.run(Fill, self) end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(h.tip)
			GameTooltip:Show()
		end)
		b:Show()
		x = x + b:GetWidth() + 4
	end
	if spec.helpers and #spec.helpers > 0 then y = y - 28 end
	message:SetText(spec.hint and ("|cff888888" .. spec.hint .. "|r") or "")
	frame:SetHeight(-y + 44)
	frame:Show()
	if rows[1].box:IsShown() then rows[1].box:SetFocus() end
end

--- The "only" field every line, step and guide has.
---@type ObviScribeField
Form.ONLY = { key = "only", label = "Only if (condition)", type = "text" }
