-- Conditions: the small condition trees parsers build ("Alliance Hunter", "on quest 123", "level < 9") and the
-- engine evaluates against the character. A tree is { op, ... }:
--   {"and", c1, c2, ...}  {"or", c1, c2, ...}  {"not", c}  {"true"}  {"false"}
--   {"faction", "Alliance"}  {"class", "HUNTER"}  {"race", "Skyborne"}
--   {"level<", n}  {"level>", n}
--   {"onquest", id}  {"ready", id}  {"done", id}       (quest in the log / ready to turn in / turned in)
--   {"knows", spellID}  {"items>=", itemID, n}  {"items<", itemID, n}
--   {"area", areaID}  {"map", uiMapID, ...}  {"nomap"}   (where the player is)
--   {"aura", spellID}                                   (a buff or debuff on the player)
local _, ns = ...
---@cast ns AnyGuideNS

---@class AnyGuideConditions
local Conditions = {}
ns.Conditions = Conditions

-- race names guides use, lower case without spaces ("undead" is the game's "scourge")
Conditions.RACES = { skyborne = true, human = true, dwarf = true, nightelf = true, gnome = true, orc = true, troll = true,
	tauren = true, undead = true, scourge = true, draenei = true, bloodelf = true, worgen = true, goblin = true, pandaren = true }

local CLASS_TOKENS = {}   -- "hunter" -> "HUNTER", "deathknight" -> "DEATHKNIGHT"
-- LOCALIZED_CLASS_NAMES_MALE is a FrameXML global the annotations do not declare
local classNames = _G["LOCALIZED_CLASS_NAMES_MALE"] ---@type table<string, string>?
for token in pairs(classNames or {}) do CLASS_TOKENS[token:lower()] = token end

---@param word string  a class name in any case ("Hunter", "HUNTER")
---@return string? token
function Conditions.ClassToken(word)
	return CLASS_TOKENS[(word:gsub("%s", "")):lower()]
end

local function Race()
	local name, file = UnitRace("player")
	return (name or ""):gsub("%s", ""):lower(), (file or ""):lower()
end

local eval
local tests = {
	["and"] = function(c) for i = 2, #c do if not eval(c[i]) then return false end end return true end,
	["or"] = function(c) for i = 2, #c do if eval(c[i]) then return true end end return false end,
	["not"] = function(c) return not eval(c[2]) end,
	["true"] = function() return true end,
	["false"] = function() return false end,
	faction = function(c) return UnitFactionGroup("player") == c[2] end,
	class = function(c) return select(2, UnitClass("player")) == c[2] end,
	race = function(c) local name, file = Race() local want = c[2]:lower() return name == want or file == want end,
	["level<"] = function(c) return UnitLevel("player") < c[2] end,
	["level>"] = function(c) return UnitLevel("player") > c[2] end,
	onquest = function(c) return C_QuestLog.IsOnQuest(c[2]) end,
	ready = function(c) return C_QuestLog.ReadyForTurnIn(c[2]) end,
	done = function(c) return C_QuestLog.IsQuestFlaggedCompleted(c[2]) end,
	knows = function(c) return C_SpellBook.IsSpellKnown(c[2]) end,
	["items>="] = function(c) return C_Item.GetItemCount(c[2]) >= c[3] end,
	["items<"] = function(c) return C_Item.GetItemCount(c[2]) < c[3] end,
	-- in an area (an AreaTable id: zone or subzone), by its name as the game shows it
	area = function(c)
		local name = C_Map.GetAreaInfo(c[2])
		return name ~= nil and (GetSubZoneText() == name or GetZoneText() == name)
	end,
	-- on one of these maps (uiMapIDs)
	map = function(c)
		local here = C_Map.GetBestMapForUnit("player")
		for i = 2, #c do if c[i] == here then return true end end
		return false
	end,
	nomap = function() return C_Map.GetBestMapForUnit("player") == nil end,
	-- guarded: the call errors on some aura ids, and a condition must never break the window
	aura = function(c)
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, c[2])
		return ok and aura ~= nil
	end,
}

---@param c AnyGuideCond?
---@return boolean
eval = function(c)
	if not c then return true end
	local test = tests[c[1]]
	if not test then return true end  -- an unknown test never hides anything
	return test(c) and true or false
end
Conditions.Eval = eval

--- Combines conditions with "and", dropping empty ones.
---@param ... AnyGuideCond?
---@return AnyGuideCond?
function Conditions.All(...)
	local parts = {}
	for i = 1, select("#", ...) do
		local c = select(i, ...)
		if c then table.insert(parts, c) end
	end
	if #parts == 0 then return nil end
	if #parts == 1 then return parts[1] end
	return { "and", unpack(parts) }
end
