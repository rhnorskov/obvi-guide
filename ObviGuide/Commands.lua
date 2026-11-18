-- Slash commands: /og (or /obvi guide) toggles the window; "/og help" lists the rest (built by ObviHub.lua).
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

--- /og trainers <profession>: what QuestieDB knows of the NPCs whose title names the profession ("Journeyman
--- Engineer", "Engineering Supplies"): id, name, title, flags, who they're friendly to, and where they stand (the
--- first spawn in each zone), by title. To see whether trainers can be picked from QuestieDB rather than listed in each guide. Read a batch of NPCs
--- a frame, so the game doesn't stall.
---@param profession string
local function Trainers(profession)
	local DB = _G["LibQuestieDB"] ---@type table?
	if not (DB and DB.Npc) then ns.Print("this needs QuestieDB") return end
	if profession == "" then ns.Print("which profession? e.g. /og trainers Engineering") return end
	local stem = profession:sub(1, 5):lower()   -- "Engin": Engineer, Engineering Supplies
	local ids, i, found = DB.Npc.GetAllIds(), 1, {} ---@type integer[], integer, table[]
	ns.Print("looking through %d NPCs for '%s'...", #ids, profession)
	local function batch()
		for _ = 1, 1500 do
			local id = ids[i]
			if not id then break end
			i = i + 1
			local title = DB.Npc.Get(id, "subName")
			if type(title) == "string" and title:lower():find(stem, 1, true) then
				local spawns, where = DB.Npc.Get(id, "spawns") or {}, {}
				for area, list in pairs(spawns) do
					local p = list[1]
					local info = C_Map.GetAreaInfo(area)
					if p then table.insert(where, ("%s %.1f,%.1f%s"):format(info or ("area " .. area), p[1], p[2],
						#list > 1 and (" (+" .. (#list - 1) .. ")") or "")) end
				end
				table.insert(found, { id = id, name = DB.Npc.Get(id, "name") or "?", title = title,
					flags = DB.Npc.Get(id, "npcFlags") or 0, friendly = DB.Npc.Get(id, "friendlyToFaction") or "-",
					where = table.concat(where, "; ") })
			end
		end
		if ids[i] then C_Timer.After(0, batch) return end
		table.sort(found, function(a, b) return a.title < b.title or (a.title == b.title and a.name < b.name) end)
		local out = { ("%d NPCs titled like '%s' (QuestieDB): id | name | title | npcFlags (16 trainer, 4 vendor) |"
			.. " friendly to | where"):format(#found, profession) }
		for _, n in ipairs(found) do
			table.insert(out, ("%d | %s | %s | %d | %s | %s"):format(n.id, n.name, n.title, n.flags, n.friendly, n.where))
		end
		ns.Copy("Obvi Guide: " .. profession .. " NPCs", table.concat(out, "\n"))
	end
	batch()
end

local function List()
	if #ns.guides == 0 then ns.Print("no guides loaded; add a guide pack") return end
	for _, g in ipairs(ns.guides) do
		-- (a guide not opened yet isn't read, so its steps aren't counted)
		local steps = g.pending and "not read yet" or (#g.steps .. " steps")
		ns.Print("%s |cff888888(%s, %s, from %s)|r", g.title, g.group, steps, g.source)
	end
end

local function Debug()
	ns.debug = not ns.debug
	ns.Print("debug %s", ns.debug and "on" or "off")
	-- what the readers could not translate when the guides were added (before debug was on)
	if ns.debug and #ns.warnings > 0 then ns.Copy("Obvi Guide: guide warnings", table.concat(ns.warnings, "\n")) end
end

ObviHub.Register({ key = "guide", title = "Obvi Guide", command = "/og", commands = {
	{ "", function() ns.Window.Toggle() end, "shows or hides the guide window" },
	{ "guides", function() ns.GuidePicker.Open() end, "picks a guide" },
	{ "list", List, "lists the loaded guides in chat" },
	-- (the rest as typed: a quest's id, name or link)
	{ "catchup", function(quest) ns.Catchup.Start(quest) end, "finds skipped quests the guide needs (or: catchup <quest>)" },
	{ "cleanup", function() ns.Cleanup() end, "cleans up the quest log" },
	{ "junk", function() ns.DestroyCheapest() end, "offers to destroy the cheapest item in your bags" },
	{ "options", function() ns.Options.Open() end, "opens the options" },
	{ "debug", Debug, "debug output on or off" },
	{ "step", function() ns.Copy("Obvi Guide: current step", ns.Engine.DebugStep() .. "\n" .. ns.Travel.DebugObjective()) end,
		"what the guide makes of the current step", dev = true },
	{ "pins", function() ns.MinimapPins.Debug() end, "how the map pins are built", dev = true },
	{ "names", TestNames, "tests looking up creature and item names by id", dev = true },
	{ "trainers", Trainers, "the NPCs QuestieDB knows for a profession (trainers <profession>)", dev = true },
} })
