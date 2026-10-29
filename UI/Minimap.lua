-- Minimap pins, as Zygor has them: while a step is current, its path points are small quest-yellow dots on the minimap
-- and its destination a gold pin. The destination stays on the minimap's edge when it is farther away, so it shows
-- the way to go. Points on another continent (or anywhere while the player is in an instance) are not shown.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuideMinimapPins
local Pins = {}
ns.MinimapPins = Pins

local DOT, DEST = 7, 16              -- pin sizes in minimap pixels (tuned in game: 8 without a rim was hard to see, 10 too big)
local RIM = 1.5                      -- the dark rim around each dot
local EDGE = 14                      -- the clamped destination sits this far inside the edge (clear of the ring art)
local INTERVAL = 0.05                -- seconds between updates while pins are shown
local DOTCOLOR = { 1, 0.82, 0 }      -- the game's own quest yellow (as quest titles and objectives are drawn)
local GOLD = { 1, 0.82, 0 }
-- the minimap's diameter in yards by zoom level (0..5), for clients without C_Minimap.GetViewRadius
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

--- Where a point lies on the minimap, in pixels from its centre (x to the right, y up), and whether it is on it.
--- World coordinates run the other way round from the map's: world x grows to the north and world y to the west,
--- so the caller passes how far north and west of the player the point is; east (minus west) is right, north is up.
--- A rotating minimap turns with the player so that where they face is up. GetPlayerFacing is in radians,
--- counter-clockwise from north (pi/2 faces west), so the offset is turned clockwise by the facing.
---@param north number    yards the point lies north of the player
---@param west number     yards it lies west
---@param radius number   yards from the minimap's centre to its edge
---@param half number     pixels from the minimap's centre to its edge
---@param facing? number  the player's facing, when the minimap rotates
---@param square? boolean a square minimap (else round)
---@return number x, number y, boolean inside
function Pins.Offset(north, west, radius, half, facing, square)
	local scale = half / radius
	local x, y = -west * scale, north * scale
	if facing then
		local c, s = math.cos(facing), math.sin(facing)
		x, y = x * c + y * s, y * c - x * s
	end
	local far = square and math.max(math.abs(x), math.abs(y)) or math.sqrt(x * x + y * y)
	return x, y, far <= half
end

