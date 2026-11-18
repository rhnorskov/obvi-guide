-- Hands the guides of your own installed Zygor addon to Obvi Guide, in game: each guide Zygor has registered (with its
-- text, so not the premium placeholders of the trial) goes to ObviGuide.Add with its title and header as plain values.
-- Nothing is copied to disk. Not published anywhere (friends may use it, but it isn't promoted). Then Zygor itself is
-- stopped (see "Zygor off" below), unless "/og zygor" says to keep it running.
--
-- When: Zygor registers its guides as its files load (before this pack), then reads their headers (who each guide is
-- for) in its startup a few seconds after login, and sets ZGV.guidesloaded once that is done; no guides come after it
-- ("Too late to RegisterGuide"). So the guides are handed over then, or after a minute if Zygor never gets there.
-- Obvi Guide reads a guide's text only when it is first opened; the text (with Zygor's #include pieces filled in and
-- the fixes below) is made at that moment.
-- Zygor's addon is ZygorGuidesViewerForever (an optional dependency, so it loads first); it sets the global
-- ZygorGuidesViewer. Without it, nothing to do.
local ZGV = _G["ZygorGuidesViewer"] ---@type table
if not ZGV then return end

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
	local added, hidden = 0, 0
	for _, guide in ipairs(ZGV.registeredguides or {}) do
		if type(guide.rawdata) == "string" and not guide.missing then
			if Visible(guide) then
				local nextTitle = guide.headerdata and guide.headerdata.next
				added = added + ObviGuide.Add("zygor", function() return Text(guide) end, {
					title = guide.title,
					header = { next = type(nextTitle) == "string" and ZGV:SanitizeGuideTitle(nextTitle) or nil },
				})
			else
				hidden = hidden + 1
			end
		end
	end
	print(("|cff4fc3f7Obvi Guide|r: %d Zygor guides handed over (%d not for this character)%s"):format(added, hidden,
		ZGV.guidesloaded and "" or "; Zygor hadn't finished loading"))
end

