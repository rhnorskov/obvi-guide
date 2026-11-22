-- Hands the guides of your own installed Zygor addon to Obvi Guide, in game: each guide in Zygor's files that Zygor
-- would show you (with its text, so not the premium placeholders of the trial) goes to ObviGuide.Add with its title
-- and header as plain values. Nothing is copied to disk. Not published anywhere (friends may use it, but it isn't
-- promoted).
--
-- Zygor itself isn't needed, and is best left disabled: its files are read from its folder (ZygorFiles.xml) against a
-- stand-in for the little of Zygor they call (ZygorStandIn.lua), which also keeps to Zygor's licence. Enabled, Zygor
-- runs alongside Obvi Guide like any other addon; the bridge just says so.
--
-- When: Zygor's files have run by the time this file runs, so the guides are handed over at once. Obvi Guide reads a
-- guide's text only when it is first opened; the text (with Zygor's #include pieces filled in and the fixes below) is
-- made at that moment.
local _, ns = ...
---@class ObviGuideZygorNS
---@field HeaderCall fun(f: function|string): boolean, any
---@cast ns ObviGuideZygorNS

-- Zygor's files have run against the stand-in: Zygor's own globals back (nil when it isn't enabled)
_G["ZygorGuidesViewer"], _G["ZGV"] = ns.zygor, ns.zygorZGV
local guides = ns.guides

-- Fixes to Zygor's guide text, applied when a guide is read: the guide (by Zygor's title, as SanitizeGuideTitle has
-- it), the exact text in the guide and what it becomes. A fix whose guide or text isn't there (another client, or
-- Zygor changed the line) does nothing.
---@type {guide: string, find: string, replace: string}[]
local fixes = {
	-- Forever: the Beached Sea Creature for quest 4723 is at 32.9,81.1 (found in game 2026-10-20)
	{ guide = "LEVELING\\Darkshore (15-18)",
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
	local include = guides.registered_includes[title]
	return include and ((include:GetParsed(params)) .. "\n") or ""
end

--- The guide's text as Obvi Guide reads it.
---@param guide ObviGuideZygorGuide
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

--- Zygor's own "is this guide for this character" (the header's condition_visible, in Zygor's condition words). Asked
--- once, at hand-over; a guide whose check fails is listed.
---@param guide ObviGuideZygorGuide
---@return boolean
local function Visible(guide)
	local check = guide.headerdata.condition_visible
	if type(check) ~= "function" and type(check) ~= "string" then return true end
	local ok, yes = ns.HeaderCall(check)
	return not ok or not not yes
end

local function HandOver()
	local added, hidden = 0, 0
	for _, guide in ipairs(guides.registeredguides) do
		if Visible(guide) then
			local nextTitle = guide.headerdata.next
			added = added + ObviGuide.Add("zygor", function() return Text(guide) end, {
				title = guide.title,
				header = { next = type(nextTitle) == "string" and guides:SanitizeGuideTitle(nextTitle) or nil },
			})
		else
			hidden = hidden + 1
		end
	end
	if added + hidden + guides.unlicensed == 0 then
		print("|cff4fc3f7Obvi Guide|r: no Zygor guides found; is Zygor (ZygorGuidesViewerForever) installed? It can stay "
			.. "disabled")
		return
	end
	print(("|cff4fc3f7Obvi Guide|r: %d Zygor guides handed over (%d not for this character%s)"):format(added, hidden,
		guides.unlicensed > 0 and (", %d not covered by your Zygor licence"):format(guides.unlicensed) or ""))
	-- (Zygor, an optional dependency, has loaded by now if it's enabled)
	if ns.zygor then
		print("|cff4fc3f7Obvi Guide|r: Zygor is enabled too and runs alongside; its guides don't need it, so it can be "
			.. "disabled in the AddOns list")
	end
end
HandOver()
