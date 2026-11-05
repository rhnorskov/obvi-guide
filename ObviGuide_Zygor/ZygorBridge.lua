-- Hands the guides of my own installed Zygor addon to Obvi Guide, in game: each guide Zygor has registered (with its
-- text, so not the premium placeholders of the trial) goes to ObviGuide.Add with its title and header as plain values.
-- Nothing is copied to disk. Personal use only (guides I own); not for sharing.
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

local waited = 0
local ticker ---@type FunctionContainer
ticker = C_Timer.NewTicker(0.5, function()
	waited = waited + 0.5
	if not ZGV.guidesloaded and waited < 60 then return end
	ticker:Cancel()
	HandOver()
end)
