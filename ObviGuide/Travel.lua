-- Travel: shows the way to the current step's destination, as the "Waypoints" setting says: Obvi Guide's own arrow (the
-- default), Shortest Path Forever (it plans the way there: walking paths, flights, boats, portals), TomTom, the game's
-- own map pin with its compass arrow, or nothing. A choice that isn't installed falls back to the arrow. Our waypoint
-- lives with one of them at a time: showing it with one takes it away from the others.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuideTravel
local Travel = {}
ns.Travel = Travel

---@alias ObviGuideWaypoints "arrow"|"spf"|"tomtom"|"pin"|"none"

local OWNER = "ObviGuide"   -- Shortest Path keeps one journey per owner
local ourPin               -- the user waypoint we set, so we never clear someone else's
local ourTomTom            -- the TomTom waypoint we set (its uid)

-- Whether the journey Shortest Path guides is ours. Its own route bookkeeping can't say: it ends our route whenever the
-- journey's point is swapped (a replan to the same place, an arrival held) while it keeps guiding there, and our journey
-- would then look like one the player planned. So we listen: a journey that starts or moves somewhere while our route is
-- gone is the player's; one that ends is no one's.
local ourJourney = false
local listening = false
local afterCombat = false   -- a journey to plan once combat is over


-- The step's objective under Shortest Path Forever's arrow, while it guides our journey: the arrow shows the distance,
-- and the stop's title only on routes of several stops ("Stop 1 of 3: ..."), so not on ours. Its frame has no name;
-- it is found by its parts (Icon, Arrow, Distance, Progress) once Shortest Path has made it. The line is our own
-- frame under the arrow's text.
local objective      ---@type Frame|{text: FontString}?
local objectiveText  ---@type string?
local spfArrow       ---@type Frame|{Distance: FontString, Progress: FontString}?
local lookFor = 0    -- looks for the arrow made in a row

local function FindArrow()
	if spfArrow then return spfArrow end
	local f = EnumerateFrames()
	while f do
		local t = f --[[@as table]]
		if t.Distance and t.Progress and t.Arrow and t.Icon and t.MoverHint and f:GetParent() == UIParent then
			spfArrow = f --[[@as Frame|{Distance: FontString, Progress: FontString}]]
			return spfArrow
		end
		f = EnumerateFrames(f)
	end
end

local function ShowObjective()
	local show = objectiveText ~= nil and ourJourney and Travel.Provider() == "spf"
	local arrow = show and FindArrow() or spfArrow
	if not arrow then
		-- Shortest Path makes its arrow when it first guides, maybe just after us: a few more looks
		if show and lookFor < 5 then lookFor = lookFor + 1 C_Timer.After(1, ShowObjective) end
		return
	end
	lookFor = 0
	if not objective then
		if not show then return end
		-- a child of the arrow: it moves, scales, fades and hides with it
		local f = CreateFrame("Frame", nil, arrow) --[[@as Frame|{text: FontString}]]
		f:SetSize(220, 20)
		f:SetPoint("TOP", arrow.Progress, "BOTTOM", 0, -2)   -- under the arrow's title line (empty on our routes)
		f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f.text:SetPoint("TOP")
		f.text:SetWidth(220)
		f.text:SetWordWrap(true)
		objective = f
	end
	objective.text:SetText(show and objectiveText or "")
	objective:SetShown(show)
end

-- Shortest Path Forever's public API (an optional dependency, so looked up at run time)
local function SPF()
	local spf = _G["ShortestPathForever"] ---@type {API: table}?
	local api = spf and spf.API
	if api and not listening and type(api.Subscribe) == "function" then
		listening = true
		api.Subscribe(function(changes)
			if changes.ended then ourJourney = false end
			if (changes.started or changes.changed) and api.CurrentStop(OWNER) == nil then ourJourney = false end
			ShowObjective()
		end)
	end
	return api
end

---@class ObviGuideTomTom
---@field AddWaypoint fun(self: ObviGuideTomTom, map: integer, x: number, y: number, opts: table): any
---@field RemoveWaypoint fun(self: ObviGuideTomTom, uid: any)

-- TomTom, when it is really installed: Shortest Path puts a TomTom-shaped stand-in in its place when it isn't
local function TomTom()
	local tt = _G["TomTom"] ---@type ObviGuideTomTom?
	if tt and C_AddOns.IsAddOnLoaded("TomTom") and type(tt.AddWaypoint) == "function" then return tt end
end

-- UiMapPoint is a FrameXML global the annotations do not declare
local UiMapPoint = _G["UiMapPoint"] ---@type {CreateFromCoordinates: fun(map: integer, x: number, y: number): table}

--- Where a point is in world coordinates (yards; x grows to the north, y to the west), and on which continent.
---@param p ObviGuidePoint
---@return number? continent, vector2? world
function Travel.World(p)
	return C_Map.GetWorldPosFromMapPos(p.map, CreateVector2D(p.x, p.y))
end

--- Where the player is, the same way; nothing in an instance (there is no map position there).
---@return number? continent, vector2? world
function Travel.PlayerWorld()
	local here = C_Map.GetBestMapForUnit("player")
	local pos = here and C_Map.GetPlayerMapPosition(here, "player")
	if not (here and pos) then return nil, nil end
	return C_Map.GetWorldPosFromMapPos(here, pos)
end

