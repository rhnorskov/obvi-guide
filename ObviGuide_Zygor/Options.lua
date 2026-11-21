-- The bridge's page in the game's Options (Options > AddOns > Obvi Guide: Zygor, or "/og zygor options"): whether
-- Zygor is stopped once its guides are handed over, and which of its features are stopped with it (all, by default).
-- What's set here takes effect at the next /reload, except stopping Zygor, which happens at once.
local _, ns = ...
---@cast ns ObviGuideZygorNS

-- (only with Zygor installed: ZygorBridge.lua sets these up)
if not ns.FEATURES then return end

-- the game's settings API (FrameXML globals the annotations do not declare)
local Settings = _G["Settings"] ---@type table
local SectionHeader = _G["CreateSettingsListSectionHeaderInitializer"] ---@type fun(name: string): table

local category ---@type table?

local function Build()
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory("Obvi Guide: Zygor")

	local stop = Settings.RegisterProxySetting(category, "ObviGuideZygor_stop", Settings.VarType.Boolean, "Stop Zygor",
		true,
		function() return not ns.Settings().keepZygor end,
		function(value) ns.SetKeepZygor(not value) end)
	local stopInit = Settings.CreateCheckbox(category, stop,
		"Once Zygor's guides are handed over to Obvi Guide, Zygor itself is stopped, so it can't clash with Obvi Guide: "
		.. "its window, arrow, action bar, auto accept and map drawings. Off, all of Zygor runs as usual (from the next "
		.. "/reload); its guides are still handed over.")

	if layout and SectionHeader then layout:AddInitializer(SectionHeader("Stopped with it")) end
	for _, feature in ipairs(ns.FEATURES) do
		local key = feature.key
		local setting = Settings.RegisterProxySetting(category, "ObviGuideZygor_stop_" .. key, Settings.VarType.Boolean,
			feature.name, true,
			function() return not (ns.Settings().run or {})[key] end,
			function(value)
				local db = ns.Settings()
				db.run = db.run or {}
				-- (stopped, the default, is kept as nil)
				db.run[key] = not value or nil
				if not next(db.run) then db.run = nil end
			end)
		local init = Settings.CreateCheckbox(category, setting, feature.tooltip
			.. " Unticked, it keeps running while the rest of Zygor is stopped (from the next /reload).")
		-- greyed out while all of Zygor runs anyway
		if init and init.SetParentInitializer and stopInit then
			init:SetParentInitializer(stopInit, function() return not ns.Settings().keepZygor end)
		end
	end

	Settings.RegisterAddOnCategory(category)
end

--- Opens the page in the game's Options.
function ns.OpenOptions()
	if category then Settings.OpenToCategory(category:GetID()) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
	if name ~= "ObviGuide_Zygor" then return end
	self:UnregisterAllEvents()
	local ok, err = pcall(Build)
	if not ok then print("|cff4fc3f7Obvi Guide|r: couldn't add the Zygor options page: " .. tostring(err)) end
end)
