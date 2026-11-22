-- Travel: shows the way to the current step's destination, as the "Waypoints" setting says: Auto (the default: Shortest
-- Path Forever when it is installed, else the arrow), Obvi Guide's own arrow, Shortest Path Forever (it plans the way
-- there: walking paths, flights, boats, portals), TomTom, the game's own map pin with its compass arrow, or nothing. A
-- choice that isn't installed falls back to the arrow. Our waypoint
-- lives with one of them at a time: showing it with one takes it away from the others.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuideTravel
local Travel = {}
ns.Travel = Travel

---@alias ObviGuideWaypoints "arrow"|"spf"|"tomtom"|"pin"|"none"
---@alias ObviGuideWaypointsSetting ObviGuideWaypoints|"auto"

local OWNER = "ObviGuide"   -- Shortest Path keeps one journey per owner
local ourPin               -- the user waypoint we set, so we never clear someone else's
local ourTomTom            -- the TomTom waypoint we set (its uid)
local placed               ---@type ObviGuidePoint?   the point we last showed the way to

-- Whether the journey Shortest Path guides is ours. Its own route bookkeeping can't say: it ends our route whenever the
-- journey's point is swapped (a replan to the same place, an arrival held) while it keeps guiding there, and our journey
-- would then look like one the player planned. So we listen: a journey that starts or moves somewhere while our route is
-- gone is the player's; one that ends is no one's.
local ourJourney = false
local listening = false
local afterCombat = false   -- a journey to plan once combat is over


-- What Shortest Path Forever is told about a step's stop besides its place, so it can do its part:
--   questIDs  the quests whose objectives are done there: arriving anywhere in their area counts, and the lines under
--             its arrow are the quests' own live progress ("Wolf slain: 3/8")
--   handins   the quests turned in there: the game's own "?" pins there are hidden, not shown twice
--   npc       the NPC there: its nameplate is marked, and the walk ends on that NPC's floor (in a city or a cave)
--   kind      the stop pin's icon (Shortest Path's names)
---@class ObviGuideStopInfo
---@field questIDs? integer[]
---@field handins? integer[]
---@field npc? integer
---@field kind? string

local LOOK = {
	turnin = "turnin", accept = "pickup", objective = "objective", kill = "objective", collect = "objective",
	fly = "flightmaster", home = "innkeeper", learn = "trainer",
}

local shownTitle  ---@type string?   the way's title as last shown
local shownSig    ---@type string?   that title and the stop's info, to tell when either changed

