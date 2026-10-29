-- Quest log cleanup: lists the quests in your log that the loaded guide doesn't need (no line from the current step
-- to the end of the guide accepts, works on or turns them in), all ticked; untick the ones to keep, and
-- the button abandons the rest. "/og cleanup" or the gear menu opens it.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

local frame ---@type Frame?
local rows = {} ---@type CheckButton[]
local content ---@type Frame
local button ---@type Button
local empty ---@type FontString
local confirming = false
local ROW = 24

--- Every quest id a condition tree mentions ("onquest 123", "done 123"...): steps shown only for a quest need it.
---@param c any
---@param mark fun(id: integer)
local function CondQuests(c, mark)
	if type(c) ~= "table" then return end
	if (c[1] == "onquest" or c[1] == "ready" or c[1] == "done") and type(c[2]) == "number" then mark(c[2]) end
	for i = 2, #c do CondQuests(c[i], mark) end
end

local REASONS = { accept = "accept", turnin = "turn in", objective = "objective", kill = "kill", collect = "collect" }

--- The quests the loaded guide still needs, with why (the first step that needs each: "step 112: turn in"): from
--- the current step to the end of this guide. Not the guides after it, as Zygor does it: a leveling chain runs to the
--- level cap, so nearly every quest would be "needed" later.
---@return table<integer, string>
local function NeededQuests()
	local needed = {}
	local guide, step = Engine.Current()
	if not guide then return needed end
	for i = step and step.index or 1, #guide.steps do
		local s = guide.steps[i]
		local function mark(why) return function(id) needed[id] = needed[id] or ("step %d: %s"):format(i, why) end end
		CondQuests(s.cond, mark("step condition"))
		CondQuests(s.skip, mark("step skip"))
		for _, list in ipairs({ s.goals, s.side }) do
			local side = list == s.side and "side task " or ""
			for _, g in ipairs(list) do
				if g.quest then mark(side .. (REASONS[g.kind] or g.kind))(g.quest) end
				CondQuests(g.cond, mark(side .. "line condition"))
			end
		end
	end
	return needed
end

--- The quests in the log, split: the ones the guide doesn't need, and the ones it keeps (with why), each as
--- {id, title, level, header, why}; header is the quest log's category (usually the zone) it's listed under.
local function Unneeded()
	local needed, list, kept = NeededQuests(), {}, {}
	local header
	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local info = C_QuestLog.GetInfo(i)
		if info and info.isHeader then
			header = info.title
		elseif info and not info.isHidden and info.questID and info.questID > 0 and C_QuestLog.CanAbandonQuest(info.questID) then
			local q = { id = info.questID, title = info.title, level = info.level, header = header, why = needed[info.questID] }
			table.insert(q.why and kept or list, q)
		end
	end
	return list, kept
end

local function Ticked()
	local ids = {}
	for _, row in ipairs(rows) do if row:IsShown() and row:GetChecked() then table.insert(ids, row["questID"]) end end
	return ids
end

local function UpdateButton()
	local n = #Ticked()
	button:SetEnabled(n > 0)
	button:SetText(confirming and ("Click again to abandon %d"):format(n) or ("Abandon %d quest%s"):format(n, n == 1 and "" or "s"))
end

local headers, notes = {}, {} ---@type FontString[], FontString[]

--- "[24] Title", the level in the game's difficulty colour, as in the quest log.
local function LevelTitle(q)
	if not (q.level and q.level > 0) then return q.title end
	local color = _G["GetQuestDifficultyColor"] and _G["GetQuestDifficultyColor"](q.level)
	local level = color and ("|cff%02x%02x%02x[%d]|r "):format(color.r * 255, color.g * 255, color.b * 255, q.level)
		or ("[%d] "):format(q.level)
	return level .. q.title
end

