-- Challenges: in the game's legacy challenges window (WoW Forever's achievements), a "Guide" button on each challenge
-- a guide leads through (a guide with `challenge = id`), which opens that guide in a tab of its own.
--
-- The window is Blizzard_LegacySystem, loaded on demand. Its challenge list is a ScrollBox whose rows get Init(row,
-- data) with the challenge's id in data.id, each time a row is set up or reused (as Leatrix Plus finds the selected
-- challenge), so the button is set there.
local _, ns = ...
---@cast ns ObviGuideNS

--- The guide for a challenge: one meant for this character first, else any.
---@param id integer
---@return ObviGuideGuide?
local function GuideFor(id)
	local any
	for _, g in ipairs(ns.guides) do
		if g.challenge == id then
			if ns.Conditions.Eval(g.cond) then return g end
			any = any or g
		end
	end
	return any
end

local buttons = setmetatable({}, { __mode = "k" }) ---@type table<Frame, Button>

---@param b Button
local function OnClick(b)
	local g = b["guide"] ---@type ObviGuideGuide?
	if not g then return end
	ns.Engine.Open(g.name or g.title, true)
	ns.Window.Show()
end

---@param b Button
local function OnEnter(b)
	local g = b["guide"] ---@type ObviGuideGuide?
	if not g then return end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:SetText("|cffffd100Click|r to open the guide |cffffd100" .. g.title .. "|r")
	GameTooltip:Show()
end

--- Shows the button on a challenge's row when a guide leads through it, and hides it otherwise.
---@param row Frame
---@param data? {id?: integer}
local function Update(row, data)
	local g = data and data.id and GuideFor(data.id)
	local b = buttons[row]
	if not g then
		if b then b:Hide() end
		return
	end
	if not b then
		b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate") --[[@as Button]]
		b:SetSize(56, 20)
		b:SetText("Guide")
		b:SetPoint("RIGHT", row, "RIGHT", -10, 0)
		b:SetFrameLevel(row:GetFrameLevel() + 5)
		b:SetScript("OnClick", OnClick)
		b:SetScript("OnEnter", OnEnter)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		buttons[row] = b
	end
	b["guide"] = g
	b:Show()
end

local hooked = setmetatable({}, { __mode = "k" }) ---@type table<Frame, boolean>
---@param row any
local function Hook(row)
	if not row or type(row.Init) ~= "function" or hooked[row] then return end
	hooked[row] = true
	hooksecurefunc(row, "Init", Update)
	-- (a row set up before the hook: its data, if the list keeps it on the row)
	if type(row.GetElementData) == "function" then Update(row, row:GetElementData()) end
end

local function Attach()
	local window = _G["LegacySystemFrame"]
	local page = window and window.ChallengesPage
	local box = page and page.DetailPane and page.DetailPane.ScrollBox
	if not box then
		ns.Debug("legacy challenges: no challenge list found; no guide buttons")
		return
	end
	box:ForEachFrame(Hook)
	_G["ScrollUtil"].AddAcquiredFrameCallback(box, function(_, row) Hook(row) end, ns)
end

-- (FrameXML globals; the window is only on WoW Forever)
local EventUtil = _G["EventUtil"]
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded("Blizzard_LegacySystem", Attach)
end
