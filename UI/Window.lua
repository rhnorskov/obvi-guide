-- The guide window, styled after Forever's own damage meter (its header bar, background, title dropdown with an
-- arrow, gear and resize handle) with the objective tracker's check marks and fonts for the step lines. All of it
-- is the game's own art by atlas name, so it looks like part of the UI. It shows the current step, its side tasks
-- and a dimmed preview of the next steps.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

---@class ObviGuideWindow
local Window = {}
ns.Window = Window

local HEADER = 32
local MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH = 220, 600, 300
-- background opacity: the damage meter's default (Edit Mode "Background" 50%), which stays the same on hover
local BG_ALPHA, BG_ALPHA_HOVER = 0.5, 0.5
local DEFAULT_PREVIEW = 0   -- upcoming steps shown dimmed (none by default; the Options page changes it)
local LINE_FONT = "ObjectiveTrackerFont12"   -- the step lines (the header keeps the damage meter's font)
local ICON = 12
local LINE_GAP = 8    -- pixels between the goal lines of a step (about what Zygor uses)
local LEADING = 3     -- extra pixels between the rows of one wrapped line
local INLINE_ICON_Y = -4 -- icons inside the text: the game draws them above the middle of the letters (measured in game)
local SIDE_PAD = 10   -- pixels between the side tasks' line and the first task
local STEP_GAP = 10   -- pixels after a step, before the side tasks and each previewed step (a bit more than LINE_GAP)
local DONE = CreateColor(0.6, 0.6, 0.6)
local TODO = CreateColor(1, 1, 1)
local DIM = CreateColor(0.55, 0.55, 0.55)

---@class ObviGuideFrame : Frame
---@field Title FontString
---@field StepText FontString
---@field Background Texture
---@field Body Frame
---@field Header Frame
---@field SideHeader Frame
---@field Continue Button|{text: FontString}   the guide end's "Continue with ..." button
---@field Resize Button
---@field collapsed boolean
local frame

---@class ObviGuideLine : Frame
---@field text FontString
---@field icon Texture
---@field dash FontString   the quest tracker's "- " in front of objectives, in the icon column
---@field Flash fun()     plays the "done" effect
---@field goal? ObviGuideGoal
---@field step? ObviGuideStep
---@field dim? boolean      a previewed step: no action
---@field side? boolean     a side task: the step's own NPC/target is not its target

---@class ObviGuideClick : Button
---@field line? ObviGuideLine   the line it lies over

local lines = {} ---@type ObviGuideLine[]
local used = 0

local function Width() return frame:GetWidth() end

--- The objective tracker's "done" effect on a line (as ObjectiveTrackerAnimLineTemplate has it): the check mark
--- pops with a glow, and a golden bar glow sweeps across the line and fades.
---@param line ObviGuideLine
local function Flashes(line)
	local _, fontHeight = line.text:GetFont()
	local checkGlow = line:CreateTexture(nil, "OVERLAY")
	checkGlow:SetAtlas("ui-questtracker-tracker-check-glow")
	checkGlow:SetSize(ICON + 6, ICON + 6)
	checkGlow:SetPoint("CENTER", line.icon)
	checkGlow:SetAlpha(0)
	local glow = line:CreateTexture(nil, "OVERLAY")
	glow:SetAtlas("ui-questtracker-objfx-barglow")
	glow:SetPoint("TOPLEFT", line.text, "TOPLEFT", -2, 2)
	glow:SetSize(180, (fontHeight or ICON) + 6)
	glow:SetAlpha(0)

	local check = line:CreateAnimationGroup()
	check:SetToFinalAlpha(true)
	local up = check:CreateAnimation("Scale")
	up:SetTarget(line.icon) up:SetDuration(0.15) up:SetScaleFrom(1, 1) up:SetScaleTo(1.2, 1.2) up:SetSmoothing("OUT")
	local down = check:CreateAnimation("Scale")
	down:SetTarget(line.icon) down:SetStartDelay(0.15) down:SetDuration(0.15) down:SetScaleFrom(1.2, 1.2) down:SetScaleTo(1, 1)
	local glowIn = check:CreateAnimation("Alpha")
	glowIn:SetTarget(checkGlow) glowIn:SetDuration(0.15) glowIn:SetFromAlpha(0) glowIn:SetToAlpha(1)
	local glowOut = check:CreateAnimation("Alpha")
	glowOut:SetTarget(checkGlow) glowOut:SetStartDelay(0.15) glowOut:SetDuration(0.15) glowOut:SetFromAlpha(1) glowOut:SetToAlpha(0)

	local sweep = line:CreateAnimationGroup()
	sweep:SetToFinalAlpha(true)
	local grow = sweep:CreateAnimation("Scale")
	grow:SetTarget(glow) grow:SetStartDelay(0.1) grow:SetDuration(0.66) grow:SetSmoothing("OUT")
	grow:SetScaleFrom(0.01, 1) grow:SetScaleTo(1, 1) grow:SetOrigin("LEFT", 0, 0)
	local show = sweep:CreateAnimation("Alpha")
	show:SetTarget(glow) show:SetDuration(0.1) show:SetFromAlpha(0) show:SetToAlpha(1)
	local fade = sweep:CreateAnimation("Alpha")
	fade:SetTarget(glow) fade:SetStartDelay(0.43) fade:SetDuration(0.58) fade:SetFromAlpha(1) fade:SetToAlpha(0)

	line.Flash = function() check:Restart() sweep:Restart() end
end

-- whether each goal was done when last drawn: a line flashes only when it turns done in front of the player (not when
-- a guide or step opens with lines already done)
local wasDone = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGoal, boolean>

--- A line: an icon (dash, check, quest mark) and wrapped text, as plain frames, so the window can lay itself out
--- at any time, in combat too. Clicking is done by secure buttons on a layer of their own laid over the lines
--- (see SyncClicks).
---@return ObviGuideLine
local function Line()
	used = used + 1
	local line = lines[used]
	if not line then
		line = CreateFrame("Frame", nil, frame.Body) --[[@as ObviGuideLine]]
		line.icon = line:CreateTexture(nil, "ARTWORK")
		line.text = line:CreateFontString(nil, "ARTWORK", LINE_FONT)
		-- centred on the first row of the text, whatever the icon's size
		local _, fontHeight = line.text:GetFont()
		line.icon:SetPoint("CENTER", line, "TOPLEFT", ICON / 2, -(fontHeight or ICON) / 2)
		line.text:SetPoint("TOPLEFT", ICON + 4, 0)
		-- the dash ends where the text starts and shares its top, so it sits on the text's first row
		line.dash = line:CreateFontString(nil, "ARTWORK", LINE_FONT)
		line.dash:SetPoint("TOPRIGHT", line, "TOPLEFT", ICON + 4, 0)
		line.dash:SetText(_G["QUEST_DASH"] or "- ")
		line.text:SetJustifyH("LEFT")
		line.text:SetWordWrap(true)
		line.text:SetSpacing(LEADING)
		Flashes(line)
		lines[used] = line
	end
	line.goal, line.step, line.dim, line.side = nil, nil, nil, nil
	line:Show()
	return line
end

-- The click layer: invisible secure action buttons, one over each line that does something when clicked (target
-- the mob or NPC, use the item, cast the spell, tick off, show the way). It lives outside the window, so the window
-- itself is never locked in combat. The game won't let addons move or change secure buttons in a fight, so the
-- whole layer is hidden in combat by the game's own rule (a state driver), and laid over the lines again after it.
local clickLayer = CreateFrame("Frame", "ObviGuideClickLayer", UIParent)
clickLayer:SetFrameStrata("MEDIUM")
_G["RegisterStateDriver"](clickLayer, "visibility", "[combat] hide; show")   -- a FrameXML global
local clicks = {} ---@type ObviGuideClick[]
local clicksDirty = false   -- the lines changed in combat; lay the buttons over them again when it ends

--- What clicking a line does, as secure attributes; returns whether the click does anything.
---@param b ObviGuideClick
---@param line ObviGuideLine
---@return boolean
local function ClickAction(b, line)
	b:SetAttribute("type", nil)
	b:SetAttribute("item", nil)
	b:SetAttribute("spell", nil)
	b:SetAttribute("macrotext", nil)
	local g = line.goal
	if not g or line.dim or not line.step then return false end
	local k = g.kind
	-- the line's target, or all of them when it names several mobs (the macro takes the first one found)
	local target, enemy = g.target and g.target.name, g.target and g.target.enemy ---@type string|string[]|nil, boolean?
	if g.targets and #g.targets > 1 then
		target = {}
		for _, t in ipairs(g.targets) do table.insert(target, t.name) end
	end
	if (k == "use" or k == "equip" or k == "hearth") and g.id then
		b:SetAttribute("type", "item")
		b:SetAttribute("item", "item:" .. g.id)
	elseif k == "cast" and g.id then
		b:SetAttribute("type", "spell")
		b:SetAttribute("spell", g.id)
	elseif target then
		b:SetAttribute("type", "macro")
		b:SetAttribute("macrotext", ns.TargetMacro(target, enemy))
	end
	if b:GetAttribute("type") then
		ns.Debug("line '%s': %s %s", g.text, b:GetAttribute("type"),
			tostring(b:GetAttribute("macrotext") or b:GetAttribute("item") or b:GetAttribute("spell")))
	end
	-- ticking off and showing the way happen after the click (PostClick), with or without a secure action
	return b:GetAttribute("type") ~= nil or g.kind == "confirm" or g.kind == "goto" or g.point ~= nil
end

--- "Darkshore 39.0, 86.0" for a point.
---@param p ObviGuidePoint
local function PlaceName(p)
	local info = C_Map.GetMapInfo(p.map)
	return ("%s %.1f, %.1f"):format(info and info.name or "?", p.x * 100, p.y * 100)
end

---@return ObviGuideClick
local function NewClick()
	local b = CreateFrame("Button", nil, clickLayer, "SecureActionButtonTemplate") --[[@as ObviGuideClick]]
	-- secure actions fire on key-down when the "cast on key down" setting is on (the default), else on key-up
	b:RegisterForClicks("AnyDown", "AnyUp")
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 0, 0)
	hl:SetPoint("BOTTOMRIGHT", 0, 0)
	hl:SetColorTexture(1, 1, 1, 0.06)
	b:SetScript("PostClick", function(self, _, down)
		local g = self.line and self.line.goal
		if down or not g or self.line.dim then return end   -- once per click: on the mouse-up
		if g.kind == "confirm" then Engine.Tick(g) end
		-- a line with its own spot sets the waypoint there (as Zygor does); a "go to" line without one, the step's
		if g.point then ns.Travel.To(g.point, g.text)
		elseif g.kind == "goto" then local _, step = Engine.Current() ns.Travel.Show(step) end
	end)
	-- hovering a line with its own spot says where clicking it sends you
	b:SetScript("OnEnter", function(self)
		local g = self.line and self.line.goal
		if not (g and g.point) or self.line.dim then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("|cffffd100Click|r to set waypoint: |cffffd100" .. PlaceName(g.point) .. "|r")
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

--- Lays the click buttons over the lines the window shows now. Out of combat only; in combat the layer is hidden
--- and this waits for the fight to end.
local function SyncClicks()
	if InCombatLockdown() then clicksDirty = true return end
	clicksDirty = false
	local showing = frame and frame:IsShown() and not frame.collapsed
	if showing then clickLayer:SetFrameLevel(frame:GetFrameLevel() + 20) end
	local n = 0
	for i = 1, (showing and used or 0) do
		local line = lines[i]
		local left, top = line:GetLeft(), line:GetTop()
		if left and top then
			n = n + 1
			local b = clicks[n] or NewClick()
			clicks[n] = b
			b.line = line
			if ClickAction(b, line) then
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left - 4, top + 2)
				b:SetSize(line:GetWidth() + 6, line:GetHeight() + 4)
				b:Show()
			else
				b:Hide()
			end
		end
	end
	for k = n + 1, #clicks do clicks[k]:Hide() clicks[k].line = nil end
