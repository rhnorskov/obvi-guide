-- Obvi Guide's page in the game's Options (Options > AddOns > Obvi Guide): the settings. The window's gear menu keeps the
-- actions (steps, Quest Cleanup, hide) and opens this page.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuideOptions
local Options = {}
ns.Options = Options

-- the game's settings API (FrameXML globals the annotations do not declare)
local Settings = _G["Settings"] ---@type table
local SectionHeader = _G["CreateSettingsListSectionHeaderInitializer"] ---@type fun(name: string): table

local category ---@type table?

--- A checkbox for a saved value; `default` is what nil means; `changed` runs after a change.
local function Checkbox(name, key, default, tooltip, changed)
	local setting = Settings.RegisterProxySetting(category, "ObviGuide_" .. key, Settings.VarType.Boolean, name, default,
		function()
			local v = ns.db and ns.db[key]
			if v == nil then return default end
			return v
		end,
		function(value)
			if not ns.db then return end
			-- the default is kept as nil, so a later change of the default reaches everyone who never touched it
			if value == default then ns.db[key] = nil else ns.db[key] = value end
			if changed then changed() end
		end)
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function Build()
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory("Obvi Guide")
	local function Header(text) if layout and SectionHeader then layout:AddInitializer(SectionHeader(text)) end end

	Header("Window")
	local upcoming = Settings.RegisterProxySetting(category, "ObviGuide_previewSteps", Settings.VarType.Number,
		"Upcoming steps", 0,
		function() return ns.db and ns.db.previewSteps or 0 end,
		function(value)
			if ns.db then ns.db.previewSteps = value ~= 0 and value or nil end
			ns.Window.Refresh()
		end)
	Settings.CreateDropdown(category, upcoming, function()
		local options = Settings.CreateControlTextContainer()
		options:Add(0, "None")
		for n = 1, 3 do options:Add(n, tostring(n)) end
		return options:GetData()
	end, "How many of the next steps the window shows, dimmed, under the current one.")
	Checkbox("Show on the minimap", "minimap", true,
		"The current step's destination and the spots it marks (yellow dots) on the minimap.",
		function() ns.MinimapPins.Refresh() end)
	-- the addons are only offered when installed; a saved choice that isn't shows (and works) as the arrow
	local waypoints = Settings.RegisterProxySetting(category, "ObviGuide_waypoints", Settings.VarType.String,
		"Waypoints", "arrow",
		function() return ns.Travel.Provider() end,
		function(value)
			if ns.db then ns.db.waypoints = value ~= "arrow" and value or nil end
			ns.Travel.Refresh()
		end)
	Settings.CreateDropdown(category, waypoints, function()
		local options = Settings.CreateControlTextContainer()
		options:Add("arrow", "Obvi Guide arrow")
		if ns.Travel.Available("spf") then options:Add("spf", "Shortest Path Forever") end
		if ns.Travel.Available("tomtom") then options:Add("tomtom", "TomTom") end
		options:Add("pin", "Map pin")
		options:Add("none", "None")
		return options:GetData()
	end, "How the way to the step's destination is shown: Obvi Guide's own arrow, Shortest Path Forever's journey, "
		.. "a TomTom waypoint, or the game's own map pin (with its arrow on the screen).")
	Checkbox("Flip window", "flip", false,
		"The window's header at the bottom with the step above it, growing upwards. For a window low on the screen.",
		function() ns.Window.Arrange() end)

	Header("Quests")
	Checkbox("Auto accept guide quests", "autoAccept", true,
		"Accepts the quests of the current and next step when you talk to the NPC (other quests are left alone). Hold Shift to skip it.")
	Checkbox("Auto turn in guide quests", "autoTurnin", true,
		"Turns in the quests of the current and next step (other quests are left alone). A choice of rewards is left to you. Hold Shift to skip it.")
	local missing = Settings.RegisterProxySetting(category, "ObviGuide_skipMissing", Settings.VarType.String,
		"Quests missing a prerequisite", "show",
		function() return ns.Engine.SkipMissing() end,
		function(value)
			if not ns.db then return end
			ns.db.skipMissing, ns.db.skipLocked = value ~= "show" and value or nil, nil
			ns.Engine.Advance()
			ns.Window.Refresh()
		end)
	Settings.CreateDropdown(category, missing, function()
		local options = Settings.CreateControlTextContainer()
		options:Add("show", "Show them")
		options:Add("notworth", "Skip when not worth catching up")
		options:Add("all", "Skip them")
		return options:GetData()
	end, "A quest that needs an earlier quest you haven't done (its chain began in a guide you skipped), or a turn-in for "
		.. "a quest you don't have. Shown, its step stays with the quest greyed out, so you can click it for a catch-up "
		.. "guide or go on with the arrow. Skipped, a step with nothing else to do is passed by: always, or only when "
		.. "catching up gives less XP per minute than the guide. A prerequisite still in your quest log keeps the step "
		.. "either way. Needs QuestieDB.")
	Checkbox("Skip hearthstone steps", "skipHearth", false,
		"Leaves out the guide's \"Hearth to ...\" and \"Set your Hearthstone to ...\" lines, and skips a step that has "
		.. "nothing else to do: for when you'd rather fly or walk, or keep your Hearthstone where it is.",
		function() ns.Engine.Advance() ns.Window.Refresh() end)
	Checkbox("Detailed catch-up numbers", "catchupDetails", false,
		"Beside Catch up on a quest you can't take yet: the XP it's worth (in bars of your XP bar), roughly how long it "
		.. "takes, and its XP per minute against the guide's. Off, just whether it's worth it (at least 1.2x the guide's "
		.. "XP per minute), about even, or not.",
		function() ns.Window.Refresh() end)

	Header("Troubleshooting")
	local debug = Settings.RegisterProxySetting(category, "ObviGuide_debug", Settings.VarType.Boolean, "Debug messages",
		false, function() return ns.debug end, function(value) ns.debug = value end)
	Settings.CreateCheckbox(category, debug, "Extra messages in chat (for this session).")

	Settings.RegisterAddOnCategory(category)
end

--- Opens ObviGuide's page in the game's Options.
function Options.Open()
	if category then Settings.OpenToCategory(category:GetID()) end
end

ns:On("ADDON_LOADED", function(_, name)
	if name ~= "ObviGuide" or category then return end
	local ok, err = pcall(Build)
	if not ok then ns.Print("couldn't add the options page: %s", tostring(err)) end
end)
