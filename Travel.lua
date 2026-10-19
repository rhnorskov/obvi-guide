-- Travel: the current step's destination goes to Shortest Path Forever when it is installed (it plans the way there:
-- walking paths, flights, boats, portals). Without it, the game's own map pin and its compass arrow are used.
local _, ns = ...
---@cast ns AnyGuideNS

---@class AnyGuideTravel
local Travel = {}
ns.Travel = Travel

local OWNER = "AnyGuide"   -- Shortest Path keeps one journey per owner
local ourPin               -- the user waypoint we set (fallback only), so we never clear someone else's

-- Shortest Path Forever's public API (an optional dependency, so looked up at run time)
local function SPF()
	local spf = _G["ShortestPathForever"] ---@type {API: table}?
	return spf and spf.API
end

-- UiMapPoint is a FrameXML global the annotations do not declare
local UiMapPoint = _G["UiMapPoint"] ---@type {CreateFromCoordinates: fun(map: integer, x: number, y: number): table}

local function ClearPin()
	if ourPin and C_Map.HasUserWaypoint() then
		local wp = C_Map.GetUserWaypoint()
		if wp and wp.uiMapID == ourPin.uiMapID and math.abs(wp.position.x - ourPin.position.x) < 1e-4 then
			C_Map.ClearUserWaypoint()
		end
	end
	ourPin = nil
end

--- Shows the way to a step's destination, or clears ours when the step has none.
---@param step? AnyGuideStep
function Travel.Show(step)
	local dest = step and step.dest
	local api = SPF()
	if api then
		if not (step and dest) then api.Cancel(OWNER) return end
		-- a journey the player planned themselves is left alone
		if api.Active() and api.CurrentStop(OWNER) == nil then return end
		local title
		for _, g in ipairs(step.goals) do if g.kind ~= "talk" then title = g.text break end end
		title = title and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
		api.NavigateRoute(OWNER, { { map = dest.map, x = dest.x, y = dest.y, title = title, hold = true, radius = dest.radius } })
		return
	end
	ClearPin()
	if not dest or not C_Map.CanSetUserWaypointOnMap(dest.map) then return end
	ourPin = UiMapPoint.CreateFromCoordinates(dest.map, dest.x, dest.y)
	C_Map.SetUserWaypoint(ourPin)
	C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end