local function Fill()
	local list, kept = Unneeded()
	local y, nRows, nHeaders, nNotes, last = 0, 0, 0, 0, nil
	-- a heading line: the quest log's categories, and "Kept for this guide"
	local function Header(text)
		nHeaders = nHeaders + 1
		local h = headers[nHeaders]
		if not h then
			h = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			h:SetJustifyH("LEFT")
			headers[nHeaders] = h
		end
		local gap = nHeaders > 1 and 8 or 2
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", 4, -(y + gap))
		h:SetText(text)
		h:Show()
		y = y + gap + 18
	end
	for _, q in ipairs(list) do
		-- the quest log's category above its quests, as the log shows it
		if q.header and q.header ~= last then last = q.header Header(q.header) end
		nRows = nRows + 1
		local row = rows[nRows]
		if not row then
			row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate") --[[@as CheckButton]]
			row:SetSize(ROW, ROW)
			row:SetScript("OnClick", function() confirming = false UpdateButton() end)
			rows[nRows] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 10, -y)
		row["questID"] = q.id
		row["text"]:SetText(LevelTitle(q))
		row:SetChecked(true)
		row:Show()
		y = y + ROW
	end
	-- the quests the guide keeps, and the first step that needs each, to see why one isn't offered
	if #kept > 0 then
		Header("Kept for this guide")
		for _, q in ipairs(kept) do
			nNotes = nNotes + 1
			local n = notes[nNotes]
			if not n then
				n = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				n:SetJustifyH("LEFT")
				n:SetWidth(300)
				notes[nNotes] = n
			end
			n:ClearAllPoints()
			n:SetPoint("TOPLEFT", 14, -y)
			n:SetText(LevelTitle(q) .. "  |cff888888" .. q.why .. "|r")
			n:Show()
			y = y + n:GetStringHeight() + 6
		end
	end
	for i = nRows + 1, #rows do rows[i]:Hide() end
	for i = nHeaders + 1, #headers do headers[i]:Hide() end
	for i = nNotes + 1, #notes do notes[i]:Hide() end
	content:SetHeight(math.max(1, y))
	empty:SetShown(#list == 0 and #kept == 0)
	confirming = false
	UpdateButton()
end

--- Abandons the quests one by one (a moment apart, so the game keeps up), then lists what's left.
---@param ids integer[]
local function Abandon(ids)
	local n = 0
	local function nextOne()
		local id = table.remove(ids, 1)
		if not id then
			ns.Print("abandoned %d quest%s", n, n == 1 and "" or "s")
			if frame and frame:IsShown() then Fill() end
			return
		end
		if C_QuestLog.IsOnQuest(id) and C_QuestLog.CanAbandonQuest(id) then
			C_QuestLog.SetSelectedQuest(id)
			C_QuestLog.SetAbandonQuest()
			C_QuestLog.AbandonQuest()
			n = n + 1
		end
		C_Timer.After(0.3, nextOne)
	end
	nextOne()
end

local function Build()
	-- the game's standard panel (Forever's own frame art), without the portrait, like the copy window
	local f = CreateFrame("Frame", "ObviGuideCleanupFrame", UIParent, "ButtonFrameTemplate") --[[@as Frame]]
	_G["ButtonFrameTemplate_HidePortrait"](f)
	if f["SetTitle"] then f["SetTitle"](f, "Quest Cleanup") end
	f:SetSize(380, 440)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	table.insert(_G["UISpecialFrames"], "ObviGuideCleanupFrame")   -- Escape closes it

	local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	intro:SetPoint("TOPLEFT", 16, -32)
	intro:SetPoint("TOPRIGHT", -16, -32)
	intro:SetJustifyH("LEFT")
	intro:SetText("Quests the current guide doesn't need from here on. Untick the ones you want to keep.")

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -60)
	scroll:SetPoint("BOTTOMRIGHT", -32, 44)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(320, 1)
	scroll:SetScrollChild(content)

	empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("TOP", scroll, "TOP", 0, -20)
	empty:SetText("Nothing to clean up.")

	button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate") --[[@as Button]]
	button:SetSize(200, 24)
	button:SetPoint("BOTTOM", 0, 12)
	button:SetScript("OnClick", function()
		if InCombatLockdown() then ns.Print("not in combat") return end
		-- two clicks: abandoning can't be undone
		if not confirming then confirming = true UpdateButton() return end
		confirming = false
		Abandon(Ticked())
		button:SetEnabled(false)
	end)
	f:SetScript("OnShow", Fill)
	frame = f
end

--- Opens the cleanup window (or refreshes it).
function ns.Cleanup()
	if not Engine.Current() then ns.Print("pick a guide first: the cleanup keeps what the guide needs") return end
	if not frame then Build() end
	---@cast frame Frame
	if frame:IsShown() then Fill() else frame:Show() end
end