--- An offset moved in along its direction to `edge` pixels from the centre (onto the minimap's rim).
---@param x number
---@param y number
---@param edge number
---@param square? boolean
---@return number x, number y
function Pins.Clamp(x, y, edge, square)
	local far = square and math.max(math.abs(x), math.abs(y)) or math.sqrt(x * x + y * y)
	if far <= edge or far == 0 then return x, y end
	return x * edge / far, y * edge / far
end

-- Everything below needs the game.

---@class ObviGuidePin : Frame
---@field tex Texture
---@field continent? integer      where the point is, in world coordinates (set for the current step)
---@field world? Vector2DMixin

local dots = {} ---@type ObviGuidePin[]   the path dots, reused from step to step
local used = 0                           -- how many of them the current step shows
local dest ---@type ObviGuidePin?
local step ---@type ObviGuideStep?
local driver = CreateFrame("Frame")      -- runs the updates while there are pins
driver:Hide()

--- A pin's art: the first of the game's atlases that exists, or else a tinted circle (a white square with a round
--- mask), so a missing atlas never shows as a green box.
---@param pin ObviGuidePin
---@param atlases string[]
---@param color number[]
---@param tint boolean   tint the atlas too (a white blip), or keep its own colours
local function Art(pin, atlases, color, tint)
	local tex = pin.tex
	for _, name in ipairs(atlases) do
		if C_Texture.GetAtlasInfo(name) then
			tex:SetAtlas(name)
			if tint then tex:SetVertexColor(color[1], color[2], color[3]) end
			return
		end
	end
	tex:SetTexture("Interface\\Buttons\\WHITE8x8")
	tex:SetVertexColor(color[1], color[2], color[3])
	local mask = pin:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
end

---@param size number
---@param level integer   above the minimap's own blips
---@return ObviGuidePin
local function NewPin(size, level)
	local pin = CreateFrame("Frame", nil, Minimap) --[[@as ObviGuidePin]]
	pin:SetSize(size, size)
	pin:SetFrameLevel(Minimap:GetFrameLevel() + level)
	pin.tex = pin:CreateTexture(nil, "OVERLAY")
	pin.tex:SetAllPoints()
	pin:Hide()
	return pin
end

-- the destination shows the step's first line on hover; the dots take no mouse
local function ShowTooltip(self)
	local goal = step and step.goals[1]
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(goal and goal.text or (step and step.label) or "Obvi Guide", 1, 1, 1, 1, true)
	GameTooltip:Show()
end

---@return ObviGuidePin
local function Dest()
	if not dest then
		dest = NewPin(DEST, 30)
		Art(dest, { "Waypoint-MapPin-Minimap-Tracked", "Waypoint-MapPin-Minimap-Untracked" }, GOLD, false)
		dest:EnableMouse(true)
		dest:SetScript("OnEnter", ShowTooltip)
		dest:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	return dest
end

--- A filled circle: a plain colour with a round mask (crisp at any size, unlike blip art with empty margins).
---@param pin ObviGuidePin
---@param layer DrawLayer
---@param size number
---@param r number
---@param g number
---@param b number
---@param a number
---@return Texture
local function Circle(pin, layer, size, r, g, b, a)
	local tex = pin:CreateTexture(nil, layer)
	tex:SetTexture("Interface\\Buttons\\WHITE8x8")
	tex:SetVertexColor(r, g, b, a)
	tex:SetSize(size, size)
	tex:SetPoint("CENTER")
	local mask = pin:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(tex)
	tex:AddMaskTexture(mask)
	return tex
end

---@return ObviGuidePin
local function Dot()
	used = used + 1
	if not dots[used] then
		local pin = NewPin(DOT + RIM * 2, 25)
		-- a quest-yellow dot with a dark rim, so it shows on any ground
		Circle(pin, "BACKGROUND", DOT + RIM * 2, 0, 0, 0, 0.85)
		pin.tex:Hide()
		pin.tex = Circle(pin, "ARTWORK", DOT, DOTCOLOR[1], DOTCOLOR[2], DOTCOLOR[3], 1)
		dots[used] = pin
	end
	return dots[used]
end

---@param pin ObviGuidePin
---@param p? ObviGuidePoint
local function Place(pin, p)
	if p then
		pin.continent, pin.world = C_Map.GetWorldPosFromMapPos(p.map, CreateVector2D(p.x, p.y))
	else
		pin.continent, pin.world = nil, nil
		pin:Hide()
	end
end

--- The minimap's radius in yards: this engine tells it; else it is worked out from the zoom and the standard sizes.
---@return number
local function ViewRadius()
	local r = C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
	if r and r > 0 then return r end
	local zoom = tonumber(Minimap:GetZoom()) or 0
	-- the minimap keeps one zoom for outdoors and one for indoors; when they differ, the one in use tells which
	local out, inside = tonumber(GetCVar("minimapZoom")), tonumber(GetCVar("minimapInsideZoom"))
	local indoors
	if out ~= inside then indoors = inside == zoom else indoors = IsIndoors() end
	return ((indoors and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]) / 2
end

local function Update()
	local here = C_Map.GetBestMapForUnit("player")
	local pos = here and C_Map.GetPlayerMapPosition(here, "player")
	local continent, me
	if here and pos then continent, me = C_Map.GetWorldPosFromMapPos(here, pos) end
	local radius, half = ViewRadius(), Minimap:GetWidth() / 2
	local facing = GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or nil
	local shape = _G["GetMinimapShape"] ---@type (fun(): string)?   set by minimap addons that make it square
	local square = shape ~= nil and shape() == "SQUARE"
	---@param pin ObviGuidePin
	local function Show(pin, clamp)
		local w = pin.world
		-- in an instance (no position) or on another continent: hidden
		if not (me and w and pin.continent == continent) then pin:Hide() return end
		local x, y, inside = Pins.Offset(w.x - me.x, w.y - me.y, radius, half, facing, square)
		if not inside and clamp then x, y = Pins.Clamp(x, y, half - EDGE, square) end
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
		pin:SetShown(inside or clamp)
	end
	for i = 1, used do Show(dots[i], false) end
	if dest and dest.world then Show(dest, true) end
end

--- Builds the pins for the current step: none when it has no points or the setting is off.
function Pins.Refresh()
	step = select(2, ns.Engine.Current())
	local on = step ~= nil and not (ns.db and ns.db.minimap == false)
	used = 0
	-- the dots: the step's route points and its markers (where its mobs or things are)
	if on and step then
		for _, p in ipairs(step.path) do Place(Dot(), p) end
		for _, p in ipairs(step.markers or {}) do Place(Dot(), p) end
	end
	for i = used + 1, #dots do Place(dots[i], nil) end
	if on and step and step.dest then Place(Dest(), step.dest) elseif dest then Place(dest, nil) end
	local any = used > 0 or (dest and dest.world) ~= nil
	driver:SetShown(any)
	if any then Update() end
end

--- "/og pins": what the pins are built from, step by step, to see where they get lost (in the copy window).
function Pins.Debug()
	Pins.Refresh()
	local out = {}
	local function P(fmt, ...) table.insert(out, fmt:format(...)) end
	P("pins: step %s, dest %s, path points %d, markers %d, setting %s", step and step.index or "none",
		step and step.dest and ("%d %.3f,%.3f"):format(step.dest.map, step.dest.x, step.dest.y) or "none",
		step and #step.path or 0, step and step.markers and #step.markers or 0, tostring(ns.db and ns.db.minimap))
	if dest then
		P("dest world: continent %s, %s", tostring(dest.continent),
			dest.world and ("%.1f, %.1f"):format(dest.world.x, dest.world.y) or "nil")
	end
	local here = C_Map.GetBestMapForUnit("player")
	local pos = here and C_Map.GetPlayerMapPosition(here, "player")
	local continent, me
	if here and pos then continent, me = C_Map.GetWorldPosFromMapPos(here, pos) end
	P("player: map %s, pos %s, continent %s, world %s", tostring(here), pos and ("%.3f,%.3f"):format(pos.x, pos.y) or "nil",
		tostring(continent), me and ("%.1f, %.1f"):format(me.x, me.y) or "nil")
	local r = C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
	P("minimap: view radius %s (used %.1f), width %.1f, zoom %s, driver %s", tostring(r), ViewRadius(),
		Minimap:GetWidth(), tostring(Minimap:GetZoom()), tostring(driver:IsShown()))
	if dest then
		local _, _, rel, x, y = dest:GetPoint()
		P("dest pin: shown %s, visible %s, at %s, %s, alpha %.2f, level %d (minimap %d)", tostring(dest:IsShown()),
			tostring(dest:IsVisible()), rel and ("%.1f"):format(x) or "-", rel and ("%.1f"):format(y) or "-",
			dest:GetEffectiveAlpha(), dest:GetFrameLevel(), Minimap:GetFrameLevel())
	end
	ns.Copy("Obvi Guide: minimap pins", table.concat(out, "\n"))
end

local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + dt
	if elapsed < INTERVAL then return end
	elapsed = 0
	Update()
end)

ns:On("OBVIGUIDE_STEP", function() Pins.Refresh() end)
ns:On("OBVIGUIDE_UPDATE", function() Pins.Refresh() end)
