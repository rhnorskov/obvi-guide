-- Copy window: text in a selectable box, for things to copy out of the game (chat can't be copied). The text comes
-- up selected, so Ctrl+C copies it all. Escape or the close button hides it.
local _, ns = ...
---@cast ns ObviGuideNS

local frame ---@type Frame?
local box ---@type EditBox

local function Build()
	-- the game's standard panel (Forever's own frame art), without the portrait
	local f = CreateFrame("Frame", "ObviGuideCopyFrame", UIParent, "ButtonFrameTemplate") --[[@as Frame]]
	_G["ButtonFrameTemplate_HidePortrait"](f)
	f:SetSize(560, 420)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	table.insert(_G["UISpecialFrames"], "ObviGuideCopyFrame")   -- Escape closes it

	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -32)
	scroll:SetPoint("BOTTOMRIGHT", -32, 32)
	box = CreateFrame("EditBox", nil, scroll) --[[@as EditBox]]
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetWidth(510)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(box)

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 16, 12)
	hint:SetText("Ctrl+C copies the selected text; Ctrl+A selects it all again.")
	frame = f
end

--- Shows text in the copy window, selected.
---@param title string
---@param text string
function ns.Copy(title, text)
	if not frame then Build() end
	---@cast frame Frame
	if frame["SetTitle"] then frame["SetTitle"](frame, title) end   -- the panel template's title
	box:SetText(text)
	frame:Show()
	box:SetFocus()
	box:SetCursorPosition(0)   -- scrolled to the top
	box:HighlightText()
end
