-- World map pins: while a step is current, its destination is a gold pin on the world map and its other points (the
-- way there, the spots it marks: "multiple locations") are dots in the minimap's colours. They show on the zone's map
-- and on any map that holds the point (the continent), and keep their size as the map zooms.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuideWorldMapPins
local Map = {}
ns.WorldMapPins = Map

local DOT, DEST = 10, 26     -- pin sizes in screen pixels
local RIM = 2
local GOLD = { 1, 0.82, 0 }

---@class ObviGuideMapPin : Frame
---@field holder Frame       a point-sized frame on the map canvas, where the pin is centred
---@field tex Texture
---@field point ObviGuidePoint
---@field rim? Texture
---@field dot? Texture
---@field gold? Texture

-- (FrameXML; the annotations differ by client)
local WorldMapFrame = _G["WorldMapFrame"] ---@type table?

-- OpenMap (a seamless world map): while its stitched map is up, pins go where it says on its canvas (over all of the
-- stitched map, not only the map underneath) and above its art (its docs/api.md)
---@class OpenMapAPI
---@field IsStitched fun(): boolean
---@field CanvasFromWorldPos fun(continent: integer, x: number, y: number): number?, number?
---@field ArtTopLevel fun(): integer?
---@field RegisterCallback fun(owner: any, event: string, method: function)
local function OpenMap()
	local api = _G["OpenMapAPI"] ---@type OpenMapAPI?
	if api and api.IsStitched and api.IsStitched() then return api end
	return nil
end

--- The frame level pins sit on: above the map's art (OpenMap's stitched art reaches higher than Blizzard's).
---@param canvas Frame
---@param above integer
---@return integer
local function Level(canvas, above)
	local api = OpenMap()
	local top = api and api.ArtTopLevel and api.ArtTopLevel()
	return math.max(canvas:GetFrameLevel(), top or 0) + above
end

local pins = {} ---@type ObviGuideMapPin[]
local used = 0
local step ---@type ObviGuideStep?
local shownMap, shownScale ---@type integer?, number?
local dirty = true

---@return Frame?
local function Canvas()
	return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

--- A filled circle with a round mask.
---@param pin Frame
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

local function ShowTooltip(self) ns.MinimapPins.Tooltip(self, step) end

--- A pin from the pool, made into a dot (r, g, b) or, without a colour, the destination's gold pin.
---@param canvas Frame
---@param r? number
---@param g? number
---@param b? number
---@return ObviGuideMapPin
local function Pin(canvas, r, g, b)
	used = used + 1
	local pin = pins[used]
	if not pin then
		local holder = CreateFrame("Frame", nil, canvas)
		holder:SetSize(1, 1)
		pin = CreateFrame("Frame", nil, holder) --[[@as ObviGuideMapPin]]
		pin.holder = holder
		pin:SetPoint("CENTER", holder, "CENTER")
		pin:EnableMouse(true)
		pin:SetScript("OnEnter", ShowTooltip)
		pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
		pins[used] = pin
	end
	-- the art for what it is now (a pin may be a dot one time and the destination the next)
	for _, tex in ipairs({ pin.rim, pin.dot, pin.gold }) do tex:Hide() end
	if r then
		pin:SetSize(DOT + RIM * 2, DOT + RIM * 2)
		pin.rim = pin.rim or Circle(pin, "BACKGROUND", DOT + RIM * 2, 0, 0, 0, 0.85)
		pin.dot = pin.dot or Circle(pin, "ARTWORK", DOT, 1, 1, 1, 1)
		pin.rim:Show()
		pin.dot:Show()
		pin.dot:SetVertexColor(r, g or 1, b or 1, 1)
		pin.holder:SetFrameLevel(Level(canvas, 100))
	else
		pin:SetSize(DEST, DEST)
		if not pin.gold then
			pin.gold = pin:CreateTexture(nil, "OVERLAY")
			pin.gold:SetAllPoints()
			local atlas
			for _, name in ipairs({ "Waypoint-MapPin-Tracked", "Waypoint-MapPin-Untracked" }) do
				if C_Texture.GetAtlasInfo(name) then atlas = name break end
			end
			if atlas then pin.gold:SetAtlas(atlas) else
				pin.gold:SetTexture("Interface\\Buttons\\WHITE8x8")
				pin.gold:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
			end
		end
		pin.gold:Show()
		pin.holder:SetFrameLevel(Level(canvas, 110))
	end
	pin.holder:Show()
	return pin
