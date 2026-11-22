-- A stand-in for the little of Zygor that its guide files call while they load, so the bridge reads them from Zygor's
-- folder itself (ZygorFiles.xml) and Zygor doesn't have to be enabled at all. Zygor's files are plain Lua: each guide
-- is a ZygorGuidesViewer:RegisterGuide(title, header, text) call. This file puts the stand-in in Zygor's two globals
-- (ZygorGuidesViewer and ZGV) while Zygor's files run, keeping Zygor's own (when it's enabled too) aside; ZygorBridge.lua
-- puts Zygor's back once they have run.
--
-- A guide counts only when Zygor itself would register it (Guide:New in its Guide.lua): not one its header hides, and
-- only one your Zygor licence covers. Zygor checks that licence (Licence.lua in its folder, kept up to date by Zygor's
-- own app) before registering a guide; Licensed below is the same check, so the bridge hands over exactly the guides
-- Zygor would show you, and none once the licence runs out.
local _, ns = ...
---@class ObviGuideZygorNS
---@field guides ObviGuideZygorStandIn   what Zygor's guide files registered
---@field zygor? table                    Zygor's own ZygorGuidesViewer, when it's enabled
---@field zygorZGV? table                 and its ZGV
---@cast ns ObviGuideZygorNS

---@class ObviGuideZygorGuide
---@field title string        Zygor's title, as Zygor keeps it ("LEVELING\\Westfall (13-15)")
---@field headerdata table    the header as the guide file has it (next, condition_visible, ...)
---@field rawdata string      the guide text

---@class ObviGuideZygorStandIn
---@field registeredguides ObviGuideZygorGuide[]
---@field registered_includes table<string, {text: string, GetParsed: fun(self, params: table?): string}>
---@field unlicensed integer   guides left out because the licence has run out (or lacks their tier)
---@field Licences? table      set by Zygor's Licence.lua
---@field GuideMenuTier? string   set by each guide file: "CLA" (the full guides) or "TRI" (the trial's)
local Z = {
	registeredguides = {},
	registered_includes = {},
	registered_functions = {},
	guidesets = {},
	unlicensed = 0,
	IMAGESDIR = "Interface\\AddOns\\ZygorGuidesViewerForever\\Guides-Forever\\Images\\",
}

-- The files in Zygor's list that hold no guides fill in parts of Zygor as they load (gear scores into ItemScore, talent
-- builds into TalentAdvisor, points of interest into Poi, a flag into Gold): those parts take anything and keep nothing.
local sink
sink = setmetatable({}, { __index = function() return sink end, __newindex = function() end })
Z.ItemScore, Z.TalentAdvisor, Z.Poi, Z.Gold = sink, sink, sink, sink

-- Zygor's condition words, for a guide header's Lua (condition_visible, hideif, next): the race, class and faction
-- names (any case, as Zygor's ConditionEnv has them) and level; anything else is the game's global.
local RACES = { "LightforgedDraenei", "VoidElf", "DarkIronDwarf", "HighmountainTauren", "ZandalariTroll", "Nightborne",
	"MagharOrc", "KulTiran", "Vulpera", "Mechagnome", "EarthenDwarf", "NightElf", "Dwarf", "Human", "Gnome", "Draenei",
	"Worgen", "Orc", "Troll", "Scourge", "Tauren", "BloodElf", "Goblin", "Pandaren", "Dracthyr", "Skyborne" }
local RACE_ALIASES = { undead = "scourge", lfdraenei = "lightforgeddraenei", hmtauren = "highmountaintauren",
	ztroll = "zandalaritroll", didwarf = "darkirondwarf", mhorc = "magharorc", kthuman = "kultiran", mgnome = "mechagnome",
	earthen = "earthendwarf" }
local CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "deathknight", "shaman", "mage", "warlock", "monk",
	"druid", "demonhunter", "evoker" }

local env ---@type table?
--- The environment a header's Lua runs in (made when first needed: the character is known by then).
---@return table
local function Env()
	if env then return env end
	local words = {} ---@type table<string, any>
	local race = (select(2, UnitRace("player")) or ""):lower()
	for _, r in ipairs(RACES) do words[r:lower()] = r:lower() == race end
	for alias, r in pairs(RACE_ALIASES) do words[alias] = words[r] end
	local class = (select(2, UnitClass("player")) or ""):lower()
	for _, c in ipairs(CLASSES) do words[c] = c == class end
	local faction = (UnitFactionGroup("player") or ""):lower()
	for _, f in ipairs({ "alliance", "horde", "neutral" }) do words[f] = f == faction end
	env = setmetatable({}, { __index = function(_, k)
		if k == "level" or k == "intlevel" then return UnitLevel("player") end
		local word = type(k) == "string" and words[k:lower()]
		if word ~= nil then return word end
		return _G[k]
	end })
	return env
end

--- Runs a header's Lua (a function, or an expression as text) in Zygor's condition words.
---@param f function|string
---@return boolean ok, any result
function ns.HeaderCall(f)
	if type(f) == "string" then
		local chunk = loadstring("return " .. f)
		if not chunk then return false, nil end
		f = chunk
	end
	setfenv(f, Env())
	return pcall(f)
end

-- Zygor's licence check (NeedsAnimatedPopup in its Parser.lua, written out plainly): the licence has a key per guide
-- type, tier ("CLA", "TRI") and side ("A", "H"); a key is good when it names that type, tier and side, its checksum adds
-- up, and the date it holds hasn't passed.
local TYPES = { LEVELING = 1, LOREMASTER = 2, DAILIES = 3, EVENTS = 4, DUNGEONS = 5, GEAR = 5, PROFESSIONS = 6,
	ACHIEVEMENTS = 7, GOLD = 8, PETSMOUNTS = 9, TITLES = 10, REPUTATIONS = 11, MACROS = 12, TEST = 13, MISC = 14 }
local TIERS = { TRI = 0, CAT = 1, MOP = 2, WOD = 3, LEG = 4, BFA = 5, SHA = 6, DRA = 7, CLA = 1, BCC = 2, WLK = 3 }
local SIDES = { A = 1, H = 2 }

local today ---@type integer?
--- Does the licence cover guides of this type and tier for this character's side?
---@param kind string
---@param tier string?
---@return boolean
local function Licensed(kind, tier)
	local side = UnitFactionGroup("player") == "Alliance" and "A" or "H"
	local byKind = type(Z.Licences) == "table" and Z.Licences[kind]
	local key = type(byKind) == "table" and tier and type(byKind[tier]) == "table" and byKind[tier][side]
	if type(key) ~= "string" or #key < 22 then return false end
	if tonumber(key:sub(13, 14)) ~= TYPES[kind] or tonumber(key:sub(15, 15)) ~= TIERS[tier]
		or tonumber(key:sub(16, 16)) ~= SIDES[side] then
		return false
	end
	local sum, weight = 0, 1
	for digit in key:sub(1, 23):gmatch(".") do
		local n = tonumber(digit) or 0
		sum, weight = sum + n * weight, weight + n
	end
	if tonumber(key:sub(24, 27)) ~= sum then return false end
	local mask = tonumber(key:sub(19, 23)) or 0
	local untilTime = tonumber(("%05d%05d"):format(bit.bxor(tonumber(key:sub(1, 6)) or 0, mask),
		bit.bxor(tonumber(key:sub(7, 12)) or 0, mask)))
	if not today then
		local d = (C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
			or C_DateAndTime.GetTodaysDate()) --[[@as table]]
		today = time({ year = d.year, month = d.month, day = d.monthDay or d.day })
	end
	return untilTime ~= nil and untilTime >= today
end

-- What Zygor's guide files call, as Zygor does it (its ZygorGuidesViewer.lua and Guide.lua)

--- "Leveling Guides\\Westfall (13-15)" -> "LEVELING\\Westfall (13-15)", Zygor's own form of a title.
---@param title string?
---@return string?
function Z:SanitizeGuideTitle(title)
	if not title then return end
	title = title:gsub([[\\]], [[\]])
	title = title:gsub("^Zygor's ", "")
	title = title:gsub("^Alliance ", ""):gsub("^Horde ", "")
	title = title
		:gsub("^Event.-\\", "EVENTS\\")
		:gsub("^Dail.-\\", "DAILIES\\")
		:gsub("^Leveling.-\\", "LEVELING\\")
		:gsub("^Loremaster.-\\", "LOREMASTER\\")
		:gsub("^Profession.-\\", "PROFESSIONS\\")
		:gsub("^Achievement.-\\", "ACHIEVEMENTS\\")
		:gsub("^Pet.-\\", "PETSMOUNTS\\")
		:gsub("^Reputation.-\\", "REPUTATIONS\\")
		:gsub("^Title.-\\", "TITLES\\")
		:gsub("^Macro.-\\", "MACROS\\")
		:gsub("^Dungeon.-\\", "DUNGEONS\\")
		:gsub("^Gear.-\\", "GEAR\\")
		:gsub("^Test Guide.-\\", "TEST\\")
		:gsub("^Misc.-\\", "MISC\\")
	return title
end

--- Each guide file's first call: true when a file of the same set has run already (a full guide file, then its trial
--- copy: only the first that's there counts).
---@param set string
---@return boolean?
function Z:DoMutex(set)
	self.GuideMenuTier = nil
	if self.guidesets[set] then return true end
	self.guidesets[set] = true
end

---@param title string
---@param header any   the header (a table), or the text when there's no header
---@param data? any    the text
function Z:RegisterGuide(title, header, data)
	title = self:SanitizeGuideTitle(title) --[[@as string]]
	if not data then header, data = {}, header end
	if type(title) ~= "string" or type(header) ~= "table" or type(data) ~= "string" then return end
	-- what its header hides, and the points-of-interest loader (a placeholder Zygor opens from its map, not a guide)
	if header.hideif == true or header.only_hardcore or header.poiloader then return end
	if type(header.hideif) == "function" then
		local ok, hide = ns.HeaderCall(header.hideif)
		if ok and hide then return end
	end
	if type(header.next) == "function" then
		local ok, nextTitle = ns.HeaderCall(header.next)
		if ok then header.next = nextTitle end
	end
	-- what the licence doesn't cover (Zygor's shared guides need none). Counted only for a type the licence has at all:
	-- the gold guides in Zygor's files have none on Forever, so Zygor never shows them either.
	local path = title:match("^(.*)\\+.-$") or title
	local kind = path:match("^(.-)\\") or path
	if not path:find("SHARED") and not Licensed(kind, self.GuideMenuTier) then
		if type(self.Licences) == "table" and type(self.Licences[kind]) == "table" then
			self.unlicensed = self.unlicensed + 1
		end
		return
	end
	table.insert(self.registeredguides, { title = title, headerdata = header, rawdata = data })
end

---@param title string
---@param text string
function Z:RegisterInclude(title, text)
	self.registered_includes[title] = { text = text, GetParsed = function(include, params)
		return (include.text:gsub("%%(%w+)%%", function(param) return params and params[param] or "" end))
	end }
end

---@param title string
---@param func fun(): string
function Z:RegisterFunction(title, func)
	self.registered_functions[title] = { func = func }
end

-- the rest it may call: nothing to keep
function Z:RegisterGuidePlaceholder() end
function Z:RegisterGuideSorting() end
function Z:RegisterMapSpots() end
function Z.BETASTART() end
function Z.BETAEND() end

ns.guides = Z
-- Zygor's own, when it's enabled (it loads first, an optional dependency), aside while its files run
ns.zygor, ns.zygorZGV = _G["ZygorGuidesViewer"], _G["ZGV"]
_G["ZygorGuidesViewer"], _G["ZGV"] = Z, Z
