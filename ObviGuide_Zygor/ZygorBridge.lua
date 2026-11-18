-- Hands the guides of my own installed Zygor addon to Obvi Guide, in game: each guide Zygor has registered (with its
-- text, so not the premium placeholders of the trial) goes to ObviGuide.Add with its title and header as plain values.
-- Nothing is copied to disk. Personal use only (guides I own); not for sharing. Then Zygor itself is stopped (see
-- "Zygor off" below), unless "/og zygor" says to keep it running.
--
-- When: Zygor registers its guides as its files load (before this pack), then reads their headers (who each guide is
-- for) in its startup a few seconds after login, and sets ZGV.guidesloaded once that is done; no guides come after it
-- ("Too late to RegisterGuide"). So the guides are handed over then, or after a minute if Zygor never gets there.
-- Obvi Guide reads a guide's text only when it is first opened; the text (with Zygor's #include pieces filled in and
-- the fixes below) is made at that moment.
-- Zygor's addon is ZygorGuidesViewer on retail and ZygorGuidesViewerForever on Forever (both optional dependencies,
-- so it loads first); both set the same global. Without either, nothing to do.
local ZGV = _G["ZygorGuidesViewer"] ---@type table
if not ZGV then return end

local BUILD = select(4, GetBuildInfo()) or 0
local FOREVER = BUILD >= 16000 and BUILD < 20000

-- Fixes to Zygor's guide text, applied when a guide is read: the exact text in the guide and what it becomes. A fix
-- whose guide or text isn't there (another client, or Zygor changed the line) does nothing.
---@type {guide: string, find: string, replace: string}[]
local fixes = {
	-- Forever: the Beached Sea Creature for quest 4723 is at 32.9,81.1 (found in game 2026-10-20)
	{ guide = "Leveling Guides\\Darkshore (15-18)",
		find = "accept Beached Sea Creature##4723 |goto Darkshore 41.88,31.55",
		replace = "accept Beached Sea Creature##4723 |goto Darkshore 32.90,81.10" },
}

--- One "#include" line -> the shared piece of guide text it names, with its %params% filled in, as Zygor's own reader
--- does it ('#include "Name",param="value"').
---@param line string
---@return string
local function Include(line)
	line = line:gsub("%s*//.-$", ""):gsub("%s*%-%-.-$", "")
	local title, rest = line:match("^%s*([^,]*)(.*)$")
	title = title:gsub("%s+$", ""):gsub('^"(.-)"$', "%1")
	local params = {}
	for k, v in rest:gmatch('([%w_]+)%s*=%s*"(.-)"') do params[k] = v end
	local include = ZGV.registered_includes and ZGV.registered_includes[title]
	return include and ((include:GetParsed(params)) .. "\n") or ""
end

--- The guide's text as Obvi Guide reads it.
---@param guide table   Zygor's guide
---@return string
local function Text(guide)
	local text = guide.rawdata ---@type string
	-- includes may include others; Zygor stops at 20 rounds
	for _ = 1, 20 do
		if not text:find("#include", 1, true) then break end
		text = text:gsub("#include%s*(.-)%s-[\r\n|$]", Include)
	end
	for _, fix in ipairs(fixes) do
		local at = fix.guide == guide.title and text:find(fix.find, 1, true)
		if at then text = text:sub(1, at - 1) .. fix.replace .. text:sub(at + #fix.find) end
	end
	return text
end

--- Zygor's own "is this guide for this character" (condition_visible, set up once Zygor has read the header). Asked
--- once, at hand-over; a guide whose check fails is listed.
---@param guide table
---@return boolean
local function Visible(guide)
	local check = guide.condition_visible
	if type(check) ~= "function" then return true end
	local ok, yes = pcall(check)
	return not ok or not not yes
end

local function HandOver()
	-- retail: Zygor's map table (zone names it makes up, and its floors: "Orgrimmar/1"); Forever uses Obvi Guide's own
	local maps = not FOREVER and ZGV.MapIDsByName or nil
	local added, hidden = 0, 0
	for _, guide in ipairs(ZGV.registeredguides or {}) do
		if type(guide.rawdata) == "string" and not guide.missing then
			if Visible(guide) then
				local nextTitle = guide.headerdata and guide.headerdata.next
				added = added + ObviGuide.Add("zygor", function() return Text(guide) end, {
					title = guide.title,
					header = { next = type(nextTitle) == "string" and ZGV:SanitizeGuideTitle(nextTitle) or nil },
					maps = maps,
				})
			else
				hidden = hidden + 1
			end
		end
	end
	print(("|cff4fc3f7Obvi Guide|r: %d Zygor guides handed over (%d not for this character)%s"):format(added, hidden,
		ZGV.guidesloaded and "" or "; Zygor hadn't finished loading"))
end

-- Zygor off: once its guides are loaded, Zygor itself is stopped, so it can't clash with Obvi Guide (its window,
-- arrow, map pins, auto accept, bag upgrade marks, timers). On by default; "/og zygor" keeps Zygor running instead
-- (from the next /reload), or stops it again. Kept in ObviGuideZygorDB.

