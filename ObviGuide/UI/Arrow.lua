-- The arrow, Obvi Guide's own way of showing the waypoint (the default, see Travel.lua), as Zygor and TomTom have one:
-- the game's navigation arrow turning towards the destination, with the step's first line and how far it is under it.
-- Drag it to move it; right-click hides it until the next step.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuideArrow
local Arrow = {}
ns.Arrow = Arrow

local SIZE = 72          -- the arrow's width in pixels (the art fills about two thirds of it)
local INTERVAL = 0.05    -- seconds between updates while there is a target (20 a second)
local ARRIVED = 10       -- yards, for points without a radius (the engine's arrival rule)
local TOP = -140         -- the stock place, under the top of the screen

--- How far to turn the arrow for a point `north` and `west` yards from the player, who faces `facing`
--- (GetPlayerFacing: radians, counter-clockwise from north, so pi/2 faces west). World coordinates grow to the
--- north and the west, so the bearing is atan2(west, north), counter-clockwise from north as the facing is.
--- The art points up and SetRotation turns counter-clockwise: 0 is straight ahead, pi/2 left, -pi/2 right.
--- Kept between -pi and pi.
---@param north number
---@param west number
---@param facing number
---@return number
function Arrow.Angle(north, west, facing)
	local a = math.atan2(west, north) - facing
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Everything below needs the game.

---@class ObviGuideArrowFrame : Frame
---@field Arrow Texture
---@field Check Texture
---@field Title FontString
---@field Distance FontString

local frame ---@type ObviGuideArrowFrame?
local target ---@type ObviGuidePoint?
local dismissed = false                  -- right-clicked away, until the next step
local driver = CreateFrame("Frame")      -- runs the updates while there is a target
driver:Hide()

-- a secret value (this engine hides some, the facing among them in places) can't be used
local canaccess = _G["canaccessvalue"] ---@type (fun(v: any): boolean)?

---@param f ObviGuideArrowFrame
local function Anchor(f)
	local at = ns.db and ns.db.arrow
	f:ClearAllPoints()
	if at then f:SetPoint(at.point, UIParent, at.relPoint, at.x, at.y) else f:SetPoint("TOP", UIParent, "TOP", 0, TOP) end
end

--- A texture's art: the game's atlas when this client has it, else a texture file.
---@param tex Texture
---@param atlas string
---@param file string
---@param w number    the atlas's size
---@param h number
---@param fw number   the file's size
---@param fh number
local function Art(tex, atlas, file, w, h, fw, fh)
	local info = C_Texture.GetAtlasInfo(atlas)
	if info then
		tex:SetAtlas(atlas)
		-- fitted in w×h, keeping the atlas's own shape
		local scale = math.min(w / info.width, h / info.height)
		tex:SetSize(info.width * scale, info.height * scale)
	else
		tex:SetTexture(file)
		tex:SetSize(fw, fh)
	end
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Obvi Guide", 1, 1, 1)
	GameTooltip:AddLine("Drag to move. Right-click hides it until the next step.", nil, nil, nil, true)
	GameTooltip:Show()
end

---@return ObviGuideArrowFrame
local function Build()
	local f = CreateFrame("Frame", nil, UIParent) --[[@as ObviGuideArrowFrame]]
	f:SetSize(SIZE + 8, SIZE + 8)
	f:SetFrameStrata("LOW")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() f:StartMoving() end)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, relPoint, x, y = f:GetPoint()
		if ns.db and point then ns.db.arrow = { point = point, relPoint = relPoint or point, x = x, y = y } end
	end)
	f:SetScript("OnMouseUp", function(_, button)
		if button ~= "RightButton" then return end
		dismissed = true
		driver:Hide()
		GameTooltip:Hide()
		f:Hide()
	end)
	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- the minimap's quest arrow, enlarged (Art\Arrow.tga, see tools\make_arrow.ps1); it points up
	f.Arrow = f:CreateTexture(nil, "ARTWORK")
	f.Arrow:SetTexture("Interface\\AddOns\\ObviGuide\\Art\\Arrow")
	f.Arrow:SetSize(SIZE, SIZE)
	f.Arrow:SetPoint("CENTER")
	-- arrived: a check mark in the arrow's place
	f.Check = f:CreateTexture(nil, "ARTWORK")
	Art(f.Check, "common-icon-checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready", 36, 36, 36, 36)
	f.Check:SetPoint("CENTER")
	f.Check:Hide()

	f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.Title:SetPoint("TOP", f, "BOTTOM", 0, -2)
	f.Title:SetWidth(260)
	f.Title:SetMaxLines(2)
	f.Distance = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.Distance:SetPoint("TOP", f.Title, "BOTTOM", 0, -3)
	Anchor(f)
	f:Hide()
	return f
end

local function Update()
	local f = frame
	if not f then return end
	local continent, me = ns.Travel.PlayerWorld()
	-- nothing to point at, put away, or no position to point from (an instance)
	if not target or dismissed or not me then f:Hide() return end
	f:Show()
	local c, w = ns.Travel.World(target)
	if not w or c ~= continent then
		f.Arrow:Hide()
		f.Check:Hide()
		f.Distance:SetText("Another continent")
		return
	end
	local north, west = w.x - me.x, w.y - me.y
	local yards = math.sqrt(north * north + west * west)
	local here = yards <= (target.radius or ARRIVED)
	f.Check:SetShown(here)
	f.Distance:SetText(here and "You're here" or ("%d yd"):format(math.floor(yards)))
	local facing = GetPlayerFacing()
	if facing and canaccess and not canaccess(facing) then facing = nil end
	-- no facing (some instances and restricted moments): the text only
	f.Arrow:SetShown(facing ~= nil and not here)
	if facing and not here then f.Arrow:SetRotation(Arrow.Angle(north, west, facing)) end
end

--- Points the arrow at a point, with its title (colour codes kept), or puts it away (nil).
---@param p? ObviGuidePoint
---@param title? string
function Arrow.Set(p, title)
	target, dismissed = p, false
	if p and not frame then frame = Build() end
	if frame then frame.Title:SetText(title or "") end
	driver:SetShown(p ~= nil)
	Update()
end

local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + dt
	if elapsed < INTERVAL then return end
	elapsed = 0
	Update()
end)