-- Zygor off: once its guides are loaded, Zygor itself is stopped, so it can't clash with Obvi Guide: nothing of it
-- shows (window, arrow, action bar, map drawings, buttons it adds to the game's windows, tooltip lines) or runs (auto
-- accept, its events, timers and update loops). On by default; "/og zygor" keeps Zygor running instead
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
--- Stops Zygor, so nothing of it shows or runs. Its guides stay registered for Obvi Guide to read. Each part is looked
--- up as Zygor (Forever 1.6) has it, and skipped when it isn't there.
local function StopZygor()
	if stopped then return end
	stopped = true
	local Pointer = ZGV.Pointer ---@type table?
	local ItemScore = ZGV.ItemScore ---@type table?
	local Gold = ZGV.Gold ---@type table?

	--- A frame of Zygor's: no events, no OnUpdate, no OnEvent.
	---@param frame table?
	local function Quiet(frame)
		if not frame then return end
		Try(function() frame:UnregisterAllEvents() end)
		Try(function() frame:SetScript("OnUpdate", nil) end)
		Try(function() frame:SetScript("OnEvent", nil) end)
	end
	--- A frame of Zygor's: hidden.
	---@param frame table?
	local function Hide(frame) if frame then Try(function() frame:Hide() end) end end
	--- A function of Zygor's, called by name from a hook into the game's UI (hooks can't be undone): does nothing.
	---@param t table?
	---@param name string
	local function NoOp(t, name) if t and type(t[name]) == "function" then t[name] = function() end end end

	-- its startup: never resumed (it's frozen just after loading the guides, see below)
	Quiet(_G["ZygorGuidesViewerFrameMaster"])

	-- the arrow and waypoints, before the rest goes
	if Pointer then
		Try(function() Pointer:ClearWaypoints() end)
		Try(function() Pointer:HideArrow() end)
	end

	-- the addon: Ace's Disable hides its window and minimap button, and drops every event, message, timer and Ace hook
	-- it registered through Ace (auto accept, step completion, the rest of its event handlers)
	Try(function() ZGV:Disable() end)

	-- its frames that run outside Ace: its every-frame update loop (points of interest, waypoint pins, tabs, widgets),
	-- delayed events, startup checklist, arrow driver, map preview, travel planner (LibRover, with its own Ace timers),
	-- flight path tracker (LibTaxi), auction house trackers
	Quiet(ZGV.UpdateCentral)
	Quiet(ZGV.EventDelayFrame)
	Quiet(ZGV.Checklist and ZGV.Checklist.Listener)
	Quiet(Pointer and Pointer.EventFrame)
	Quiet(Pointer and Pointer.ArrowFrameCtrl)
	Quiet(ZGV.PointerMap and ZGV.PointerMap.TrackerFrame)
	local Rover = ZGV.LibRover ---@type table?
	if Rover then
		Quiet(Rover.frame)
		Quiet(Rover.F)
		Try(function() Rover:CancelAllTimers() end)
	end
	Quiet(ZGV.LibTaxi and ZGV.LibTaxi.frame)
	Quiet(Gold and Gold.Appraiser and Gold.Appraiser.Events)
	Quiet(Gold and Gold.Scan and Gold.Scan.FWORK)
	Quiet(Gold and Gold.Scan and Gold.Scan.FUI)

	-- what it shows: its window, arrow, action bar (below), the menu button on the world map, the bag-space count on the
	-- backpack button, the gear finder button on the character window, the creature viewer, the minimap button
	Hide(ZGV.Frame)
	Hide(Pointer and Pointer.ArrowFrame)
	Hide(ZGV.MapCoords and ZGV.MapCoords.MapButtonFrame)
	Hide(ZGV.Inventory and ZGV.Inventory.BagSpaceText)
	Hide(ZGV.Inventory and ZGV.Inventory.BagSpaceTextBG)
	Hide(ItemScore and ItemScore.GearFinder and ItemScore.GearFinder.PaperDollButton)
	Hide(ItemScore and ItemScore.GearFinder and ItemScore.GearFinder.MainFrame)
	Hide(ZGV.CreatureViewer and ZGV.CreatureViewer.Frame)
	Hide(_G["ZygorGuidesViewerMapIcon"])

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

	-- its hooks into the game's own windows and tooltips. Those that ask Zygor's settings first: the settings are off
	-- while it's stopped, and put back as they were at logout, before they're saved, so Zygor's own settings don't change
	local profile = ZGV.db and ZGV.db.profile ---@type table?
	local hidThings = false
	if profile then
		local keys = {
			"talenton", "ta_toggle_icons",                     -- talent advisor: icons on the talents, its menu button
			"autogear", "markupgrades", "itemscore_tooltips",  -- gear upgrades: bag marks, popups, tooltip lines
			"badupgradehotkey",                                -- gear upgrades: the click on a bag item
			"gold_tooltips_show",                              -- auction prices on item tooltips
			"hidetracker", "hideexptracker",                   -- hiding the game's quest tracker and XP bar
			"autoskipcutscenes",                               -- skipping cutscenes
		}
		hidThings = profile.hidetracker or profile.hideexptracker
		-- what was saved (nil: left at Zygor's default, and put back as nil so it stays one)
		local was = {} ---@type table<string, any>
		for _, key in ipairs(keys) do
			was[key] = rawget(profile, key)
			profile[key] = false
		end
		local logout = CreateFrame("Frame")
		logout:RegisterEvent("PLAYER_LOGOUT")
		logout:SetScript("OnEvent", function() for _, key in ipairs(keys) do rawset(profile, key, was[key]) end end)
	end
	-- the rest call these by name: clicking a map icon (suggests a guide), quest and player choices (recorded), the
	-- talents window (the advisor), its map preview, the bag-space count, the gear finder tab, a declined equip (marks a
	-- bad upgrade), the flight map's tooltips, the gossip options picked (recorded)
	NoOp(ZGV, "SuggestGuideFromBlizzardIcon")
	NoOp(ZGV, "QuestRewardSelect")
	NoOp(ZGV, "PlayerChoiceResponce")
	local TA = ZGV.TalentAdvisor ---@type table?
	if TA then
		-- it sets itself up when the talents window first loads: marked set up so it never does, or put away if it has
		if TA.Initialised then Try(function() TA:Toggle(false) end) else TA.Initialised = true end
		NoOp(TA, "SetTalents")
	end
	local PointerMap = ZGV.PointerMap ---@type table?
	if PointerMap then
		if PointerMap.PreviewVisible then Try(function() PointerMap:HidePreview(true) end) end
		NoOp(PointerMap, "HidePreview")
		NoOp(PointerMap, "RestoreMapSettings")
	end
	NoOp(ZGV.Inventory, "UpdateBagspaceText")
	NoOp(ItemScore and ItemScore.GearFinder, "UpdateSystemTab")
	NoOp(ItemScore and ItemScore.Upgrades, "SetBadUpgrade")
	NoOp(ZGV.LibTaxi and ZGV.LibTaxi.HooksForTaxiFrame, "ClassicTaxiButtonOnEnter")
	NoOp(ZGV.Telemetry and ZGV.Telemetry.Miner, "GetSelectedOption")
	-- the quest tracker and XP bar Zygor hides while its window is up (when set to): shown again, and no longer hidden
	local Replacements = ZGV.Replacements ---@type table?
	if Replacements then
		if hidThings then Try(function() Replacements:UpdateVisibility(true) end) end
		NoOp(Replacements, "UpdateVisibility")
	end

	-- its action bar (trash, talk-to and use buttons): a secure frame, so hidden out of combat, with its combat
	-- show/hide driver dropped so combat can't bring it back
	local bar = ZGV.ActionBar and ZGV.ActionBar.Frame ---@type table?
	if bar then
		local function HideBar()
			-- (a FrameXML global the annotations don't declare)
			Try(function() _G["UnregisterAttributeDriver"](bar, "state-combathide") end)
			Hide(bar.Overlay)
			Hide(bar)
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

-- "/og zygor": Zygor off or kept running (a command added to Obvi Guide's /og, see ObviGuide\ObviHub.lua).
local function ToggleZygor()
	local db = Settings()
	db.keepZygor = not db.keepZygor
	if db.keepZygor then
		print("|cff4fc3f7Obvi Guide|r: Zygor will keep running after the next /reload (its guides are still handed over)")
	else
		print("|cff4fc3f7Obvi Guide|r: Zygor " .. (ZGV.guidesloaded and "stopped" or "will stop once its guides are handed over"))
		if ZGV.guidesloaded then StopZygor() end
	end
end
ObviHub.AddCommand("guide", { "zygor", ToggleZygor, "keeps Zygor running, or stops it again" })

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