--- The saved settings. (The game sets ObviGuideZygorDB after this file has run, so it's looked up each time.)
---@return {keepZygor: boolean?}
local function Settings()
	ObviGuideZygorDB = ObviGuideZygorDB or {}
	return ObviGuideZygorDB
end

--- Calls f, quietly: a part of Zygor that isn't there (another version) is skipped.
---@param f fun()
local function Try(f) pcall(f) end

local stopped = false
--- Stops Zygor: its startup (the modules that come after the guides, loading the last guide), then the addon itself
--- (Ace's Disable hides its window and map button and drops all its events, timers and hooks), its arrow and
--- waypoints, and the event frames it keeps outside Ace. Its guides stay registered for Obvi Guide to read.
local function StopZygor()
	if stopped then return end
	stopped = true
	local master = _G["ZygorGuidesViewerFrameMaster"] ---@type Frame?
	if master then master:SetScript("OnUpdate", nil) end
	local Pointer = ZGV.Pointer
	if Pointer then
		Try(function() Pointer:ClearWaypoints() end)
		Try(function() Pointer:HideArrow() end)
		Try(function() Pointer.ArrowFrame:Hide() end)
		Try(function() Pointer.EventFrame:UnregisterAllEvents() end)
	end
	Try(function() ZGV:Disable() end)
	Try(function() ZGV.Frame:Hide() end)
	Try(function() ZGV.EventDelayFrame:UnregisterAllEvents() end)
	Try(function() ZGV.Listener:UnregisterAllEvents() end)
	-- what it draws on the maps: its world map layers (unexplored-area overlay, points of interest, waypoint pins and
	-- lines) and its waypoint icons on the world map and minimap
	local map = _G["WorldMapFrame"] ---@type table   (FrameXML; the annotations don't declare it)
	local providers = map and map.dataProviders ---@type table?
	for _, provider in ipairs({ ZGV.Foglight and ZGV.Foglight.DataProvider, ZGV.Poi and ZGV.Poi.DataProvider,
		ZGV.Poi and ZGV.Poi.CurrentZoneDataProvider, Pointer and Pointer.OverlayProvider, Pointer and Pointer.Provider }) do
		if providers and providers[provider] then Try(function() map:RemoveDataProvider(provider) end) end
	end
	if ZGV.HBDPins and Pointer then
		Try(function() ZGV.HBDPins:RemoveAllWorldMapIcons(Pointer) end)
		Try(function() ZGV.HBDPins:RemoveAllMinimapIcons(Pointer) end)
	end
	-- its action bar (trash, talk-to and use buttons): a secure frame, so hidden out of combat, with its combat
	-- show/hide driver dropped so combat can't bring it back
	local bar = ZGV.ActionBar and ZGV.ActionBar.Frame ---@type table?
	if bar then
		local function HideBar()
			-- (a FrameXML global the annotations don't declare)
			Try(function() _G["UnregisterAttributeDriver"](bar, "state-combathide") end)
			Try(function() bar.Overlay:Hide() end)
			Try(function() bar:Hide() end)
		end
		if InCombatLockdown() then
			local wait = CreateFrame("Frame")
			wait:RegisterEvent("PLAYER_REGEN_ENABLED")
			wait:SetScript("OnEvent", function(self) self:UnregisterAllEvents() HideBar() end)
		else
			HideBar()
		end
	end
end

-- Zygor's startup checks the guides' jumps right after setting guidesloaded (in its startup coroutine): stop there,
-- before the rest of its startup runs. Yielding "waiting..." ends that frame's startup run; with the startup frame's
-- OnUpdate gone it never resumes.
if type(ZGV.CheckGuideJumps) == "function" then
	local check = ZGV.CheckGuideJumps
	ZGV.CheckGuideJumps = function(...)
		check(...)
		if Settings().keepZygor then return end
		local master = _G["ZygorGuidesViewerFrameMaster"] ---@type Frame?
		if master then master:SetScript("OnUpdate", nil) end
		if coroutine.running() then coroutine.yield("waiting: stopped by Obvi Guide") end
	end
end

-- "/og zygor": Zygor off or kept running. The rest of /og is Obvi Guide's own.
local slashCmdList = _G["SlashCmdList"] ---@type table<string, fun(msg: string)>
local obvi = slashCmdList.OBVIGUIDE
slashCmdList.OBVIGUIDE = function(msg)
	if (msg or ""):lower():match("^%s*(%S*)") ~= "zygor" then return obvi(msg) end
	local db = Settings()
	db.keepZygor = not db.keepZygor
	if db.keepZygor then
		print("|cff4fc3f7Obvi Guide|r: Zygor will keep running after the next /reload (its guides are still handed over)")
	else
		print("|cff4fc3f7Obvi Guide|r: Zygor " .. (ZGV.guidesloaded and "stopped" or "will stop once its guides are handed over"))
		if ZGV.guidesloaded then StopZygor() end
	end
end

local waited = 0
local ticker ---@type FunctionContainer
ticker = C_Timer.NewTicker(0.5, function()
	waited = waited + 0.5
	if not ZGV.guidesloaded and waited < 60 then return end
	ticker:Cancel()
	HandOver()
	if not Settings().keepZygor then
		StopZygor()
		print("|cff4fc3f7Obvi Guide|r: Zygor stopped (/og zygor keeps it running)")
	end
end)
