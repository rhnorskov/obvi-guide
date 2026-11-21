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
local _, ns = ...
---@class ObviGuideZygorNS
---@field Settings fun(): ObviGuideZygorDB
---@field FEATURES {key: string, name: string, tooltip: string}[]
---@field SetKeepZygor fun(keepZygor: boolean)
---@field OpenOptions? fun()
---@cast ns ObviGuideZygorNS

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
-- accept, its events, timers and update loops). On by default. Its features that work without its guides can each be
-- left running (Options > AddOns > Obvi Guide: Zygor, see Options.lua), and "/og zygor" (or the page) keeps all of
-- Zygor running instead, from the next /reload. Kept in ObviGuideZygorDB.

---@class ObviGuideZygorDB
---@field keepZygor? boolean            all of Zygor runs as usual
---@field run? table<string, boolean>   features left running while Zygor is stopped, by key (FEATURES)

--- The saved settings. (The game sets ObviGuideZygorDB after this file has run, so it's looked up each time.)
---@return ObviGuideZygorDB
local function Settings()
	ObviGuideZygorDB = ObviGuideZygorDB or {}
	return ObviGuideZygorDB
end

--- Zygor's features that work without its guides, which can be left running while it's stopped (all of them stop by
--- default). Its window, arrow, action bar, auto accept and the rest run off its guides: those need all of Zygor.
---@type {key: string, name: string, tooltip: string}[]
local FEATURES = {
	{ key = "talents", name = "Talent advisor",
		tooltip = "Zygor's suggested talents on the talents window, and its button there." },
	{ key = "gear", name = "Gear upgrades",
		tooltip = "Zygor's upgrade marks on bag items, upgrade lines in item tooltips, and its gear finder button on the "
			.. "character window." },
	{ key = "vendor", name = "Vendor and bags",
		tooltip = "Selling grey items and repairing at vendors (as Zygor's own options say), and the free bag space on the "
			.. "backpack button." },
	{ key = "map", name = "World map layers",
		tooltip = "Zygor's points of interest and unexplored areas on the world map, and its menu button on the map." },
	{ key = "auction", name = "Auction house tools",
		tooltip = "Zygor's auction house scans and prices, and auction prices in item tooltips." },
	{ key = "flightmap", name = "Flight map tooltips",
		tooltip = "Zygor's extra lines in the flight map's tooltips." },
}

--- Is a feature left running while Zygor is stopped?
---@param key string
---@return boolean
local function Runs(key)
	local run = Settings().run
	return run ~= nil and run[key] == true
end

-- for Options.lua
ns.Settings, ns.FEATURES = Settings, FEATURES

--- Calls f, quietly: a part of Zygor that isn't there (another version) is skipped.
---@param f fun()
local function Try(f) pcall(f) end

--- Runs one of Zygor's startup steps that its frozen startup never got to (by name), to the end.
---@param name string
local function RunStartup(name)
	for _, startup in ipairs(ZGV.startups or {}) do
		if type(startup) == "table" and startup.name == name and not startup.done and type(startup.func) == "function" then
			startup.done = true
			local co = coroutine.create(function() startup.func(ZGV) end)
			-- (startup steps yield now and then; a step that never ends is given up on)
			for _ = 1, 10000 do
				if not coroutine.resume(co) or coroutine.status(co) == "dead" then break end
			end
		end
	end
end

local stopped = false
--- Stops Zygor, so nothing of it shows or runs but the features left running (FEATURES). Its guides stay registered
--- for Obvi Guide to read. Each part is looked up as Zygor (Forever 1.6) has it, and skipped when it isn't there.
local function StopZygor()
	if stopped then return end
	stopped = true
	local Pointer = ZGV.Pointer ---@type table?
	local ItemScore = ZGV.ItemScore ---@type table?
	local Gold = ZGV.Gold ---@type table?
	local Inventory = ZGV.Inventory ---@type table?
	local TA = ZGV.TalentAdvisor ---@type table?
	local Poi = ZGV.Poi ---@type table?
	local talents, gear, vendor, mapLayers, auction, flightmap =
		Runs("talents"), Runs("gear"), Runs("vendor"), Runs("map"), Runs("auction"), Runs("flightmap")

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

	-- the event handlers of the features left running (Zygor's own, as it registered them), found before they go
	local keep = {} ---@type table<function, boolean>
	local events = ZGV.Events_Events ---@type table<string, any[]>?
	local function Keep(handler) if type(handler) == "function" then keep[handler] = true end end
	if talents and TA then Keep(TA.DelayedSetTalents) end
	if gear and ItemScore then
		Keep(ItemScore.OnEvent)
		Keep(ItemScore.Upgrades and ItemScore.Upgrades.AttachBagButton)
	end
	if vendor and Inventory then Keep(Inventory.OnEvent) end
	if mapLayers and events then
		-- the points of interest's handler is Zygor's local: the one handling both loot and achievement criteria
		local loot = rawget(events, "LOOT_READY") or {}
		for _, h in ipairs(rawget(events, "CRITERIA_UPDATE") or {}) do
			if tContains(loot, h) then Keep(h) end
		end
	end

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

	-- the features left running get their own events back, and only their own handlers (shared events, like bag
	-- updates, no longer reach the action bar and the rest). A handler's error is swallowed: Zygor is stopped.
	if events and next(keep) then
		for event, handlers in pairs(events) do
			local kept = {}
			for _, h in ipairs(handlers) do
				if keep[h] then kept[#kept + 1] = function(...) pcall(h, ...) end end
			end
			events[event] = kept
			if kept[1] then Try(function() ZGV:RegisterEvent(event, "EventHandler_Events") end) end
		end
	end

	-- its frames that run outside Ace: its every-frame update loop (points of interest, waypoint pins, tabs, widgets),
	-- delayed events, startup checklist, arrow driver, map preview, travel planner (LibRover, with its own Ace timers),
	-- flight path tracker (LibTaxi), auction house trackers
	local central = ZGV.UpdateCentral ---@type table?
	if mapLayers and central and central.UpdateHandlers then
		-- the points of interest's update is Zygor's local too: everything but the waypoints', tabs' and widgets'
		local others = {} ---@type table<any, boolean>
		for _, f in ipairs({ Pointer and Pointer.Provider and Pointer.Provider.OnUpdate,
			Pointer and Pointer.OverlayProvider and Pointer.OverlayProvider.OnUpdate,
			ZGV.Tabs and ZGV.Tabs.OnUpdate, ZGV.Widgets and ZGV.Widgets.UpdateDriver }) do
			if f then others[f] = true end
		end
		local kept = {}
		for _, h in ipairs(central.UpdateHandlers) do if not others[h] then kept[#kept + 1] = h end end
		central.UpdateHandlers = kept
	else
		Quiet(central)
	end
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
	if not flightmap then Quiet(ZGV.LibTaxi and ZGV.LibTaxi.frame) end
	if auction then
		-- its auction startup steps come after the guides, so the frozen startup never ran them
		for _, name in ipairs({ "Gold", "Servertrends", "Gold scan startup" }) do Try(function() RunStartup(name) end) end
	else
		Quiet(Gold and Gold.Appraiser and Gold.Appraiser.Events)
		Quiet(Gold and Gold.Scan and Gold.Scan.FWORK)
		Quiet(Gold and Gold.Scan and Gold.Scan.FUI)
	end

	-- what it shows: its window, arrow, action bar (below), the menu button on the world map, the bag-space count on the
	-- backpack button, the gear finder button on the character window, the creature viewer, the minimap button
	Hide(ZGV.Frame)
	Hide(Pointer and Pointer.ArrowFrame)
	if not mapLayers then Hide(ZGV.MapCoords and ZGV.MapCoords.MapButtonFrame) end
	if not vendor then
		Hide(Inventory and Inventory.BagSpaceText)
		Hide(Inventory and Inventory.BagSpaceTextBG)
	end
	if not gear then
		Hide(ItemScore and ItemScore.GearFinder and ItemScore.GearFinder.PaperDollButton)
		Hide(ItemScore and ItemScore.GearFinder and ItemScore.GearFinder.MainFrame)
	end
	Hide(ZGV.CreatureViewer and ZGV.CreatureViewer.Frame)
	Hide(_G["ZygorGuidesViewerMapIcon"])

	-- what it draws on the maps: its world map layers (unexplored-area overlay and points of interest, unless left
	-- running; waypoint pins and lines) and its waypoint icons on the world map and minimap
	local map = _G["WorldMapFrame"] ---@type table   (FrameXML; the annotations don't declare it)
	local providers = map and map.dataProviders ---@type table?
	local drop = { Pointer and Pointer.OverlayProvider, Pointer and Pointer.Provider }
	if not mapLayers then
		table.insert(drop, ZGV.Foglight and ZGV.Foglight.DataProvider)
		table.insert(drop, Poi and Poi.DataProvider)
		table.insert(drop, Poi and Poi.CurrentZoneDataProvider)
	end
	for _, provider in pairs(drop) do
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
			"hidetracker", "hideexptracker",   -- hiding the game's quest tracker and XP bar
			"autoskipcutscenes",               -- skipping cutscenes
		}
		-- the talent advisor: icons on the talents, its menu button
		if not talents then table.insert(keys, "talenton") table.insert(keys, "ta_toggle_icons") end
		-- gear upgrades: bag marks, popups, tooltip lines, the click on a bag item
		if not gear then
			for _, key in ipairs({ "autogear", "markupgrades", "itemscore_tooltips", "badupgradehotkey" }) do
				table.insert(keys, key)
			end
		end
		-- auction prices on item tooltips
		if not auction then table.insert(keys, "gold_tooltips_show") end
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
	-- the rest call these by name: clicking a map icon (suggests a guide), quest and player choices (recorded), its map
	-- preview, the gossip options picked (recorded), and the stopped features' own
	NoOp(ZGV, "SuggestGuideFromBlizzardIcon")
	NoOp(ZGV, "QuestRewardSelect")
	NoOp(ZGV, "PlayerChoiceResponce")
	NoOp(ZGV.Telemetry and ZGV.Telemetry.Miner, "GetSelectedOption")
	local PointerMap = ZGV.PointerMap ---@type table?
	if PointerMap then
		if PointerMap.PreviewVisible then Try(function() PointerMap:HidePreview(true) end) end
		NoOp(PointerMap, "HidePreview")
		NoOp(PointerMap, "RestoreMapSettings")
	end
	if TA and not talents then
		-- it sets itself up when the talents window first loads: marked set up so it never does, or put away if it has
		if TA.Initialised then Try(function() TA:Toggle(false) end) else TA.Initialised = true end
		NoOp(TA, "SetTalents")
	end
	if not gear then
		NoOp(ItemScore and ItemScore.GearFinder, "UpdateSystemTab")
		NoOp(ItemScore and ItemScore.Upgrades, "SetBadUpgrade")
	end
	-- (at a vendor, it also looks for things to buy for its own guide's step: not while it's stopped)
	NoOp(Inventory, "FindItemsToBuyDelayed")
	if not vendor then NoOp(Inventory, "UpdateBagspaceText") end
	if not flightmap then NoOp(ZGV.LibTaxi and ZGV.LibTaxi.HooksForTaxiFrame, "ClassicTaxiButtonOnEnter") end
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

--- All of Zygor kept running (from the next /reload), or stopped again (now, once its guides are handed over).
---@param keepZygor boolean
local function SetKeepZygor(keepZygor)
	Settings().keepZygor = keepZygor or nil
	if keepZygor then
		print("|cff4fc3f7Obvi Guide|r: Zygor will keep running after the next /reload (its guides are still handed over)")
	else
		print("|cff4fc3f7Obvi Guide|r: Zygor " .. (ZGV.guidesloaded and "stopped" or "will stop once its guides are handed over"))
		if ZGV.guidesloaded then StopZygor() end
	end
end
ns.SetKeepZygor = SetKeepZygor

-- "/og zygor": Zygor kept running or stopped again (a command added to Obvi Guide's /og, see ObviGuide\ObviHub.lua);
-- "/og zygor options": the page in the game's Options
ObviHub.AddCommand("guide", { "zygor", function(rest)
	if (rest or ""):lower():match("^%s*option") or (rest or ""):lower():match("^%s*config") then
		if ns.OpenOptions then ns.OpenOptions() end
		return
	end
	SetKeepZygor(not Settings().keepZygor)
end, "keeps Zygor running, or stops it again; /og zygor options: which of its features to keep" })

local waited = 0
local ticker ---@type FunctionContainer
ticker = C_Timer.NewTicker(0.5, function()
	waited = waited + 0.5
	if not ZGV.guidesloaded and waited < 60 then return end
	ticker:Cancel()
	HandOver()
	if not Settings().keepZygor then
		StopZygor()
		print("|cff4fc3f7Obvi Guide|r: Zygor stopped (/og zygor keeps it running; /og zygor options for its features)")
	end
end)
