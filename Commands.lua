-- Slash commands: /obvi or /og (or /obviguide) toggles the window; "/og list" lists the loaded guides; "/og debug";
-- "/og names" tests looking up creature and item names by id; "/og cleanup" cleans up the quest log.
local _, ns = ...
---@cast ns ObviGuideNS

--- A creature's name from its id, through a tooltip for a made-up creature link (nil when the game doesn't know it).
---@param id integer
---@return string?
local function CreatureName(id)
	local ok, data = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
	local line = ok and data and data.lines and data.lines[1]
	local name = line and line.leftText
	return (name and name ~= "") and name or nil
end

--- An item's name from its id (nil while the game hasn't loaded it; asking makes it load).
---@param id integer
---@return string?
local function ItemName(id)
	local name = C_Item.GetItemNameByID(id)
	if not name then C_Item.RequestLoadItemDataByID(id) end
	return name
end

--- Asks for every id, then twice more (3 seconds apart) for the ones the game didn't know, and reports how many
--- worked and which names differ from the guide's: the pass counts in chat, the whole report into `out`.
---@param label string
---@param written table<integer, string>   id -> the guide's name
---@param lookup fun(id: integer): string?
---@param out string[]                     the report's lines
---@param done fun()                       called after the report
local function TestLookups(label, written, lookup, out, done)
	local ids = {}
	for id in pairs(written) do table.insert(ids, id) end
	table.sort(ids)
	if #ids == 0 then table.insert(out, label .. ": none in the loaded guides") done() return end
	local found = {} ---@type table<integer, string>
	local function pass(n)
		local got, missing = 0, 0
		for _, id in ipairs(ids) do
			found[id] = found[id] or lookup(id)
			if found[id] then got = got + 1 else missing = missing + 1 end
		end
		local line = ("%s pass %d: %d of %d named, %d unknown"):format(label, n, got, #ids, missing)
		ns.Print(line)
		table.insert(out, line)
		if missing > 0 and n < 3 then C_Timer.After(3, function() pass(n + 1) end) return end
		-- what's still unknown, and names that differ from the guide's (often just plurals)
		for _, id in ipairs(ids) do
			if not found[id] then table.insert(out, ("  unknown: %d (guide: %s)"):format(id, written[id])) end
		end
		for _, id in ipairs(ids) do
			if found[id] and found[id] ~= written[id] then
				table.insert(out, ("  differs: %d game '%s', guide '%s'"):format(id, found[id], written[id]))
			end
		end
		table.insert(out, "")
		done()
	end
	pass(1)
end

--- The goal's text without colours, icons or brackets (the guide's name for an item, roughly).
---@param s string
---@return string
local function Plain(s)
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("[%[%]]", "")
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Test: can every creature and item in the loaded guides be named from its id? (Guides not opened yet aren't read,
--- so they have no steps to test.)
local function TestNames()
	local creatures, items = {}, {} ---@type table<integer, string>, table<integer, string>
	local function creature(t) if t and t.id and not creatures[t.id] then creatures[t.id] = t.name end end
	local function item(g)
		local k = g.kind
		if g.id and not items[g.id] and (k == "use" or k == "equip" or k == "collect" or k == "hearth") then items[g.id] = Plain(g.text) end
	end
	for _, guide in ipairs(ns.guides) do
		for _, step in ipairs(guide.steps) do
			creature(step.target)
			for _, g in ipairs(step.goals) do creature(g.target) item(g) end
			for _, g in ipairs(step.side) do creature(g.target) item(g) end
		end
	end
	local out = {}
	TestLookups("creatures", creatures, CreatureName, out, function()
		TestLookups("items", items, ItemName, out, function() ns.Copy("Obvi Guide: name lookups", table.concat(out, "\n")) end)
	end)
end

SLASH_OBVIGUIDE1, SLASH_OBVIGUIDE2, SLASH_OBVIGUIDE3 = "/obvi", "/og", "/obviguide"
-- SlashCmdList is a FrameXML global the WoW annotations do not declare, hence the _G lookup.
local slashCmdList = _G["SlashCmdList"] ---@type table<string, fun(msg: string)>
slashCmdList.OBVIGUIDE = function(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	if cmd == "list" then
		if #ns.guides == 0 then ns.Print("no guides loaded; add a guide pack") return end
		for _, g in ipairs(ns.guides) do
			-- (a guide not opened yet isn't read, so its steps aren't counted)
			local steps = g.pending and "not read yet" or (#g.steps .. " steps")
			ns.Print("%s |cff888888(%s, %s, from %s)|r", g.title, g.group, steps, g.source)
		end
	elseif cmd == "debug" then
		ns.debug = not ns.debug
		ns.Print("debug %s", ns.debug and "on" or "off")
		-- what the readers could not translate when the guides were added (before debug was on)
		if ns.debug and #ns.warnings > 0 then ns.Copy("Obvi Guide: guide warnings", table.concat(ns.warnings, "\n")) end
	elseif cmd == "pins" then
		ns.MinimapPins.Debug()
	elseif cmd == "cleanup" then
		ns.Cleanup()
	elseif cmd == "names" then
		TestNames()
	else
		ns.Window.Toggle()
	end
end