--- Whether a way of showing waypoints can be used here (the addon it needs is installed).
---@param kind ObviGuideWaypoints
---@return boolean
function Travel.Available(kind)
	if kind == "spf" then return SPF() ~= nil end
	if kind == "tomtom" then return TomTom() ~= nil end
	return kind == "arrow" or kind == "pin" or kind == "none"
end

--- The way waypoints are shown: the setting, or the arrow when what it names isn't installed.
---@return ObviGuideWaypoints
function Travel.Provider()
	local kind = ns.db and ns.db.waypoints or "arrow"
	return Travel.Available(kind) and kind or "arrow"
end

-- the title without colour codes and icons, for the others (they show it as plain text)
---@param title? string
---@return string?
local function Plain(title)
	return title and (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

local function ClearPin()
	if ourPin and C_Map.HasUserWaypoint() then
		local wp = C_Map.GetUserWaypoint()
		if wp and wp.uiMapID == ourPin.uiMapID and math.abs(wp.position.x - ourPin.position.x) < 1e-4 then
			C_Map.ClearUserWaypoint()
		end
	end
	ourPin = nil
end

local function ClearTomTom()
	local tt = TomTom()
	-- TomTom drops a waypoint on arrival by itself, so ours may be gone already
	if tt and ourTomTom then pcall(tt.RemoveWaypoint, tt, ourTomTom) end
	ourTomTom = nil
end

--- Takes our waypoint away from every way of showing it but `keep`.
---@param keep ObviGuideWaypoints
local function ClearOthers(keep)
	local api = SPF()
	if keep ~= "spf" and api then api.Cancel(OWNER) end   -- (only ever our own journey)
	if keep ~= "tomtom" then ClearTomTom() end
	if keep ~= "pin" then ClearPin() end
	if keep ~= "arrow" and ns.Arrow then ns.Arrow.Set(nil) end
end

--- Shows the way to a point (or clears ours) with the chosen provider.
---@param p? ObviGuidePoint
---@param title? string    colour codes kept: the arrow shows them
---@param step? boolean    a step's destination (a journey the player planned in Shortest Path is then left alone)
local function Place(p, title, step)
	local kind = Travel.Provider()
	ClearOthers(kind)
	if kind == "arrow" then
		ns.Arrow.Set(p, title)
	elseif kind == "spf" then
		local api = SPF() --[[@as table]]
		if not p then api.Cancel(OWNER) ourJourney = false return end
		if step and api.Active() and not ourJourney then return end   -- the player's own journey: left alone
		-- Shortest Path plans no journey in combat (a step often moves on there, as the mob dies): again after it
		if InCombatLockdown() then afterCombat = true return end
		ourJourney = api.NavigateRoute(OWNER, { { map = p.map, x = p.x, y = p.y, title = Plain(title), hold = true, radius = p.radius } }) ~= false
	elseif kind == "tomtom" then
		ClearTomTom()
		if not p then return end
		local tt = TomTom() --[[@as ObviGuideTomTom]]
		local ok, uid = pcall(tt.AddWaypoint, tt, p.map, p.x, p.y,
			{ title = Plain(title), persistent = false, minimap = true, world = true, from = "Obvi Guide" })
		if ok then ourTomTom = uid else ns.Debug("TomTom waypoint failed: %s", tostring(uid)) end
	elseif kind == "pin" then
		ClearPin()
		if not p or not C_Map.CanSetUserWaypointOnMap(p.map) then return end
		ourPin = UiMapPoint.CreateFromCoordinates(p.map, p.x, p.y)
		C_Map.SetUserWaypoint(ourPin)
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	end
	-- "none": nothing to show
end

--- Shows the way to one point the player picked (a line's own spot, clicked in the window), as for a step's
--- destination.
---@param p ObviGuidePoint
---@param title? string
function Travel.To(p, title)
	Place(p, title, false)
	objectiveText = title
	ShowObjective()
end

--- Shows the way to a step's destination, or clears ours when the step has none.
---@param step? ObviGuideStep
function Travel.Show(step)
	local dest = step and step.dest
	local title
	if step and dest then
		for _, g in ipairs(step.goals) do if g.kind ~= "talk" then title = g.text break end end
	end
	Place(dest, title, true)
	objectiveText = dest and title or nil
	ShowObjective()
end

--- Shows the current step's waypoint again (after the setting changed, or after combat).
function Travel.Refresh()
	Travel.Show(select(2, ns.Engine.Current()))
end

ns:On("PLAYER_REGEN_ENABLED", function()
	if not afterCombat then return end
	afterCombat = false
	Travel.Refresh()
	-- right after a reload in combat, Shortest Path may not take a journey yet as combat ends: once more a moment later,
	-- if there is still no journey at all
	C_Timer.After(2, function()
		local api = SPF()
		if api and not ourJourney and not api.Active() and not InCombatLockdown() and Travel.Provider() == "spf" then
			Travel.Refresh()
		end
	end)
end)

--- The objective line under the waypoint marker, for /og step: what it would show and why it shows or not.
---@return string
function Travel.DebugObjective()
	local api = SPF()
	local arrow = FindArrow()
	return ("objective line: text %q, ours %s, provider %s, spf active %s, our stop %s, spf arrow %s, line %s")
		:format(tostring(objectiveText), tostring(ourJourney), Travel.Provider(), tostring(api and api.Active()),
			tostring(api and api.CurrentStop(OWNER)), arrow and (arrow:IsVisible() and "shown" or "hidden") or "not found",
			objective and (objective:IsVisible() and "shown" or "hidden") or "not made")
end