end

--- Hides the click buttons while the window moves (they'd be left behind); SyncClicks puts them back.
local function HideClicks()
	if InCombatLockdown() then clicksDirty = true return end
	for _, b in ipairs(clicks) do b:Hide() end
end

--- Text-height icons inside a guide's text ("|Tpath:0|t"), moved to the middle of the letters.
---@param s string
---@return string
local function Inline(s)
	return (s:gsub("|T([^:|]+):0|t", "|T%1:0:0:0:" .. INLINE_ICON_Y .. "|t"))
end

---@param line ObviGuideLine
local function Icon(line, goal, done)
	local tex = line.icon
	line.dash:Hide()
	tex:SetTexture(nil)
	tex:SetTexCoord(0, 1, 0, 1)
	tex:SetVertexColor(1, 1, 1)
	tex:SetSize(ICON, ICON)
	if done then tex:SetAtlas("ui-questtracker-tracker-check") return end
	local k = goal and goal.kind
	if k == "accept" then tex:SetAtlas("QuestNormal")
	elseif k == "turnin" then tex:SetAtlas("QuestTurnin")
	elseif k == "talk" then tex:SetTexture("Interface\\GossipFrame\\GossipGossipIcon")
	elseif k == "hearth" and goal.id then tex:SetTexture(C_Item.GetItemIconByID(goal.id))
	-- kill lines: the attack cursor's sword (also a kill line without a quest, a text line with an enemy to target)
	elseif k == "kill" or (k == "text" and goal.target and goal.target.enemy) then
		tex:SetTexture("Interface\\Cursor\\Crosshair\\Attack")
		tex:SetSize(ICON - 2, ICON - 2)   -- the sword fills its whole square, so it looks bigger than the others
	-- collect lines: the loot cursor's pouch (the same pouch Questie draws on its maps)
	elseif k == "collect" then
		tex:SetTexture("Interface\\Cursor\\Crosshair\\LootAll")
	elseif k == "text" or k == nil then tex:SetTexture(nil)
	else line.dash:SetTextColor(line.text:GetTextColor()) line.dash:Show() end
end

--- Lays out one line below the previous one; returns the new bottom offset.
local function Place(line, y, indent)
	local w = Width()
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 10 + indent, -y)
	line.text:SetWidth(w - 24 - ICON - indent)
	local h = math.max(ICON, line.text:GetStringHeight())
	line:SetSize(w - 20 - indent, h)
	return y + h + LINE_GAP