end

-- which continent each map lies on (world coordinates are per continent)
local continentOf = {} ---@type table<integer, integer|false>
---@param map integer
---@return integer?
local function Continent(map)
	if continentOf[map] == nil then
		local continent = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0.5, 0.5))
		continentOf[map] = continent or false
	end
	return continentOf[map] or nil
end

--- Where a point lies on a map (0-1), or nil when that map doesn't hold it.
---@param p ObviGuidePoint
---@param map integer
---@return number?, number?
local function OnMap(p, map)
	local api = OpenMap()
	if api then
		-- on OpenMap's stitched map: anywhere on it (past the map underneath too)
		local continent, world = C_Map.GetWorldPosFromMapPos(p.map, CreateVector2D(p.x, p.y))
		if not (continent and world) then return nil end
		return api.CanvasFromWorldPos(continent, world.x, world.y)
	end
	if p.map == map then return p.x, p.y end
	local continent, world = C_Map.GetWorldPosFromMapPos(p.map, CreateVector2D(p.x, p.y))
	if not (continent and world) or Continent(map) ~= continent then return nil end
	local _, pos = C_Map.GetMapPosFromWorldPos(continent, world, map)
	if pos and pos.x >= 0 and pos.x <= 1 and pos.y >= 0 and pos.y <= 1 then return pos.x, pos.y end
	return nil
end

--- Puts the pins where their points are on the map shown, at the size they keep however far it's zoomed.
local function Layout()
	local canvas, map = Canvas(), WorldMapFrame and WorldMapFrame:GetMapID()
	if not (canvas and map) then return end
	local scale = (WorldMapFrame and WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
	shownMap, shownScale = map, scale
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	for i = 1, used do
		local pin = pins[i]
		local x, y = OnMap(pin.point, map)
		if x and y then
			pin.holder:ClearAllPoints()
			pin.holder:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
			pin:SetScale(1 / scale)
			pin.holder:Show()
		else
			pin.holder:Hide()
		end
	end
end

--- Builds the pins for the current step: none when it has no points or the setting is off.
local function Build()
	dirty = false
	local canvas = Canvas()
	if not canvas then return end
	used = 0
	step = select(2, ns.Engine.Current())
	if step and not (ns.db and ns.db.worldMap == false) then
		local r, g, b = ns.MinimapPins.StepColor(step)
		for _, p in ipairs(step.path) do Pin(canvas, r, g, b).point = p end
		for _, p in ipairs(step.markers or {}) do Pin(canvas, r, g, b).point = p end
		if step.dest then Pin(canvas).point = step.dest end
	end
	for i = used + 1, #pins do pins[i].holder:Hide() end
	Layout()
end

--- The step changed (or the setting): build the pins anew when the map shows next (or now, when it's open).
function Map.Refresh()
	dirty = true
	if WorldMapFrame and WorldMapFrame:IsShown() then Build() end
end

if WorldMapFrame then
	-- while the map is open: a new step, another map or a zoom moves the pins
	local driver = CreateFrame("Frame", nil, WorldMapFrame)
	driver:SetScript("OnUpdate", function()
		if dirty then Build() return end
		local map = WorldMapFrame:GetMapID()
		local scale = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:GetCanvasScale()
		if map ~= shownMap or scale ~= shownScale then Layout() end
	end)
end

-- OpenMap: its view moving (or turning stitched on or off) moves the pins
local function HookOpenMap()
	local api = _G["OpenMapAPI"] ---@type OpenMapAPI?
	if not (api and api.RegisterCallback) then return end
	api.RegisterCallback(Map, "OpenMap_ViewChanged", function() if WorldMapFrame and WorldMapFrame:IsShown() then Layout() end end)
	api.RegisterCallback(Map, "OpenMap_StitchedChanged", function() Map.Refresh() end)
end
ns:On("PLAYER_LOGIN", HookOpenMap)

ns:On("OBVIGUIDE_STEP", function() Map.Refresh() end)
ns:On("OBVIGUIDE_UPDATE", function() Map.Refresh() end)