-- Shortest Path Forever's public API (an optional dependency, so looked up at run time)
local function SPF()
	local spf = _G["ShortestPathForever"] ---@type {API: table}?
	local api = spf and spf.API
	if api and not listening and type(api.Subscribe) == "function" then
		listening = true
		api.Subscribe(function(changes)
			if changes.ended then ourJourney = false end
			if (changes.started or changes.changed) and api.CurrentStop(OWNER) == nil then ourJourney = false end
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

--- The Waypoints setting as chosen ("auto" while it is left at the default).
---@return ObviGuideWaypointsSetting
function Travel.Setting()
	return ns.db and ns.db.waypoints or "auto"
end

--- The way waypoints are shown: the setting (Auto: Shortest Path Forever when installed), or the arrow when what it
--- names isn't installed. Looked up each time, so it doesn't matter which addon loaded first.
---@return ObviGuideWaypoints
function Travel.Provider()
	local setting = Travel.Setting()
	local kind = (setting == "auto" and "spf" or setting) --[[@as ObviGuideWaypoints]]
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
---@param info? ObviGuideStopInfo   what Shortest Path is told about the stop besides its place
local function Place(p, title, step, info)
	local kind = Travel.Provider()
	placed = p
	ClearOthers(kind)
	if kind == "arrow" then
		ns.Arrow.Set(p, title)
	elseif kind == "spf" then
		local api = SPF() --[[@as table]]
		if not p then api.Cancel(OWNER) ourJourney = false return end
		if step and api.Active() and not ourJourney then return end   -- the player's own journey: left alone
		-- Shortest Path plans no journey in combat (a step often moves on there, as the mob dies): again after it
		if InCombatLockdown() then afterCombat = true return end
		local stop = { map = p.map, x = p.x, y = p.y, title = Plain(title), hold = true, radius = p.radius }
		if info then
			stop.questIDs, stop.handins, stop.npc, stop.kind = info.questIDs, info.handins, info.npc, info.kind
		end
		-- the line under its arrow: the quests' own live progress when the stop has quests to do, else the step's line
		if not stop.questIDs then stop.tooltip = title end
		-- Sending the same place again (the step's line or quests changed) only relabels the stop: no new route search
		ourJourney = api.NavigateRoute(OWNER, { stop }) ~= false
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
	shownTitle, shownSig = title, nil
end

local CLOSE = 20   -- yards: as good as there

--- Whether clicking a line for point p would change nothing: the way is shown there already (in Shortest Path, our
--- journey is still on), or the player is there. So clicking again and again doesn't ask Shortest Path to plan anew
--- each time.
---@param p ObviGuidePoint
---@return boolean
function Travel.Already(p)
	local same = placed and placed.map == p.map and math.abs(placed.x - p.x) < 1e-4 and math.abs(placed.y - p.y) < 1e-4
	if same and (Travel.Provider() ~= "spf" or ourJourney) then return true end
	local c1, w1 = Travel.PlayerWorld()
	local c2, w2 = Travel.World(p)
	if not (w1 and w2) or c1 ~= c2 then return false end
	local dx, dy = w1.x - w2.x, w1.y - w2.y
	return math.sqrt(dx * dx + dy * dy) <= math.max(CLOSE, p.radius or 0)
end

--- The way's title: the step's first shown line that's still to do (else its first shown line), not a "Talk to" line
--- or a note. Lines come and go as you play ("Use Draught of Water Breathing" only until you have its buff).
---@param step ObviGuideStep
---@return string?
local function Title(step)
	local first
	for _, g in ipairs(step.goals) do
		if g.kind ~= "talk" and not g.note and ns.Engine.IsVisible(g) then
			if not ns.Engine.IsComplete(g, step) then return g.text end
			first = first or g.text
		end
	end
	return first
end

--- What Shortest Path is told about a step's stop, from the step's shown lines still to do.
---@param step ObviGuideStep
---@return ObviGuideStopInfo
local function Info(step)
	local quests, handins, kind = {}, {}, nil
	for _, g in ipairs(step.goals) do
		if ns.Engine.IsVisible(g) and not ns.Engine.IsComplete(g, step) then
			kind = kind or LOOK[g.kind]
			local q = g.quest
			if q and g.kind == "turnin" then
				if not tContains(handins, q) then handins[#handins + 1] = q end
			elseif q and (g.kind == "objective" or g.kind == "kill" or (g.kind == "collect" and g.objective)) then
				if not tContains(quests, q) then quests[#quests + 1] = q end
			end
		end
	end
	local target = step.target
	return {
		questIDs = quests[1] and quests or nil,   -- (an empty list is refused)
		handins = handins[1] and handins or nil,
		npc = target and not target.enemy and target.id or nil,
		kind = kind,
	}
end

---@param title? string
---@param info ObviGuideStopInfo
---@return string
local function Signature(title, info)
	return table.concat({ title or "", table.concat(info.questIDs or {}, ","), table.concat(info.handins or {}, ","),
		tostring(info.npc), tostring(info.kind) }, "|")
end

local shownStep ---@type ObviGuideStep?
local shownOpen = false   -- the shown step was seen not done (see Ahead)

--- Shows the way to a step's destination, or clears ours when the step has none.
---@param step? ObviGuideStep
function Travel.Show(step)
	local dest = step and step.dest
	local title = step and dest and Title(step) or nil
	local info = step and dest and Info(step) or nil
	if step ~= shownStep then shownOpen = false end
	shownStep = step
	Place(dest, title, true, info)
	shownTitle, shownSig = title, info and Signature(title, info) or nil
end

-- A step that turns done stays a moment for its "done" effect before the guide moves on. Meanwhile the way to the step
-- it moves on to is already asked for, so the route is there when it does (the guide showing that step then sends
-- the same place again: only a relabel). Only for a step seen open (one gone back to, done already, stays put), and
-- only where the next step is plain to see: no jumps, not a guide in any order.

---@param step ObviGuideStep
---@return ObviGuideStep?
local function Ahead(step)
	local guide, current = ns.Engine.Current()
	if not guide or current ~= step or guide.nearest or step.jumps then return nil end
	for i = step.index + 1, #guide.steps do
		local s = guide.steps[i]
		local applies, done = ns.Engine.StepState(s)
		if applies and not done then return s end
		if s.jumps then return nil end
	end
end

ns:On("OBVIGUIDE_UPDATE", function()
	local step = shownStep
	if not step then return end
	local _, done = ns.Engine.StepState(step)
	if not done then shownOpen = true return end
	if not shownOpen then return end
	shownOpen = false
	local nxt = Ahead(step)
	if nxt and nxt.dest then Travel.Show(nxt) end
end)

-- the step's lines changed (a buff, an item, an objective done): the title and the stop's quests follow, without
-- asking for the way anew (Shortest Path relabels a stop sent again at the same place)
ns:On("OBVIGUIDE_UPDATE", function()
	local step = shownStep
	if not (step and step.dest and placed == step.dest) then return end
	local title, info = Title(step), Info(step)
	local sig = Signature(title, info)
	if sig == shownSig then return end
	local titleChanged = title ~= shownTitle
	shownTitle, shownSig = title, sig
	local kind = Travel.Provider()
	if kind == "arrow" then
		if titleChanged then ns.Arrow.Set(step.dest, title) end
	elseif kind == "spf" and ourJourney then
		-- (it takes no journey in combat: sent again once combat is over)
		if InCombatLockdown() then afterCombat = true return end
		Place(step.dest, title, true, info)
	end
end)

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

-- Shortest Path Forever loading after us (or on demand): Auto moves the step's waypoint over to it
ns:On("ADDON_LOADED", function(_, name)
	if name == "ShortestPathForever" and Travel.Setting() == "auto" and ns.Engine and ns.Engine.Current() then
		Travel.Refresh()
	end
end)

--- The waypoint as last shown, for /og step: its title, what Shortest Path was told about the stop, and whose journey
--- it guides.
---@return string
function Travel.DebugObjective()
	local api = SPF()
	return ("waypoint: title %q, stop %s, ours %s, provider %s, spf active %s, our stop %s")
		:format(tostring(shownTitle), tostring(shownSig), tostring(ourJourney), Travel.Provider(),
			tostring(api and api.Active()), tostring(api and api.CurrentStop(OWNER)))
end