end

--- Text, colour and icon of a goal line from the game's state.
---@param line ObviGuideLine
local function RenderLine(line)
	local g, step, dim = line.goal, line.step, line.dim
	if not (g and step) then return end
	local done = not dim and Engine.IsComplete(g, step)
	local text = g.text
	local progress = not dim and Engine.Progress(g)
	-- the progress, with what it counts when the line's text doesn't say it: "(7/8 Abandoned Belongings)"
	local counted = progress and g.what and (progress .. " " .. g.what) or progress or g.what
	if counted then text = text .. " |cffaaaaaa(" .. counted .. ")|r" end
	-- the action key, next to the line it acts on
	-- (a line naming several mobs has a key for each: shown right after that mob's name)
	for _, h in ipairs(dim and {} or ns.Action.Hints(g)) do
		local tag = " |cff4fc3f7[" .. h.hint .. "]|r"
		local s, e = nil, nil
		if h.name then s, e = text:find(h.name, 1, true) end
		if s and e then
			if text:sub(e + 1, e + 2) == "|r" then e = e + 2 end   -- after the name's colour ends
			text = text:sub(1, e) .. tag .. text:sub(e + 1)
		else
			text = text .. " " .. tag
		end
	end
	if g.kind == "confirm" and not dim and not done then text = text .. " |cff888888(click when done)|r" end
	line.text:SetText(Inline(text))
	line.text:SetTextColor((dim and DIM or done and DONE or TODO):GetRGB())
	Icon(line, g, done)
	if not dim then
		if done and wasDone[g] == false then line.Flash() end
		wasDone[g] = done
	end
end

---@param tip ObviGuideTip
local function Tip(tip, y)
	local line = Line()
	line.text:SetText(Inline("|cffd0b070" .. tip.text .. "|r"))
	line.text:SetTextColor(1, 1, 1)
	Icon(line, nil, false)
	return Place(line, y, 0)   -- no extra indent: its text lines up with the text of the lines around it
end

--- The goal lines, with the step's notes (if given) each right after the line it follows in the guide.
---@param step ObviGuideStep
---@param goals ObviGuideGoal[]
---@param tips? ObviGuideTip[]
local function Goals(step, goals, y, dim, side, tips)
	tips = tips or {}
	local shown = {} ---@type table<ObviGuideTip, boolean>
	local function TipsAfter(goal)
		for _, tip in ipairs(tips) do
			if tip.after == goal then y = Tip(tip, y) shown[tip] = true end
		end
	end
	TipsAfter(nil)
	for _, g in ipairs(goals) do
		if Engine.IsVisible(g) then
			local line = Line()
			line.goal, line.step, line.dim, line.side = g, step, dim, side
			RenderLine(line)
			y = Place(line, y, 0)
		end
		TipsAfter(g)
	end
	-- notes whose line was folded away go last
	for _, tip in ipairs(tips) do if not shown[tip] then y = Tip(tip, y) end end
	return y
end

-- dividers between the steps shown (the current one and the previewed ones): the objective tracker's header line
local SEP_ATLAS = "UI-QuestTracker-Secondary-Objective-Header"
local SEP_HEIGHT = 22   -- the frame the art is centred in; its drawn line sits at about the frame's bottom edge
local separators, sepUsed = {}, 0 ---@type Frame[], integer

--- A divider across the window with its line at y; returns where the next step starts.
local function Separator(y)
	sepUsed = sepUsed + 1
	local sep = separators[sepUsed]
	if not sep then
		sep = CreateFrame("Frame", nil, frame.Body)
		sep:SetHeight(SEP_HEIGHT)
		local art = sep:CreateTexture(nil, "BACKGROUND")
		-- stretched across the window; the art has empty margins (about 14 left, 17 right), so it reaches past the
		-- frame for the drawn line to start where the text starts and end as far in from the right edge
		art:SetAtlas(SEP_ATLAS)
		local info = C_Texture.GetAtlasInfo(SEP_ATLAS)
		art:SetHeight(info and info.height or SEP_HEIGHT)
		art:SetPoint("LEFT", -6, 0)
		art:SetPoint("RIGHT", 9, 0)
		separators[sepUsed] = sep
	end
	sep:ClearAllPoints()
	sep:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 4, -(y - SEP_HEIGHT))
	sep:SetPoint("TOPRIGHT", frame.Body, "TOPRIGHT", -4, -(y - SEP_HEIGHT))
	sep:Show()
	return y + 4 + STEP_GAP   -- a little room for the art's shading under the line
