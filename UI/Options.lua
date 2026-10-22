-- AnyGuide's page in the game's Options (Options > AddOns > AnyGuide): the settings. The window's gear menu keeps the
-- actions (steps, Quest Cleanup, hide) and opens this page.
local _, ns = ...
---@cast ns AnyGuideNS

---@class AnyGuideOptions
local Options = {}
ns.Options = Options

-- the game's settings API (FrameXML globals the annotations do not declare)
local Settings = _G["Settings"] ---@type table
local SectionHeader = _G["CreateSettingsListSectionHeaderInitializer"] ---@type fun(name: string): table

local category ---@type table?

--- A checkbox for a saved value; `default` is what nil means; `changed` runs after a change.
local function Checkbox(name, key, default, tooltip, changed)
	local setting = Settings.RegisterProxySetting(category, "AnyGuide_" .. key, Settings.VarType.Boolean, name, default,
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
	category, layout = Settings.RegisterVerticalLayoutCategory("AnyGuide")
	local function Header(text) if layout and SectionHeader then layout:AddInitializer(SectionHeader(text)) end end

	Header("Window")
	local upcoming = Settings.RegisterProxySetting(category, "AnyGuide_previewSteps", Settings.VarType.Number,
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

	Header("Quests")
	Checkbox("Auto accept quests", "autoAccept", false,
		"Accepts the quests the current step accepts when you talk to the NPC. Hold Shift to skip it.")
	Checkbox("Auto turn in quests", "autoTurnin", false,
		"Turns in the quests the current step turns in. A choice of rewards is left to you. Hold Shift to skip it.")

	Header("Troubleshooting")
	local debug = Settings.RegisterProxySetting(category, "AnyGuide_debug", Settings.VarType.Boolean, "Debug messages",
		false, function() return ns.debug end, function(value) ns.debug = value end)
	Settings.CreateCheckbox(category, debug, "Extra messages in chat (for this session).")

	Settings.RegisterAddOnCategory(category)
end

--- Opens AnyGuide's page in the game's Options.
function Options.Open()
	if category then Settings.OpenToCategory(category:GetID()) end
end

ns:On("ADDON_LOADED", function(_, name)
	if name ~= "AnyGuide" or category then return end
	local ok, err = pcall(Build)
	if not ok then ns.Print("couldn't add the options page: %s", tostring(err)) end
end)
