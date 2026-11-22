-- The guide windows, styled after Forever's own damage meter (its header bar, background, title dropdown with an
-- arrow, gear and resize handle) with the objective tracker's check marks and fonts for the step lines. All of it
-- is the game's own art by atlas name, so it looks like part of the UI. A window shows the current step of the guide
-- it follows, its side tasks and a dimmed preview of the next steps.
-- There can be several windows, each following a guide of its own at the same time (the engine's followers): a
-- leveling guide in one, a profession in another. The one last used is the active one: the waypoint and the action
-- keys follow its step, and the others' titles are greyed.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

---@class ObviGuideWindow
local Window = {}
ns.Window = Window

local HEADER = 32
local MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH = 220, 600, 300
local WINDOW_GAP = 12   -- pixels between a new window and the one it's put beside
-- background opacity: the damage meter's default (Edit Mode "Background" 50%), which stays the same on hover
local BG_ALPHA, BG_ALPHA_HOVER = 0.5, 0.5
local DEFAULT_PREVIEW = 0   -- upcoming steps shown dimmed (none by default; the Options page changes it)
local LINE_FONT = "ObjectiveTrackerFont12"   -- the step lines (the header keeps the damage meter's font)
local ICON = 12
local LINE_GAP = 8    -- pixels between the goal lines of a step (about what Zygor uses)
local LEADING = 3     -- extra pixels between the rows of one wrapped line
local INLINE_ICON_Y = -4 -- icons inside the text: the game draws them above the middle of the letters (measured in game)
local SIDE_PAD = 10   -- pixels between the side tasks' line and the first task
local SIDE_BOX_GAP = 6   -- extra pixels between two side tasks
local STEP_GAP = 10   -- pixels after a step, before the side tasks and each previewed step (a bit more than LINE_GAP)
local DONE = CreateColor(0.6, 0.6, 0.6)
local TODO = CreateColor(1, 1, 1)
local DIM = CreateColor(0.55, 0.55, 0.55)
local IDLE_TITLE = CreateColor(0.6, 0.6, 0.6)   -- the title of a window that isn't the active one

---@class ObviGuideFrame : Frame
---@field Title FontString
---@field StepText FontString
---@field FwdPulse AnimationGroup   the next arrow's pulse, while you're back from the step the guide is on
---@field FwdGlow Frame
---@field Background Texture
---@field Body Frame
---@field Header Frame
---@field SideHeader Frame
---@field Continue Button|{text: FontString, action: fun()}   the guide end's "Continue with ..." link
---@field Resize Button
---@field collapsed boolean

---@class ObviGuideLine : Frame
---@field text FontString
---@field icon Texture
---@field dash FontString   the quest tracker's "- " in front of objectives, in the icon column
---@field Flash fun()     plays the "done" effect
---@field goal? ObviGuideGoal
---@field step? ObviGuideStep
---@field dim? boolean      a previewed step: no action
---@field side? boolean     a side task: the step's own NPC/target is not its target
---@field locked? string    an accept line for a quest you can't take yet: what it waits for ("needs Blessed Arm")
---@field quiet? boolean     a locked line whose quest a locked line below it needs: greyed, the reason left to that one
---@field sub FontString     a smaller line under the text: what a quest you can't take yet waits for, and Catch up

---@class ObviGuideClick : Button
---@field line? ObviGuideLine   the line it lies over

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
	if g and line.locked then return true end   -- a quest you can't take yet: Quest Catchup for it (PostClick)
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
	elseif g.craft and C_SpellBook.IsSpellKnown(g.craft) and not ns.Action.CraftReady(g) then
		-- a "Make …" line with its profession's window closed: opens it (casts the profession); open, PostClick makes it
		local profession = ns.Action.ProfessionSpell(g)
		if profession then
			b:SetAttribute("type", "spell")
			b:SetAttribute("spell", profession)
		end
	elseif target then
		b:SetAttribute("type", "macro")
		b:SetAttribute("macrotext", ns.TargetMacro(target, enemy))
	end
	if b:GetAttribute("type") then
		ns.Debug("line '%s': %s %s", g.text, b:GetAttribute("type"),
			tostring(b:GetAttribute("macrotext") or b:GetAttribute("item") or b:GetAttribute("spell")))
	end
	-- ticking off and showing the way happen after the click (PostClick), with or without a secure action
	return b:GetAttribute("type") ~= nil or g.kind == "confirm" or g.opens ~= nil or (g.point or line.step.dest) ~= nil
		or g.kind == "learn" or g.kind == "skill"   -- (trained by clicking while a trainer's window is open)
		or g.craft ~= nil   -- (makes its recipe)
		or g.places ~= nil   -- (shows the way to where to get it)
		or g.kind == "sell"   -- (sells the spare at an open merchant)
end

-- what clicking a line that uses an item or casts a spell does, for its tooltip
local ACTS = { use = "use", equip = "equip", hearth = "use", cast = "cast" }

--- What clicking the line does with an item or spell ("use", "equip", "cast"), or nil when it doesn't.
---@param g ObviGuideGoal
---@return string?
local function Acts(g)
	return g.id and ACTS[g.kind] or nil
end

--- Where clicking a line sets the waypoint: its own spot, or else the step's. Not a line that uses an item or casts
--- a spell (unless it has a spot of its own): that click is the action.
---@param b ObviGuideClick
---@return ObviGuidePoint?
local function ClickPoint(b)
	local g = b.line and b.line.goal
	if not g or b.line.dim then return nil end
	if Acts(g) then return g.point end
	-- (a collect line with where to get it: the nearest of those places)
	local place = Engine.NearestPlace(g)
	return g.point or (place and place.point) or b.line.step.dest
end

--- "Darkshore 39.0, 86.0" for a point.
---@param p ObviGuidePoint
local function PlaceName(p)
	local info = C_Map.GetMapInfo(p.map)
	return ("%s %.1f, %.1f"):format(info and info.name or "?", p.x * 100, p.y * 100)
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
	-- sell lines: a gold coin
	elseif k == "sell" then
		tex:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
	elseif k == "text" or k == nil then tex:SetTexture(nil)
	else line.dash:SetTextColor(line.text:GetTextColor()) line.dash:Show() end
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
	if g.kind == "confirm" and not g.done and not dim and not done then text = text .. " |cff888888(click when done)|r" end
	-- a quest you can't take yet: what it waits for, small, under it, and the catch-up the line's click starts
	if line.locked and not line.quiet then
		-- with what it's worth: the XP of the catch-up, the quest, and its chain after it (missed if you go on)
		-- and against the guide's own XP per step: worth the way or not
		local xp = g.quest and ns.Catchup.Worth(g.quest)
		local pace = xp and xp > 0 and ns.Catchup.Pace(g.quest --[[@as integer]])
		-- (the numbers with "Detailed catch-up numbers"; else just the verdict)
		local worth = ""
		-- "Needs Blessed Arm · Catch up: not worth it"
		if ns.db and ns.db.catchupDetails then
			if pace and xp then
				worth = (": %s, ~%d min, %s this guide's XP per minute"):format(ns.Catchup.Bars(xp),
					math.max(1, math.floor(pace.minutes + 0.5)),
					pace.ratio < 0.05 and "under 0.1x" or ("%.1fx"):format(pace.ratio))
				local behind = ns.Catchup.Behind()
				if behind then
					worth = worth .. (behind >= 0.05 and (", %.1f levels behind the guide"):format(behind)
						or behind <= -0.05 and (", %.1f levels ahead of the guide"):format(-behind) or ", on the guide's pace")
				end
			elseif xp and xp > 0 then
				worth = ": " .. ns.Catchup.XPText(xp)
			end
		elseif pace then
			local verdict, behind = ns.Catchup.Verdict(g.quest --[[@as integer]])
			worth = verdict == "worth" and ": |cff60d060worth it|r" or verdict == "even" and ": |cffd0b070about even|r"
				or ": not worth it"
			if behind then worth = worth .. " |cff888888(you're behind the guide)|r" end
		end
		line.sub:SetText(("%s  |cff666666·|r  |cffffd100Catch up|r%s"):format((line.locked:gsub("^%l", string.upper)),
			worth))
		line.sub:SetTextColor(0.6, 0.6, 0.6)
		line.sub:Show()
	end
	-- a note shown as a line of its own (in a side task, or with a condition) looks like the step's notes
	if g.note and not dim then text = "|cffd0b070" .. text .. "|r" end
	line.text:SetText(Inline(text))
	line.text:SetTextColor((dim and DIM or done and DONE or TODO):GetRGB())
	Icon(line, g, done)
	if not dim then
		if done and wasDone[g] == false then line.Flash() end
		wasDone[g] = done
	end
end

-- dividers between the steps shown (the current one and the previewed ones): the Settings panel's thin gold divider.
-- (The objective tracker's header art was a thin line on Forever but is a whole glowing header bar on retail.)
local SEP_ATLAS = "Options_HorizontalDivider"

-- Room around the lines: 6 px on the header's side, 18 px (the last line's gap + 10) on the far side. With the header
-- at the bottom the two swap, so the narrow one stays next to the header.
local NEAR, FAR = 6, 10
local function TopPad() return (ns.db and ns.db.flip) and (FAR + LINE_GAP) or NEAR end
local function EndPad() return (ns.db and ns.db.flip) and (NEAR - LINE_GAP) or FAR end

--- The "Header at the bottom" setting.
local function Flipped() return ns.db ~= nil and ns.db.flip == true end

-- The title's menu, as the damage meter's title switches what it shows: the window's guides (several can be open,
-- each where it was left: a leveling guide, a dungeon, a profession), one to switch to, each with a close button on
-- hover (as Edit Mode's layouts have theirs); "Add guide..." to open one more from the guide picker
-- (UI\GuidePicker.lua), and to open one in a window of its own.
local MenuTemplates = _G["MenuTemplates"] ---@type table?
local MenuVariants = _G["MenuVariants"] ---@type table?

-- One per guide window: its frame, its lines and its click layer, showing the step of the window's follower. A closed
-- window's view is kept for the next window opened (frames can't be thrown away).
---@class ObviGuideView
---@field f? ObviGuideFollower   the window it shows (nil: none, kept for the next one)
---@field frame ObviGuideFrame
---@field Bind fun(f?: ObviGuideFollower)
---@field Refresh fun()
---@field Arrange fun()      places the header (after "Header at the bottom" changed)
---@field Resync fun()       lays the click buttons over the lines again, if they changed in combat

local views = {} ---@type ObviGuideView[]
local shown = false   -- whether the guide windows are shown (/og shows and hides them all)

--- How many guide windows there are.
---@return integer
function Window.Count() return #Engine.Followers() end

--- The frame of the window before this one (where a new window is put beside), or nil.
---@param f ObviGuideFollower
---@return Frame?
local function FrameBefore(f)
	local prev
	for _, other in ipairs(Engine.Followers()) do
		if other == f then break end
		prev = other
	end
	for _, v in ipairs(views) do if prev and v.f == prev then return v.frame end end
end

---@param n integer   which view this is (for its frames' names: the first is ObviGuideFrame)
---@return ObviGuideView
local function NewView(n)
	local view = {}
	local F ---@type ObviGuideFollower?
	local frame ---@type ObviGuideFrame
	local suffix = n == 1 and "" or tostring(n)

	local lines = {} ---@type ObviGuideLine[]
	local used = 0

	local function Width() return frame:GetWidth() end

	--- Whether this is the first window (its place is account-wide; it can be hidden but not closed).
	local function First() return F ~= nil and F == Engine.Followers()[1] end

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
			line.sub = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			line.sub:SetPoint("TOPLEFT", line.text, "BOTTOMLEFT", 0, -2)
			line.sub:SetJustifyH("LEFT")
			line.sub:SetWordWrap(true)
			Flashes(line)
			lines[used] = line
		end
		line.goal, line.step, line.dim, line.side, line.locked, line.quiet = nil, nil, nil, nil, nil, nil
		line.sub:Hide()
		line:Show()
		return line
	end

	-- The click layer: invisible secure action buttons, one over each line that does something when clicked (target
	-- the mob or NPC, use the item, cast the spell, tick off, show the way). It lives outside the window, so the window
	-- itself is never locked in combat. The game won't let addons move or change secure buttons in a fight, so the
	-- whole layer is hidden in combat by the game's own rule (a state driver), and laid over the lines again after it.
	local clickLayer = CreateFrame("Frame", "ObviGuideClickLayer" .. suffix, UIParent)
	clickLayer:SetFrameStrata("MEDIUM")
	_G["RegisterStateDriver"](clickLayer, "visibility", "[combat] hide; show")   -- a FrameXML global
	local clicks = {} ---@type ObviGuideClick[]
	local clicksDirty = false   -- the lines changed in combat; lay the buttons over them again when it ends

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
			local line = self.line
			local g = line and line.goal
			if down or not (line and g) then return end   -- once per click: on the mouse-up
			-- (a click in a window makes it the active one: the waypoint and the keys follow it)
			if F then Engine.Focus(F) end
			if line.locked then ns.Catchup.Start(g.quest) return end
			if line.dim then return end
			if g.kind == "confirm" then Engine.Tick(g, line.step) end
			-- a "Sell …" line: sells the spare at an open merchant (else nothing: there's no way to show)
			if g.kind == "sell" then ns.Action.Sell(g) return end
			-- a recipe or rank the open trainer offers: trained
			if ns.Action.Train(g) then return end
			-- a "Make …" line whose recipe you know: made (or its window opened, by the secure click), no waypoint
			if g.craft and C_SpellBook.IsSpellKnown(g.craft) then ns.Action.Craft(g) return end
			-- a challenge's line opens the guide for it, beside this one
			if g.opens then Engine.Open(g.opens, true) return end
			-- (not when the way is shown there already, or you're there: clicking a "Talk to" line again and again to
			-- target the NPC shouldn't set the waypoint anew each time)
			local p = ClickPoint(self)
			if not p or ns.Travel.Already(p) then return end
			local place = Engine.NearestPlace(g)
			if p == g.point then ns.Travel.To(p, g.text)
			elseif place and p == place.point then ns.Travel.To(p, place.name or g.text)
			else ns.Travel.Show(line.step) end
		end)
		-- hovering a line says where clicking it sends you
		b:SetScript("OnEnter", function(self)
			local g = self.line and self.line.goal
			if g and self.line.locked then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText("|cffffd100Click|r for a catch-up guide to this quest: " .. self.line.locked)
				GameTooltip:Show()
				return
			end
			if g and g.opens and not self.line.dim then
				local guide = ns.FindGuide(g.opens)
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText("|cffffd100Click|r to open the guide |cffffd100" .. (guide and guide.title or g.opens) .. "|r")
				GameTooltip:Show()
				return
			end
			if g and not self.line.dim and g.kind == "sell" then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText(ns.Action.MerchantOpen() and "|cffffd100Click|r to sell the spare"
					or "At a merchant, |cffffd100click|r to sell the spare")
				GameTooltip:Show()
				return
			end
			if g and not self.line.dim and ns.Action.Service(g) then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText("|cffffd100Click|r to train it")
				GameTooltip:Show()
				return
			end
			if g and not self.line.dim and g.craft and C_SpellBook.IsSpellKnown(g.craft) then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				local open = not ns.Action.CraftReady(g) and ns.Action.ProfessionSpell(g)
				-- how many: what the skill points left need
				local count = ns.Action.CraftCount(g)
				local make = count and ("make " .. count) or "make all you can"
				GameTooltip:SetText(open and ("|cffffd100Click|r to open " .. open .. ", then again to " .. make)
					or ("|cffffd100Click|r to " .. make))
				GameTooltip:Show()
				return
			end
			local acts = g and not self.line.dim and Acts(g)
			if acts then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				-- the line's own words without its verb: "Use [Shiny Bauble]" -> "[Shiny Bauble]"
				local what = g.text:gsub("^%a+ ", "")
				GameTooltip:SetText("|cffffd100Click|r to " .. acts .. " " .. what)
				GameTooltip:Show()
				return
			end
			local p = ClickPoint(self)
			if not p then return end
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			local place = Engine.NearestPlace(g)
			local who = place and p == place.point and place.name and (" (" .. place.name .. ")") or ""
			GameTooltip:SetText("|cffffd100Click|r to set waypoint: |cffffd100" .. PlaceName(p) .. "|r" .. who)
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
		local showing = frame:IsShown() and not frame.collapsed
		if showing then clickLayer:SetFrameLevel(frame:GetFrameLevel() + 20) end
		local count = 0
		for i = 1, (showing and used or 0) do
			local line = lines[i]
			local left, top = line:GetLeft(), line:GetTop()
			if left and top then
				count = count + 1
				local b = clicks[count] or NewClick()
				clicks[count] = b
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
		for k = count + 1, #clicks do clicks[k]:Hide() clicks[k].line = nil end
	end

	--- Hides the click buttons while the window moves (they'd be left behind); SyncClicks puts them back.
	local function HideClicks()
		if InCombatLockdown() then clicksDirty = true return end
		for _, b in ipairs(clicks) do b:Hide() end
	end

	function view.Resync() if clicksDirty then SyncClicks() end end

	--- Lays out one line below the previous one; returns the new bottom offset.
	local function Place(line, y, indent)
		local w = Width()
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 10 + indent, -y)
		line.text:SetWidth(w - 24 - ICON - indent)
		local h = math.max(ICON, line.text:GetStringHeight())
		if line.sub:IsShown() then
			line.sub:SetWidth(w - 24 - ICON - indent)
			h = h + 2 + line.sub:GetStringHeight()
		end
		line:SetSize(w - 20 - indent, h)
		return y + h + LINE_GAP
	end

	---@param tip ObviGuideTip
	local function Tip(tip, y, dim)
		local line = Line()
		line.text:SetText(Inline(dim and tip.text or ("|cffd0b070" .. tip.text .. "|r")))
		line.text:SetTextColor((dim and DIM or TODO):GetRGB())
		Icon(line, nil, false)
		return Place(line, y, 0)   -- no extra indent: its text lines up with the text of the lines around it
	end

	--- The goal lines, with the step's notes (if given) each right after the line it follows in the guide.
	---@param step ObviGuideStep
	---@param goals ObviGuideGoal[]
	--- With `all`, the lines left out for you are shown too (greyed, as `dim` has them): a step that doesn't apply,
	--- gone to by hand, shows what it is about rather than only its talk line and notes.
	---@param tips? ObviGuideTip[]
	---@param all? boolean
	local function Goals(step, goals, y, dim, side, tips, all)
		tips = tips or {}
		local shownTips = {} ---@type table<ObviGuideTip, boolean>
		local function TipsAfter(goal)
			for _, tip in ipairs(tips) do
				if tip.after == goal then y = Tip(tip, y, dim) shownTips[tip] = true end
			end
		end
		TipsAfter(nil)
		-- the quests a locked accept here waits for: a locked line for one of them (turn in Blessed Arm, accept Armed
		-- and Ready) is shown greyed but quiet, so one chain says its reason and Catch up once, on the quest it leads to
		local waitedFor = {} ---@type table<integer, boolean>
		for _, g in ipairs(goals) do
			if g.kind == "accept" and g.quest and not Engine.IsVisible(g) and Engine.Locked(g) then
				local pre = Engine.PreQuests(g.quest, Engine.GuideOf(step, g))
				for _, list in ipairs(pre and { pre.all, pre.any } or {}) do
					for _, q in ipairs(list) do waitedFor[q] = true end
				end
			end
		end
		local box   -- the side box of the last line shown: a gap before the next box's lines sets the tasks apart
		for _, g in ipairs(goals) do
			-- a quest you can't take yet (its chain began in a guide you skipped) shows greyed out, with what it waits for
			local locked = not Engine.IsVisible(g) and Engine.Locked(g) or nil
			if locked or all or Engine.IsVisible(g) then
				if side and g.box and box and g.box ~= box then y = y + SIDE_BOX_GAP end
				box = g.box or box
				local line = Line()
				line.goal, line.step, line.dim, line.side = g, step, dim or locked ~= nil, side
				line.locked = locked
				line.quiet = locked ~= nil and g.quest ~= nil and waitedFor[g.quest] or nil
				RenderLine(line)
				y = Place(line, y, 0)
			end
			TipsAfter(g)
		end
		-- notes whose line was folded away go last
		for _, tip in ipairs(tips) do if not shownTips[tip] then y = Tip(tip, y, dim) end end
		return y
	end

	local separators, sepUsed = {}, 0 ---@type Texture[], integer

	--- A divider across the window, centred on y; returns where the next step starts.
	local function Separator(y)
		sepUsed = sepUsed + 1
		local sep = separators[sepUsed]
		if not sep then
			sep = frame.Body:CreateTexture(nil, "ARTWORK")
			local info = C_Texture.GetAtlasInfo(SEP_ATLAS)
			if info then
				sep:SetAtlas(SEP_ATLAS)
				sep:SetHeight(math.max(1, math.min(info.height, 4)))
			else
				sep:SetColorTexture(1, 0.82, 0, 0.5)   -- a client without it: a plain gold line
				sep:SetHeight(2)
			end
			separators[sepUsed] = sep
		end
		sep:ClearAllPoints()
		sep:SetPoint("LEFT", frame.Body, "TOPLEFT", 13, -y)    -- as wide as the side tasks' thin line
		sep:SetPoint("RIGHT", frame.Body, "TOPRIGHT", -12, -y)
		sep:Show()
		return y + STEP_GAP
	end

	local function Finish(y)
		for k = used + 1, #lines do lines[k]:Hide() end
		for k = sepUsed + 1, #separators do separators[k]:Hide() end
		frame:SetHeight(HEADER + y + EndPad())
		SyncClicks()
	end

	local titleColor ---@type colorRGB   the title's own colour (the damage meter's gold)

	--- Whether this window's title is greyed: another window is the active one.
	local function Idle() return F ~= nil and Window.Count() > 1 and F ~= Engine.Active() end

	--- Lays the window out for its current step. Works in combat too: only the click buttons wait for the fight to end.
	function view.Refresh()
		local f = F
		if not f or not frame:IsShown() then return end
		local guide, step = f:Current()
		frame.Title:SetText(guide and guide.title or "Obvi Guide")
		frame.Title:SetTextColor((Idle() and IDLE_TITLE or titleColor):GetRGB())
		frame.StepText:SetText(guide and step and ("%d/%d"):format(step.index, #guide.steps) or "")
		if f:Behind() then
			if not frame.FwdPulse:IsPlaying() then frame.FwdPulse:Play() end
		elseif frame.FwdPulse:IsPlaying() then
			frame.FwdPulse:Stop()
			frame.FwdGlow:SetAlpha(0)
		end
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
		local ended, nextTitle = f:Ended()
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
		-- a step with nothing in it for you (its lines wait on a quest you haven't got: Stranglethorn Vale 37-38's first
		-- step, the Small Brass Key from Viznik's bank), gone to by hand: the guide passes it by, so all of it shows
		-- greyed, rather than a talk line and a note about something that isn't there
		local applies = Engine.StepState(step)
		y = Goals(step, step.goals, y, not applies, false, step.tips, not applies)
		-- side tasks
		local open = {}
		local boxes = {} ---@type table<table, boolean>   each side box: still open (a done one goes with its notes)
		for _, g in ipairs(step.side) do
			local box = g.box or { g }
			if boxes[box] == nil then boxes[box] = Engine.SideOpen(box, step) end
			if boxes[box] and Engine.IsVisible(g) and not Engine.IsComplete(g, step) then table.insert(open, g) end
		end
		if #open > 0 then
			y = y + STEP_GAP - LINE_GAP
			frame.SideHeader:ClearAllPoints()
			frame.SideHeader:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 4, -y)
			frame.SideHeader:SetWidth(Width() - 8)
			frame.SideHeader:Show()
			y = Goals(step, open, y + 1 + SIDE_PAD, false, true)
		end
		-- dimmed preview of the next steps that apply
		local previewed, i = 0, step.index + 1
		local preview = ns.db and ns.db.previewSteps or DEFAULT_PREVIEW
		while previewed < preview and guide.steps[i] do
			local nxt = guide.steps[i]
			if (Engine.StepState(nxt)) then
				y = Separator(y + STEP_GAP - LINE_GAP)
				y = Goals(nxt, nxt.goals, y, true)
				previewed = previewed + 1
			end
			i = i + 1
		end
		Finish(y)
	end

	--- Anchors the window at its header's edge: by its top-left corner, so a taller or shorter step grows or shrinks
	--- it downwards only; with the header at the bottom, by its bottom-left corner, so it grows upwards and the header
	--- stays. (Dragging leaves it anchored by whichever point is nearest, often the centre, which grows both ways.)
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

	--- Places the header at the top (the lines below it) or, with "Header at the bottom", at the bottom (the lines
	--- above it), and the resize handle at the far corner. The background's gradient turns with it, so its dark part
	--- stays behind the header: the art is turned half a turn (SetRotation works on this client, swapped texture
	--- coordinates don't; tested with a scratch addon), and the resize handle a quarter turn into its new corner.
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

	--- Where the window is, saved: the first window's account-wide, another's with its tabs.
	local function SavePosition()
		Pin()
		if not F then return end
		local point, _, relPoint, x, y = frame:GetPoint()
		if First() then
			if ns.db then
				ns.db.window = { point = point, relPoint = relPoint, x = x, y = y, width = Width(), height = frame:GetHeight() }
			end
		else
			F.slot.at = { point = point, relPoint = relPoint, x = x, y = y, width = Width() }
		end
	end

	--- Puts the window where it was left; a new window beside the window before it (to its left, or its right when
	--- there's no room).
	local function PlaceWindow()
		local saved = First() and ns.db and ns.db.window or (not First() and F and F.slot.at)
		frame:ClearAllPoints()
		frame:SetWidth(DEFAULT_WIDTH)
		local fresh = false
		if saved then
			frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x, saved.y)
			frame:SetWidth(math.max(MIN_WIDTH, math.min(MAX_WIDTH, saved.width or DEFAULT_WIDTH)))
		else
			local before = F and not First() and FrameBefore(F)
			local left, right, top = before and before:GetLeft(), before and before:GetRight(), before and before:GetTop()
			if left and right and top then
				local x = left - WINDOW_GAP - DEFAULT_WIDTH
				if x < 0 then x = right + WINDOW_GAP end
				frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
				fresh = true
			else
				frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
			end
		end
		Arrange()
		Pin()   -- older saves, and the default spot, may be anchored by another point
		if fresh then SavePosition() end
	end

	local function SetupSettingsMenu(_, root)
		-- the settings live on ObviGuide's page in the game's Options
		root:CreateButton("Settings", function() ns.Options.Open() end)
		root:CreateDivider()
		-- (for this window's guide)
		root:CreateButton("Quest Catchup", function()
			if F then Engine.Focus(F) end
			ns.Catchup.Start()
		end)
		root:CreateButton("Quest Cleanup", function() ns.Cleanup() end)
		root:CreateButton("Destroy cheapest item", function() ns.DestroyCheapest() end)
		root:CreateButton(Window.Count() > 1 and "Hide all (/og shows them again)" or "Hide (/og shows it again)",
			function() Window.Hide() end)
		if F and not First() then root:CreateButton("Close this window", function() if F then Engine.CloseWindow(F) end end) end
	end

	local function GuidesMenu(_, root)
		local f = F
		if not f then return end
		local tabs, shownTab = f:Tabs()
		root:CreateTitle("Active guides")
		for i, tab in ipairs(tabs) do
			if tab.guide then
				local g = ns.FindGuide(tab.guide)
				local radio = root:CreateRadio(g and g.title or tab.guide, function() return i == shownTab end,
					function()
						Engine.Focus(f)
						f:SwitchTab(i)
					end)
				if MenuTemplates and MenuTemplates.AttachAutoHideCancelButton and MenuVariants then
					radio:AddInitializer(function(button, _, menu)
						local close = MenuTemplates.AttachAutoHideCancelButton(button)
						MenuTemplates.SetUtilityButtonTooltipText(close, "Close this guide")
						MenuTemplates.SetUtilityButtonAnchor(close, MenuVariants.GearButtonAnchor, button)
						MenuTemplates.SetUtilityButtonClickHandler(close, function()
							f:CloseTab(i)
							menu:Close()
						end)
					end)
				end
			end
		end
		root:CreateDivider()
		root:CreateButton("Add guide...", function() ns.GuidePicker.Open(true, f) end)
		root:CreateButton("Add guide in a new window...", function() ns.GuidePicker.Open("window") end)
		if #tabs > 1 then root:CreateButton("Move this guide to a new window", function() Engine.MoveTab(f, shownTab) end) end
		if not (MenuTemplates and MenuTemplates.AttachAutoHideCancelButton) then   -- (no close buttons on this client)
			root:CreateButton("Close this guide", function() f:CloseTab(shownTab) end)
		end
	end

	--- The title clicked: the guides menu, or straight to the guide picker while the window has no guide.
	---@param owner Frame
	local function TitleClick(owner)
		if F and F:Current() then MenuUtil.CreateContextMenu(owner, GuidesMenu) else ns.GuidePicker.Open(false, F) end
	end

	--- Hovering the title of a window that isn't the active one says so.
	---@param owner Frame
	local function TitleEnter(owner)
		if not Idle() then return end
		GameTooltip:SetOwner(owner, "ANCHOR_TOP")
		GameTooltip:SetText(frame.Title:GetText() or "Obvi Guide")
		GameTooltip:AddLine("The waypoint and action keys follow another window. Click a line or an arrow here to "
			.. "have them follow this one.", 1, 1, 1, true)
		GameTooltip:Show()
	end

	--- Goes a step on or back by hand (the arrows, the step counter, Continue): the window becomes the active one.
	---@param go fun(f: ObviGuideFollower)
	local function ByHand(go)
		if not F then return end
		Engine.Focus(F)
		go(F)
	end

	frame = CreateFrame("Frame", "ObviGuideFrame" .. suffix, UIParent) --[[@as ObviGuideFrame]]
	frame:Hide()
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
	-- mouse): clicking it or the title text opens the guides menu (GuidesMenu)
	local picker = CreateFrame("DropdownButton", nil, header, "WowStyle1ArrowDropdownTemplate")
	picker.hasShadow = false
	picker:SetPoint("TOPLEFT", 1, -3)   -- header offsets copied from the damage meter (Blizzard_DamageMeter)
	picker:EnableMouse(false)
	frame.Title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
	frame.Title:SetPoint("LEFT", picker.Arrow or picker, "RIGHT", 0, 3)
	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetWordWrap(false)
	titleColor = CreateColor(frame.Title:GetTextColor())
	-- plain buttons over the arrow and the title: a click opens the guides menu, a drag moves the window
	for _, region in ipairs({ picker --[[@as Frame]], frame.Title }) do
		local b = CreateFrame("Button", nil, header)
		b:SetAllPoints(region)
		b:SetScript("OnClick", TitleClick)
		b:SetScript("OnEnter", TitleEnter)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
	---@param state boolean
	local function Collapse(state)
		frame.collapsed = state
		collapse:SetNormalAtlas(state and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all")
		collapse:SetPushedAtlas(state and "ui-questtrackerbutton-expand-all-pressed" or "ui-questtrackerbutton-collapse-all-pressed")
	end
	collapse:SetScript("OnClick", function()
		Collapse(not frame.collapsed)
		view.Refresh()
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
		b:SetScript("OnClick", function(_, button)
			ByHand(function(f) if button == "RightButton" then f:Jump(dir) else f:Step(dir) end end)
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip)
			local at = dir > 0 and F and F:Behind()
			if at then GameTooltip:AddLine(("You went back: the guide is at step %d."):format(at), 1, 0.82, 0) end
			GameTooltip:AddLine(dir > 0 and "Right-click: next unfinished step" or "Right-click: back to an unfinished step", 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end
	local fwd = Arrow("common-icon-forwardarrow", gear, 1, "Next step")
	local back = Arrow("common-icon-backarrow", fwd, -1, "Previous step")
	-- the next arrow pulses gold while you're back from the step the guide is on: lit up, swelling a little
	local glow = CreateFrame("Frame", nil, fwd)
	glow:SetAllPoints()
	glow:SetFrameLevel(fwd:GetFrameLevel() + 1)
	local lit = glow:CreateTexture(nil, "OVERLAY")
	lit:SetAtlas("common-icon-forwardarrow")
	lit:SetAllPoints()
	lit:SetBlendMode("ADD")
	lit:SetVertexColor(1, 0.82, 0)
	glow:SetAlpha(0)
	local pulse = glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.7)
	local swell = pulse:CreateAnimation("Scale")
	swell:SetScaleFrom(0.95, 0.95)
	swell:SetScaleTo(1.2, 1.2)
	swell:SetOrigin("CENTER", 0, 0)
	swell:SetDuration(0.7)
	frame.FwdPulse, frame.FwdGlow = pulse, glow
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
		local to = tonumber(self:GetText())
		CloseGoTo()
		if to then ByHand(function(f) f:GoTo(to) end) end
	end)
	goTo:SetScript("OnEscapePressed", CloseGoTo)
	goTo:SetScript("OnEditFocusLost", CloseGoTo)
	local counter = CreateFrame("Button", nil, header)
	counter:SetAllPoints(frame.StepText)
	counter:SetScript("OnClick", function()
		if not F then return end
		local _, step = F:Current()
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
	frame.Continue.action = function() ByHand(function(f) f:Continue() end) end
	frame.Continue:SetScript("OnClick", function(self) if self.action then self.action() end end)
	frame.Continue:Hide()

	-- the damage meter's resize handle, shown while the mouse is over the window; it changes the width
	frame.Resize = CreateFrame("Button", nil, frame)
	frame.Resize:SetSize(40, 40)
	frame.Resize:SetNormalAtlas("damagemeters-scalehandle")
	frame.Resize:SetHighlightAtlas("damagemeters-scalehandle-hover")
	frame.Resize:SetPushedAtlas("damagemeters-scalehandle-pressed")
	frame.Resize:SetAlpha(0)
	frame.Resize:SetScript("OnMouseDown", function() frame:StartSizing("RIGHT") end)
	frame.Resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() SavePosition() view.Refresh() end)

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
	frame:SetScript("OnSizeChanged", function() if frame.Resize:GetButtonState() == "PUSHED" then view.Refresh() end end)
	frame:SetScript("OnShow", function() view.Refresh() end)
	frame:SetScript("OnHide", HideClicks)

	--- Shows a window's follower in this view (put where that window was left), or with none, hides it.
	function view.Bind(f)
		F, view.f = f, f
		if not f then frame:Hide() return end
		Collapse(false)   -- (a view kept from a closed window starts open)
		PlaceWindow()
		frame:SetShown(shown)
		view.Refresh()
	end

	--- After "Header at the bottom" changes: the header moves, and the window stays where it is on screen.
	function view.Arrange()
		Arrange()
		SavePosition()
		view.Refresh()
	end

	view.frame = frame
	return view --[[@as ObviGuideView]]
end

---@param f ObviGuideFollower
---@return ObviGuideView?
local function ViewOf(f)
	for _, v in ipairs(views) do if v.f == f then return v end end
end

--- A view for each guide window the engine has (made, or one kept from a closed window), and none for a closed one.
local function Sync()
	local fs = Engine.Followers()
	local open = {} ---@type table<ObviGuideFollower, boolean>
	for _, f in ipairs(fs) do open[f] = true end
	for _, v in ipairs(views) do if v.f and not open[v.f] then v.Bind(nil) end end
	for _, f in ipairs(fs) do
		if not ViewOf(f) then
			local free
			for _, v in ipairs(views) do if not v.f then free = v break end end
			if not free then
				free = NewView(#views + 1)
				table.insert(views, free)
			end
			free.Bind(f)
		end
	end
end

--- Lays every window out for its current step.
function Window.Refresh()
	for _, v in ipairs(views) do if v.f then v.Refresh() end end
end

--- After "Header at the bottom" changes: the headers move, and the windows stay where they are on screen.
function Window.Arrange()
	for _, v in ipairs(views) do if v.f then v.Arrange() end end
end

--- Shows the guide windows.
function Window.Show()
	shown = true
	Sync()
	for _, v in ipairs(views) do if v.f then v.frame:Show() end end
	Window.Refresh()
end

--- Hides the guide windows (/og shows them again).
function Window.Hide()
	shown = false
	for _, v in ipairs(views) do v.frame:Hide() end
end

function Window.Toggle()
	if shown then Window.Hide() else Window.Show() end
end

ns:On("PLAYER_REGEN_ENABLED", function() for _, v in ipairs(views) do v.Resync() end end)
ns:On("OBVIGUIDE_STEP", function() Window.Refresh() end)
ns:On("OBVIGUIDE_UPDATE", function() Window.Refresh() end)
ns:On("OBVIGUIDE_GUIDES_ADDED", function() Window.Refresh() end)
-- a window opened or closed (the others' titles grey or not with it)
ns:On("OBVIGUIDE_WINDOWS", function()
	Sync()
	Window.Refresh()
end)
ns:On("PLAYER_LOGIN", function() Window.Show() end)