end

-- Room around the lines: 6 px on the header's side, 18 px (the last line's gap + 10) on the far side. With the header
-- at the bottom the two swap, so the narrow one stays next to the header.
local NEAR, FAR = 6, 10
local function TopPad() return (ns.db and ns.db.flip) and (FAR + LINE_GAP) or NEAR end
local function EndPad() return (ns.db and ns.db.flip) and (NEAR - LINE_GAP) or FAR end

local function Finish(y)
	for k = used + 1, #lines do lines[k]:Hide() end
	for k = sepUsed + 1, #separators do separators[k]:Hide() end
	frame:SetHeight(HEADER + y + EndPad())
	SyncClicks()
end

--- Lays the window out for the current step. Works in combat too: only the click buttons wait for the fight to end.
function Window.Refresh()
	if not frame or not frame:IsShown() then return end
	local guide, step = Engine.Current()
	frame.Title:SetText(guide and guide.title or "Obvi Guide")
	frame.StepText:SetText(guide and step and ("%d/%d"):format(step.index, #guide.steps) or "")
	used, sepUsed = 0, 0
	frame.SideHeader:Hide()
	if frame.collapsed then
		frame.Body:Hide()
		for k = 1, #lines do lines[k]:Hide() end
		frame:SetHeight(HEADER)
		SyncClicks()
		return
	end
	frame.Body:Show()
	-- the guide's end: a line saying so, and a button on to the guide that follows (when we have it)
	local ended, nextTitle = Engine.Ended()
	frame.Continue:Hide()
	if guide and ended then
		frame.StepText:SetText("end")
		local line = Line()
		line.text:SetText(("You've reached the end of |cffffd100%s|r."):format(guide.title))
		line.text:SetTextColor(TODO:GetRGB())
		Icon(line, nil, false)
		local y = Place(line, TopPad(), 0)
		if nextTitle then
			frame.Continue.text:SetText(("Continue with |cffffd100%s|r"):format(nextTitle))
			frame.Continue:ClearAllPoints()
			frame.Continue:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 10 + ICON + 4, -y)
			frame.Continue:SetSize(Width() - 24 - ICON, frame.Continue.text:GetStringHeight() + 6)
			frame.Continue:Show()
			y = y + frame.Continue:GetHeight() + LINE_GAP
		else
			local hint = Line()
			hint.text:SetText("|cff888888No guide follows it here: pick the next one from the title above.|r")
			Icon(hint, nil, false)
			y = Place(hint, y, 0)
		end
		Finish(y)
		return
	end
	if not guide or not step then
		local line = Line()
		line.text:SetText(#ns.guides == 0 and "No guides loaded. Add a guide pack." or "Pick a guide: click the title above.")
		line.text:SetTextColor(TODO:GetRGB())
		Icon(line, nil, false)
		Finish(Place(line, TopPad(), 0))
		return
	end
	local y = TopPad()
	y = Goals(step, step.goals, y, false, false, step.tips)
	-- side tasks
	local open = {}
	for _, g in ipairs(step.side) do if Engine.IsVisible(g) and not Engine.IsComplete(g, step) then table.insert(open, g) end end
	if #open > 0 then
		y = y + STEP_GAP - LINE_GAP
		frame.SideHeader:ClearAllPoints()
		frame.SideHeader:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 4, -y)
		frame.SideHeader:SetWidth(Width() - 8)
		frame.SideHeader:Show()
		y = Goals(step, open, y + 1 + SIDE_PAD, false, true)
	end
	-- dimmed preview of the next steps that apply
	local shown, i = 0, step.index + 1
	local preview = ns.db and ns.db.previewSteps or DEFAULT_PREVIEW
	while shown < preview and guide.steps[i] do
		local nxt = guide.steps[i]
		if (Engine.StepState(nxt)) then
			y = Separator(y + STEP_GAP - LINE_GAP)
			y = Goals(nxt, nxt.goals, y, true)
			shown = shown + 1
		end
		i = i + 1
	end
	Finish(y)
end

--- The "Header at the bottom" setting.
local function Flipped() return ns.db ~= nil and ns.db.flip == true end

--- Anchors the window at its header's edge: by its top-left corner, so a taller or shorter step grows or shrinks it
--- downwards only; with the header at the bottom, by its bottom-left corner, so it grows upwards and the header stays.
--- (Dragging leaves it anchored by whichever point is nearest, often the centre, which grows both ways.)
local function Pin()
	local left, top, bottom = frame:GetLeft(), frame:GetTop(), frame:GetBottom()
	if not (left and top and bottom) then return end
	frame:ClearAllPoints()
	if Flipped() then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	else
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	end
end

--- Places the header at the top (the lines below it) or, with "Header at the bottom", at the bottom (the lines above
--- it), and the resize handle at the far corner. The background's gradient turns with it, so its dark part stays
--- behind the header: the art is turned half a turn (SetRotation works on this client, swapped texture coordinates
--- don't; tested with a scratch addon), and the resize handle a quarter turn into its new corner.
local function Arrange()
	local turn = Flipped() and math.pi or 0
	frame.Background:SetRotation(turn)
	for _, tex in ipairs({ frame.Resize:GetNormalTexture(), frame.Resize:GetHighlightTexture(), frame.Resize:GetPushedTexture() }) do
		if tex then tex:SetRotation(Flipped() and math.pi / 2 or 0) end
	end
	local header, body, flip = frame.Header, frame.Body, Flipped()
	header:ClearAllPoints()
	body:ClearAllPoints()
	frame.Resize:ClearAllPoints()
	if flip then
		header:SetPoint("BOTTOMLEFT")
		header:SetPoint("BOTTOMRIGHT")
		body:SetPoint("TOPLEFT")
		body:SetPoint("BOTTOMRIGHT", 0, HEADER)
		frame.Resize:SetPoint("TOPRIGHT", 6, 6)
	else
		header:SetPoint("TOPLEFT")
		header:SetPoint("TOPRIGHT")
		body:SetPoint("TOPLEFT", 0, -HEADER)
		body:SetPoint("BOTTOMRIGHT")
		frame.Resize:SetPoint("BOTTOMRIGHT", 6, -6)
	end
end

local function SavePosition()
	Pin()
	local point, _, relPoint, x, y = frame:GetPoint()
	if ns.db then ns.db.window = { point = point, relPoint = relPoint, x = x, y = y, width = Width(), height = frame:GetHeight() } end
end

local function SetupSettingsMenu(_, root)
	-- the settings live on ObviGuide's page in the game's Options
	root:CreateButton("Settings", function() ns.Options.Open() end)
	root:CreateDivider()
	root:CreateButton("Quest Cleanup", function() ns.Cleanup() end)
	root:CreateButton("Hide (/og shows it again)", function() frame:Hide() end)
end

local function Build()
	frame = CreateFrame("Frame", "ObviGuideFrame", UIParent) --[[@as ObviGuideFrame]]
	frame:SetSize(DEFAULT_WIDTH, 120)
	frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(MIN_WIDTH, HEADER, MAX_WIDTH, 2000)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("MEDIUM")
	frame.collapsed = false

	-- the damage meter's background; a little see-through until the mouse is over the window
	frame.Background = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.Background:SetAtlas("damagemeters-background")
	-- from the very top, behind the header bar, as the damage meter has it: the gradient's dark part then sits right
	-- under the header, behind the first lines
	frame.Background:SetPoint("TOPLEFT")
	frame.Background:SetPoint("BOTTOMRIGHT")
	frame.Background:SetAlpha(BG_ALPHA)

	-- header: the damage meter's header bar; drag it to move the window
	local header = CreateFrame("Frame", nil, frame)
	frame.Header = header   -- (Arrange places it at the top or the bottom)
	header:SetHeight(HEADER)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() HideClicks() frame:StartMoving() end)
	header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() SavePosition() SyncClicks() end)
	local bar = header:CreateTexture(nil, "BACKGROUND")
	bar:SetAtlas("ui-damagemeters-header-bar")
	bar:SetAllPoints()

	-- the title looks like a dropdown with an arrow, like "Damage Done"; the arrow is only art (it gets no menu and no
	-- mouse): clicking it or the title text opens the guide picker (UI\GuidePicker.lua)
	local picker = CreateFrame("DropdownButton", nil, header, "WowStyle1ArrowDropdownTemplate")
	picker.hasShadow = false
	picker:SetPoint("TOPLEFT", 1, -3)   -- header offsets copied from the damage meter (Blizzard_DamageMeter)
	picker:EnableMouse(false)
	frame.Title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
	frame.Title:SetPoint("LEFT", picker.Arrow or picker, "RIGHT", 0, 3)
	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetWordWrap(false)
	-- plain buttons over the arrow and the title: a click opens the picker, a drag moves the window
	for _, region in ipairs({ picker --[[@as Frame]], frame.Title }) do
		local b = CreateFrame("Button", nil, header)
		b:SetAllPoints(region)
		b:SetScript("OnClick", function() ns.GuidePicker.Toggle() end)
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnDragStart", function() HideClicks() frame:StartMoving() end)
		b:SetScript("OnDragStop", function() frame:StopMovingOrSizing() SavePosition() SyncClicks() end)
	end

	-- right side: collapse (the tracker's button, as the damage meter uses it), the gear menu, step arrows, counter
	local collapse = CreateFrame("Button", nil, header)
	collapse:SetSize(18, 19)
	collapse:SetPoint("TOPRIGHT", -3, -5)
	collapse:SetNormalAtlas("ui-questtrackerbutton-collapse-all")
	collapse:SetPushedAtlas("ui-questtrackerbutton-collapse-all-pressed")
	collapse:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
	collapse:SetScript("OnClick", function(self)
		frame.collapsed = not frame.collapsed
		self:SetNormalAtlas(frame.collapsed and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all")
		self:SetPushedAtlas(frame.collapsed and "ui-questtrackerbutton-expand-all-pressed" or "ui-questtrackerbutton-collapse-all-pressed")
		Window.Refresh()
	end)

	-- the gear: the damage meter's settings button art on a plain dropdown button
	local gear = CreateFrame("DropdownButton", nil, header)
	gear:SetSize(27, 27)
	gear:SetPoint("RIGHT", collapse, "LEFT", -2, -2)
	local gearIcon = gear:CreateTexture(nil, "ARTWORK")
	gearIcon:SetAllPoints()
	local function GearArt(state) gearIcon:SetAtlas("common-dropdown-a-button-settings-" .. state .. "shadowless", true) end
	GearArt("")
	gear:SetScript("OnEnter", function() GearArt("hover-") end)
	gear:SetScript("OnLeave", function() GearArt("") end)
	gear:SetScript("OnMouseDown", function() GearArt("pressed-") end)
	gear:SetScript("OnMouseUp", function() GearArt("hover-") end)
	gear:SetupMenu(SetupSettingsMenu)

	local function Arrow(atlas, anchor, dir, tip)
		local b = CreateFrame("Button", nil, header)
		b:SetSize(16, 16)
		b:SetPoint("RIGHT", anchor, "LEFT", -2, anchor == gear and 3 or 0)   -- the damage meter puts its session text 3 above the gear
		b:SetNormalAtlas(atlas)
		b:SetHighlightAtlas(atlas, "ADD")
		-- left-click: one step; right-click: fast forward / back to an unfinished step (as Zygor's arrows do)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function(_, button) if button == "RightButton" then Engine.Jump(dir) else Engine.Step(dir) end end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip)
			GameTooltip:AddLine(dir > 0 and "Right-click: next unfinished step" or "Right-click: back to an unfinished step", 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end
	local fwd = Arrow("common-icon-forwardarrow", gear, 1, "Next step")
	local back = Arrow("common-icon-backarrow", fwd, -1, "Previous step")
	frame.StepText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.StepText:SetPoint("RIGHT", back, "LEFT", -4, 0)
	frame.Title:SetPoint("RIGHT", frame.StepText, "LEFT", -6, 0)

	-- clicking the counter turns it into a number box: type a step and Enter goes there, Escape leaves it
	local goTo = CreateFrame("EditBox", nil, header, "InputBoxTemplate") --[[@as EditBox]]
	goTo:SetSize(42, 18)
	goTo:SetPoint("RIGHT", back, "LEFT", -6, 0)
	goTo:SetAutoFocus(false)
	goTo:SetNumeric(true)
	goTo:SetMaxLetters(5)
	goTo:SetJustifyH("CENTER")
	goTo:SetFontObject("GameFontHighlightSmall")
	goTo:Hide()
	local function CloseGoTo() goTo:ClearFocus() goTo:Hide() frame.StepText:Show() end
	goTo:SetScript("OnEnterPressed", function(self)
		local n = tonumber(self:GetText())
		CloseGoTo()
		if n then Engine.GoTo(n) end
	end)
	goTo:SetScript("OnEscapePressed", CloseGoTo)
	goTo:SetScript("OnEditFocusLost", CloseGoTo)
	local counter = CreateFrame("Button", nil, header)
	counter:SetAllPoints(frame.StepText)
	counter:SetScript("OnClick", function()
		local _, step = Engine.Current()
		if not step then return end
		frame.StepText:Hide()
		goTo:SetText(tostring(step.index))
		goTo:Show()
		goTo:SetFocus()
		goTo:HighlightText()
	end)
	counter:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Go to step...")
		GameTooltip:AddLine("Click and type a step number", 1, 1, 1)
		GameTooltip:Show()
	end)
	counter:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- body: the step lines
	frame.Body = CreateFrame("Frame", nil, frame)

	frame.SideHeader = CreateFrame("Frame", nil, frame.Body)
	frame.SideHeader:SetHeight(1)
	-- side tasks are set off by a thin gold line only, no title (the steps get the tracker's bold header line, see Separator)
	local sideLine = frame.SideHeader:CreateTexture(nil, "ARTWORK")
	sideLine:SetColorTexture(1, 0.82, 0, 0.25)
	sideLine:SetHeight(1)
	sideLine:SetPoint("LEFT", 9, 0)    -- tuned by eye against the steps' divider line
	sideLine:SetPoint("RIGHT", -8, 0)
	frame.SideHeader:Hide()

	-- the guide end's "Continue with <next guide>" (a plain button: it works in combat too)
	frame.Continue = CreateFrame("Button", nil, frame.Body) --[[@as Button|{text: FontString}]]
	frame.Continue.text = frame.Continue:CreateFontString(nil, "ARTWORK", LINE_FONT)
	frame.Continue.text:SetPoint("LEFT", 0, 0)
	frame.Continue.text:SetPoint("RIGHT", 0, 0)
	frame.Continue.text:SetJustifyH("LEFT")
	local contHl = frame.Continue:CreateTexture(nil, "HIGHLIGHT")
	contHl:SetPoint("TOPLEFT", -4, 2)
	contHl:SetPoint("BOTTOMRIGHT", 2, -2)
	contHl:SetColorTexture(1, 1, 1, 0.06)
	frame.Continue:SetScript("OnClick", function() Engine.Continue() end)
	frame.Continue:Hide()

	-- the damage meter's resize handle, shown while the mouse is over the window; it changes the width
	frame.Resize = CreateFrame("Button", nil, frame)
	frame.Resize:SetSize(40, 40)
	frame.Resize:SetNormalAtlas("damagemeters-scalehandle")
	frame.Resize:SetHighlightAtlas("damagemeters-scalehandle-hover")
	frame.Resize:SetPushedAtlas("damagemeters-scalehandle-pressed")
	frame.Resize:SetAlpha(0)
	frame.Resize:SetScript("OnMouseDown", function() frame:StartSizing("RIGHT") end)
	frame.Resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() SavePosition() Window.Refresh() end)

	-- hover: background fully opaque and the resize handle shown, as the damage meter does
	local hovering = false
	frame:SetScript("OnUpdate", function()
		local over = frame:IsMouseOver() or frame.Resize:IsMouseOver()
		if over ~= hovering then
			hovering = over
			frame.Background:SetAlpha(over and BG_ALPHA_HOVER or BG_ALPHA)
			frame.Resize:SetAlpha(over and 1 or 0)
		end
	end)
	frame:SetScript("OnSizeChanged", function() if frame.Resize:GetButtonState() == "PUSHED" then Window.Refresh() end end)
	frame:SetScript("OnShow", Window.Refresh)
	frame:SetScript("OnHide", HideClicks)

	local saved = ns.db and ns.db.window
	if saved then
		frame:ClearAllPoints()
		frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x, saved.y)
		frame:SetWidth(math.max(MIN_WIDTH, math.min(MAX_WIDTH, saved.width or DEFAULT_WIDTH)))
	end
	Arrange()
	Pin()   -- older saves, and the default spot, may be anchored by another point
end

--- After "Header at the bottom" changes: the header moves, and the window stays where it is on screen.
function Window.Arrange()
	if not frame then return end
	Arrange()
	SavePosition()
	Window.Refresh()
end

function Window.Toggle()
	if not frame then Build() frame:Show() return end
	frame:SetShown(not frame:IsShown())
end

function Window.Show()
	if not frame then Build() end
	frame:Show()
	Window.Refresh()
end

ns:On("PLAYER_REGEN_ENABLED", function() if clicksDirty then SyncClicks() end end)
ns:On("OBVIGUIDE_STEP", function() Window.Refresh() end)
ns:On("OBVIGUIDE_UPDATE", function() Window.Refresh() end)
ns:On("OBVIGUIDE_GUIDES_ADDED", function() Window.Refresh() end)
ns:On("PLAYER_LOGIN", function() Window.Show() end)
