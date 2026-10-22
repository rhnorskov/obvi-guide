-- Parser for Zygor guide syntax (the text inside Zygor's RegisterGuide calls): text in, neutral guides out.
-- AnyGuide reads only text handed to AnyGuide.Add; it never looks at the Zygor addon itself. The title and header of a
-- guide are Lua in Zygor's files, so a pack hands them over as plain values:
--   AnyGuide.Add("zygor", [[ ...guide text... ]], { title = "Leveling Guides\\Westfall (13-15)", header = {...} })
-- header: next (a Zygor title), faction ("Alliance"/"Horde"), visible and hideif (Zygor's Lua expressions as text),
-- trial (true for the free trial's copy of a guide).
--
-- The format, as far as AnyGuide uses it (Zygor's own reader is Parser.lua, the line kinds are in Goal.lua):
--   step                      a step; "label X" names it, "|only if <lua>" on a line of its own makes it conditional
--   stickystart "X" / stickystop "X"   between steps: the step labelled X is shown alongside the following steps
--   a line is chunks split by "|": the first is a command (talk Name##npc, accept Title##quest, kill 5 Mob##npc,
--   collect 8 Item##item, ...) or plain text; the rest modify it (goto Zone x,y < dist, q 123/1, only if ...,
--   tip text, future, c, n, noway, or (one of several lines), next "label" (jump there when the step is done), ...)
local _, ns = ...
---@cast ns AnyGuideNS

local Conditions = ns.Conditions
local COLORS = ns.Colors
local HEARTHSTONE = 6948   -- item id

---@class AnyGuideParser
local Zygor = {}
ns.Parsers.zygor = Zygor

-- Zone names -> classic uiMapIDs, from the Forever port's map table (ZygorGuidesViewer\Libs-Classic\LibRover-1.0\
-- data.lua, MapIDsByName). Dungeons there have made-up ids, so they are left out: points in them are dropped.
local MAPS = {
	["Alterac Mountains"] = 1416, ["Arathi Highlands"] = 1417, ["Badlands"] = 1418, ["Blasted Lands"] = 1419,
	["Burning Steppes"] = 1428, ["Deadwind Pass"] = 1430, ["Dun Morogh"] = 1426, ["Duskwood"] = 1431,
	["Eastern Plaguelands"] = 1423, ["Elwynn Forest"] = 1429, ["Hillsbrad Foothills"] = 1424, ["Ironforge"] = 1455,
	["Loch Modan"] = 1432, ["Redridge Mountains"] = 1433, ["Searing Gorge"] = 1427, ["Silverpine Forest"] = 1421,
	["Stormwind City"] = 1453, ["Stranglethorn Vale"] = 1434, ["Swamp of Sorrows"] = 1435, ["The Hinterlands"] = 1425,
	["Tirisfal Glades"] = 1420, ["Undercity"] = 1458, ["Western Plaguelands"] = 1422, ["Westfall"] = 1436,
	["Wetlands"] = 1437, ["Ashenvale"] = 1440, ["Azshara"] = 1447, ["Darkshore"] = 1439, ["Darnassus"] = 1457,
	["Desolace"] = 1443, ["Durotar"] = 1411, ["Dustwallow Marsh"] = 1445, ["Felwood"] = 1448, ["Feralas"] = 1444,
	["Moonglade"] = 1450, ["Mulgore"] = 1412, ["Orgrimmar"] = 1454, ["Silithus"] = 1451,
	["Stonetalon Mountains"] = 1442, ["Tanaris"] = 1446, ["Teldrassil"] = 1438, ["The Barrens"] = 1413,
	["Thousand Needles"] = 1441, ["Thunder Bluff"] = 1456, ["Un'Goro Crater"] = 1449, ["Winterspring"] = 1452,
	["Alterac Valley"] = 1459, ["Arathi Basin"] = 1461, ["Warsong Gulch"] = 1460,
}

-- Forever redrew some zone maps, so Zygor's (classic) coordinates on them are moved into the new map frame:
-- classic map x,y -> world position (classic frame) -> map x,y (Forever frame). Copied from the Forever port
-- (ZygorGuidesViewer\Code-Forever\Stubs.lua, ZGV.ForeverMapFrames and ZGV.ForeverShiftXY). Per map:
-- { minX, maxX, minY, maxY } in world yards, X = north, Y = west; map x runs east (-Y), map y runs south (-X).
local FRAMES = {
	[1412] = { classic = { -3697.917, -272.917, -3089.583, 2047.917 }, forever = { -3835.416, 266.666, -3675.000, 2479.167 } }, -- Mulgore
	[1423] = { classic = { 1218.750, 3800.000, -6056.250, -2185.417 }, forever = { 825.000, 3691.667, -6558.334, -2256.250 } }, -- Eastern Plaguelands
	[1433] = { classic = { -10022.916, -8575.000, -3741.667, -1570.833 }, forever = { -10022.916, -8575.000, -3852.084, -1681.250 } }, -- Redridge Mountains
	[1453] = { classic = { -9175.205, -8278.851, 36.701, 1380.971 }, forever = { -9154.170, -7995.830, -14.584, 1722.920 } }, -- Stormwind City
}

---@param map integer
---@param x number   0..1
---@param y number   0..1
---@return number, number
local function Shift(map, x, y)
	local f = FRAMES[map]
	if not f then return x, y end
	local c, n = f.classic, f.forever
	local worldY = c[4] - x * (c[4] - c[3])
	local worldX = c[2] - y * (c[2] - c[1])
	return (n[4] - worldY) / (n[4] - n[3]), (n[2] - worldX) / (n[2] - n[1])
end

-- Zygor's colour braces ({o}text{}) and _highlights_, as its apply_colours has them
local BRACES = { o = "ff7d40", orange = "ff7d40", g = "00ff00", green = "00ff00", r = "ff0000", red = "ff0000",
	b = "3dbffb", blue = "3dbffb", y = "ffcc00", yellow = "ffcc00", p = "cf3dbf", purple = "cf3dbf", w = "ffffff",
	white = "ffffff", q0 = "9d9d9d", poor = "9d9d9d", q1 = "ffffff", common = "ffffff", q2 = "1eff00",
	uncommon = "1eff00", q3 = "0070dd", rare = "0070dd", q4 = "a335ee", epic = "a335ee" }

---@param s string
---@return string
local function Colour(s)
	s = s:gsub("_(.-)_", "|cffffee88%1|r"):gsub("{}", "|r")
	s = s:gsub("{#(%x+)}", "|cff%1"):gsub("{(%w+)}", function(k) return BRACES[k] and ("|cff" .. BRACES[k]) end)
	s = s:gsub("%%UNDER%%", "_")
	return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

---@param name string
---@param color string   a key of ns.Colors
local function Named(name, color)
	return "|c" .. COLORS[color] .. name .. "|r"
end

--- "Name##123" (or "4 Name##123+", "Name##123, Other##456") -> name, id, count; for several, the first.
---@param s string
---@return string name, integer? id, integer? count, string all, {name: string, id?: integer}[] list
---  all: every name, for "Kill A, B"; list: each of them
local function Thing(s)
	local count, rest = s:match("^(%d+)%s+(.+)$")
	s = rest or s
	local names, list = {}, {}
	for part in (s .. ","):gmatch("%s*(.-)%s*,") do
		if part ~= "" then
			local n, id = part:match("^(.-)##?(%d+)")   -- (one guide line has "Name#id")
			n = (n or part):gsub("%+$", ""):gsub('^"(.-)"$', "%1")
			table.insert(names, n)
			table.insert(list, { name = n, id = tonumber(id) })
		end
	end
	local first = list[1] or { name = "" }
	return first.name, first.id, tonumber(count), table.concat(names, ", "), list
end

--- Every one of several named NPCs or mobs ("kill A##1, B##2") as targets, in the order written; nil for one.
---@param list {name: string, id?: integer}[]
---@param enemy? boolean
---@return {name: string, id?: integer, enemy?: boolean}[]?
local function Targets(list, enemy)
	if #list < 2 then return nil end
	local targets = {}
	for _, t in ipairs(list) do table.insert(targets, { name = t.name, id = t.id, enemy = enemy }) end
	return targets
end

-- ---------------------------------------------------------------------------------------------------------------
-- Conditions: Zygor's "|only if" lines are Lua ("NightElf Druid", "haveq(123) or level >= 10"). The common words and
-- calls become condition trees; the rest counts as "always" and is reported.

local CLASSES = { warrior = "WARRIOR", paladin = "PALADIN", hunter = "HUNTER", rogue = "ROGUE", priest = "PRIEST",
	shaman = "SHAMAN", mage = "MAGE", warlock = "WARLOCK", druid = "DRUID" }

-- Faction names Zygor's rep() uses -> classic faction ids. Others (Season of Discovery's) stay names, which the
-- condition looks up in game.
local FACTIONS = {
	["Stormwind"] = 72, ["Ironforge"] = 47, ["Gnomeregan Exiles"] = 54, ["Darnassus"] = 69, ["Orgrimmar"] = 76,
	["Thunder Bluff"] = 81, ["Undercity"] = 68, ["Darkspear Trolls"] = 530, ["Timbermaw Hold"] = 576,
	["Cenarion Circle"] = 609, ["Brood of Nozdormu"] = 910, ["Argent Dawn"] = 529, ["Thorium Brotherhood"] = 59,
	["Hydraxian Waterlords"] = 749, ["Zandalar Tribe"] = 270, ["Bloodsail Buccaneers"] = 87, ["Booty Bay"] = 21,
	["Ratchet"] = 470, ["Gadgetzan"] = 369, ["Everlook"] = 577, ["Wintersaber Trainers"] = 589,
	["Frostwolf Clan"] = 729, ["Stormpike Guard"] = 730, ["Silverwing Sentinels"] = 890, ["Warsong Outriders"] = 889,
	["League of Arathor"] = 509, ["The Defilers"] = 510, ["Ravenholdt"] = 349, ["Shen'dralar"] = 809,
	["Darkmoon Faire"] = 909, ["Gelkis Clan Centaur"] = 92, ["Magram Clan Centaur"] = 93,
}
-- standings as rep() compares them (the game's reaction numbers)
local STANDINGS = { Hated = 1, Hostile = 2, Unfriendly = 3, Neutral = 4, Friendly = 5, Honored = 6, Revered = 7,
	Exalted = 8 }

local TRUE, FALSE = { "true" }, { "false" }

--- A race, class or faction word as a test, or nil.
---@param w string
---@return AnyGuideCond?
local function Word(w)
	local lw = w:lower()
	if lw == "alliance" or lw == "horde" then return { "faction", lw == "alliance" and "Alliance" or "Horde" } end
	if CLASSES[lw] then return { "class", CLASSES[lw] } end
	if Conditions.RACES[lw] then return { "race", (lw == "undead" or lw == "scourge") and "scourge" or lw } end
end

-- the parts of an expression while it is read: a condition, a number, a numeric expression or something unknown
---@class AnyGuideZygorValue
---@field c? AnyGuideCond      a condition (TRUE/FALSE when known to be constant)
---@field n? number            a number
---@field s? string            a string
---@field num? string          a numeric expression: "level", "items", "rep" or "money"
---@field id? integer|string   for "items": the item; for "rep": the faction (id, or name)
---@field u? boolean           unknown

local function C(c) return { c = c } end
local UNKNOWN = { u = true }

---@param v AnyGuideZygorValue
---@return AnyGuideZygorValue   as a condition (a number is true in Lua)
local function Bool(v)
	if v.c or v.u then return v end
	if v.n or v.s or v.num then return C(TRUE) end
	return UNKNOWN
end

local function Not(v)
	v = Bool(v)
	if v.u then return v end
	if v.c == TRUE then return C(FALSE) elseif v.c == FALSE then return C(TRUE) end
	if v.c[1] == "not" then return C(v.c[2]) end
	return C({ "not", v.c })
end

--- "and": an unknown part is left out (it counts as always true); "or": an unknown part makes it always true.
local function Join(op, list)
	local parts, unknown = { op }, false
	for _, v in ipairs(list) do
		v = Bool(v)
		if v.u then unknown = true
		elseif op == "and" and v.c == FALSE then return C(FALSE)
		elseif op == "or" and v.c == TRUE then return C(TRUE)
		elseif not ((op == "and" and v.c == TRUE) or (op == "or" and v.c == FALSE)) then table.insert(parts, v.c) end
	end
	if op == "or" and unknown then return UNKNOWN end
	if #parts == 1 then
		if unknown then return UNKNOWN end
		return C(op == "and" and TRUE or FALSE)
	end
	return C(#parts == 2 and parts[2] or parts)
end

---@param kind string
---@param ids any[]
local function AnyQuest(kind, ids, all)
	local list = {}
	for _, id in ipairs(ids) do
		if type(id) ~= "number" then return UNKNOWN end   -- "123/1" (an objective) or a range
		table.insert(list, C({ kind, id }))
	end
	if #list == 0 then return UNKNOWN end
	return Join(all and "and" or "or", list)
end

-- the calls Zygor's conditions use that have a test here
local CALLS = {
	haveq = function(a) return AnyQuest("onquest", a) end,
	completedq = function(a) return AnyQuest("done", a) end,
	completedanyq = function(a) return AnyQuest("done", a) end,
	completedallq = function(a) return AnyQuest("done", a, true) end,
	readyq = function(a) return AnyQuest("ready", a) end,
	readyallq = function(a) return AnyQuest("ready", a, true) end,
	itemcount = function(a) if #a == 1 and type(a[1]) == "number" then return { num = "items", id = a[1] } end return UNKNOWN end,
	hasbuff = function(a) if type(a[1]) == "number" then return C({ "aura", a[1], a[2] }) end return UNKNOWN end,
	equipped = function(a) if type(a[1]) == "number" then return C({ "equipped", a[1] }) end return UNKNOWN end,
	subzone = function(a) if type(a[1]) == "string" then return C({ "subzone", a[1] }) end return UNKNOWN end,
	-- a zone with a map here by its map; others (dungeons) by name
	zone = function(a)
		if type(a[1]) ~= "string" then return UNKNOWN end
		local m = MAPS[a[1]]
		return C(m and { "map", m } or { "zone", a[1] })
	end,
	rep = function(a) if type(a[1]) == "string" then return { num = "rep", id = FACTIONS[a[1]] or a[1] } end return UNKNOWN end,
	GetMoney = function() return { num = "money" } end,
	-- enough money for a mount: Zygor takes 10% off from honored with the faction that sells it
	discountgold = function(a)
		local f, amount = a[1], a[2]
		if type(f) ~= "string" or type(amount) ~= "number" then return UNKNOWN end
		return C({ "or", { "money", amount }, { "and", { "rep", FACTIONS[f] or f, 6 }, { "money", math.ceil(amount * 0.9) } } })
	end,
	indoors = function() return C({ "indoors" }) end,
	IsIndoors = function() return C({ "indoors" }) end,
	knowspell = function(a) if type(a[1]) == "number" then return C({ "knows", a[1] }) end return UNKNOWN end,
	isdead = function() return C({ "dead" }) end,
	-- no flying in classic content, and Forever characters are neither hardcore nor self-made
	iswalking = function() return C(TRUE) end,
	hardcore = function() return C(FALSE) end,
	selfmade = function() return C(FALSE) end,
	-- the optional dungeon runs a player picks in Zygor's window; nobody has picked them here
	guideflag = function() return C(FALSE) end,
}
-- the words that stand for a value without a call
local WORDS = {
	walking = C(TRUE), hardcore = C(FALSE), selfmade = C(FALSE), ["true"] = C(TRUE), ["false"] = C(FALSE),
	isdead = C({ "dead" }), level = { num = "level" }, intlevel = { num = "level" },
	["ZGV.IsClassicSoD"] = C(FALSE), ["ZGV.IsClassicHardcore"] = C(FALSE),
}
for name, n in pairs(STANDINGS) do WORDS[name] = { n = n } end

--- "level >= 10", "itemcount(123) < 5" as a test.
---@param l AnyGuideZygorValue
---@param op string
---@param r AnyGuideZygorValue
---@return AnyGuideZygorValue
local function Compare(l, op, r)
	if r.num and l.n then
		local flip = { ["<"] = ">", [">"] = "<", ["<="] = ">=", [">="] = "<=" }
		l, r, op = r, l, flip[op] or op
	end
	local n = r.n
	if not (l.num and n) then return UNKNOWN end
	-- as "less than n" or "at least n" (whole numbers for items; levels are whole here too)
	local lt, ge
	if op == "<" then lt = n elseif op == "<=" then lt = n + 1 elseif op == ">=" then ge = n elseif op == ">" then ge = n + 1
	elseif op == "==" then lt, ge = n + 1, n elseif op == "~=" then return Not(Compare(l, "==", r)) end
	if not (lt or ge) then return UNKNOWN end
	local parts = {}
	if l.num == "level" then
		if ge then table.insert(parts, C({ "level>", ge - 1 })) end
		if lt then table.insert(parts, C({ "level<", lt })) end
	elseif l.num == "rep" or l.num == "money" then
		-- both are "at least" tests
		local function AtLeast(m) return C(l.num == "rep" and { "rep", l.id, m } or { "money", m }) end
		if ge then table.insert(parts, AtLeast(ge)) end
		if lt then table.insert(parts, Not(AtLeast(lt))) end
	else
		if ge then table.insert(parts, C({ "items>=", l.id, ge })) end
		if lt then table.insert(parts, C({ "items<", l.id, lt })) end
	end
	return Join("and", parts)
end

--- Zygor's condition Lua as a condition tree. Returns the tree (nil: always) and whether a part was not understood.
---@param s string
---@return AnyGuideCond? cond, boolean partial
local function Expr(s)
	local toks, pos = {}, 1
	while pos <= #s do
		local c = s:sub(pos, pos)
		if c:find("%s") then
			pos = pos + 1
		elseif c == '"' or c == "'" then
			local e = s:find(c, pos + 1, true)
			if not e then return nil, true end
			table.insert(toks, { t = "str", v = s:sub(pos + 1, e - 1) })
			pos = e + 1
		else
			local num = s:match("^%d+%.?%d*", pos)
			local op = not num and (s:match("^[<>=~]=", pos) or s:match("^[<>(),]", pos))
			local id = not (num or op) and s:match("^[%a_][%w_%.:]*", pos)
			if num then table.insert(toks, { t = "num", v = tonumber(num) }) pos = pos + #num
			elseif op then table.insert(toks, { t = "op", v = op }) pos = pos + #op
			elseif id then table.insert(toks, { t = "id", v = id }) pos = pos + #id
			else return nil, true end
		end
	end
	local i, partial = 1, false
	local function peek() return toks[i] end
	local function isOp(v) return toks[i] and toks[i].t == "op" and toks[i].v == v end
	local function isWord(v) return toks[i] and toks[i].t == "id" and toks[i].v == v end
	local Or
	local function Atom()
		local t = toks[i]
		if not t then error("ends early", 0) end
		i = i + 1
		if t.t == "op" and t.v == "(" then
			local v = Or()
			if not isOp(")") then error("no )", 0) end
			i = i + 1
			return v
		elseif t.t == "num" then return { n = t.v }
		elseif t.t == "str" then return { s = t.v }
		elseif t.t == "id" then
			if isOp("(") then
				i = i + 1
				local args = {}
				while not isOp(")") do
					local a = toks[i]
					if not a then error("no )", 0) end
					if not isOp(",") then table.insert(args, a.v) end
					i = i + 1
				end
				i = i + 1
				local call = CALLS[(t.v:gsub("^_G%.", ""))]
				local v = call and call(args) or UNKNOWN
				if v.u then partial = true end
				return v
			end
			local v = WORDS[t.v] or (Word(t.v) and C(Word(t.v)))
			if CALLS[t.v] and not v then v = CALLS[t.v]({}) end   -- "|only if hardcore": a call without its ()
			if not v then partial = true return UNKNOWN end
			return v
		end
		error("unexpected " .. tostring(t.v), 0)
	end
	local function Cmp()
		local l = Atom()
		local t = peek()
		if t and t.t == "op" and t.v:find("^[<>=~]") then
			i = i + 1
			local v = Compare(l, t.v, Atom())
			if v.u then partial = true end
			return v
		end
		return l
	end
	local function NotE()
		if isWord("not") then i = i + 1 return Not(NotE()) end
		return Cmp()
	end
	local function And()
		local list = { NotE() }
		while true do
			if isWord("and") then i = i + 1
			-- "NightElf Druid": words side by side mean "and", as Zygor reads them
			elseif not (peek() and (peek().t == "id" or isOp("(")) and not isWord("or")) then break end
			table.insert(list, NotE())
		end
		return #list == 1 and list[1] or Join("and", list)
	end
	Or = function()
		local list = { And() }
		while isWord("or") do i = i + 1 table.insert(list, And()) end
		return #list == 1 and list[1] or Join("or", list)
	end
	local ok, v = pcall(function()
		local r = Or()
		if toks[i] then error("left over", 0) end
		return r
	end)
	if not ok then return nil, true end
	v = Bool(v)
	if v.u then return nil, true end
	if v.c == TRUE then return nil, partial end
	return v.c, partial
end

--- "|only Human Warlock,Dwarf" (no "if"): any of the comma-separated race/class/faction words (all of them in one).
---@return AnyGuideCond?, boolean partial
local function RaceClass(s)
	local alts = {}
	for alt in (s .. ","):gmatch("%s*(.-)%s*,") do
		if alt ~= "" then
			local neg = alt:sub(1, 1) == "!"
			local words = {}
			for w in (neg and alt:sub(2) or alt):gmatch("%S+") do
				local c = Word(w)
				if not c then return nil, true end
				table.insert(words, C(c))
			end
			local v = Join("and", words)
			table.insert(alts, neg and Not(v) or v)
		end
	end
	local v = Join("or", alts)
	if v.u or v.c == TRUE then return nil, v.u == true end
	return v.c, false
end

-- ---------------------------------------------------------------------------------------------------------------
-- Lines

-- line commands that make the goal (the first one on a line counts)
local ACTIONS = { talk = true, accept = true, turnin = true, kill = true, collect = true, get = true, buy = true,
	use = true, cast = true, click = true, clicknpc = true, goal = true, ding = true, level = true, home = true,
	hearth = true, fpath = true, fly = true, confirm = true, equip = true, equipped = true, learnspell = true, trash = true,
	bank = true, vendor = true, trainer = true, stablemaster = true, gossip = true, complete = true, condition = true,
	havebuff = true, nobuff = true, skill = true, skillmax = true, invehicle = true, outvehicle = true,
	zombiewalk = true, getrune = true, learnpetspell = true, unequipped = true, unequip = true }
-- Zygor-window scripts and the like: a line with one of these is dropped (and reported)
-- other Zygor line commands the leveling guides use now and then; reported, and the line has nothing to show
local OTHER = { expcollect = true, turninany = true, useany = true, achieve = true, rep = true, repcollect = true,
	goldcollect = true, create = true, craft = true, abandon = true, scenariogoal = true }
local DROP = { talknpcs = true, openskill = true, autoscript = true, execute = true, popuptext = true, script = true,
	loadguide = true, nexttab = true }
-- modifiers that change nothing here (waypoint and automation hints, Zygor-window behaviour)
local IGNORE = { walk = true, notinsticky = true, onlyinsticky = true, notravel = true, region = true,
	instant = true, noautoaccept = true, noautogossip = true, usebank = true, delay = true, sticky = true,
	stickyif = true, macro = true, forceuse = true, optional = true, opt = true, important = true, h = true,
	hide = true, image = true, autoacceptany = true, autoturninany = true, direct = true, nowayinzone = true,
	indoors = true, outdoors = true, killcount = true, noobsolete = true, repeatable = true, daily = true,
	showtext = true, more = true, travelfor = true, title = true, defaultfor = true, model = true,
	modelnpc = true, blizztooltip = true, buttonicon = true, accountwide = true, usename = true, noordinal = true,
	nomovieskip = true, nohearth = true, travelcfg = true, minizone = true, mapicon = true, required = true,
	gotoontaxi = true, countexpr = true, updatescript = true, grouprole = true, orlogic = true, meta = true }

---@class AnyGuideZygorLine
---@field action? string
---@field params? string
---@field text? string          the line's own text (it replaces the generated one)
---@field cond? AnyGuideCond
---@field point? AnyGuidePoint
---@field noway? boolean
---@field quest? integer
---@field objective? integer
---@field future? boolean
---@field complete? boolean     "c": reached by arriving
---@field nocomplete? boolean   "n": never done by itself
---@field orGroup? string       "or": one of several lines (Zygor's group name)
---@field orCount? integer      how many of the group must be done
---@field next? string          "next": the label to go on at
---@field override? boolean     "override": done means the step is done
---@field quests? integer[]     "multiq": several quests
---@field tips string[]

---@class AnyGuideZygorCtx
---@field map? integer        the map the last coordinates were on (lines may leave the zone out)
---@field counts table<string, integer>
---@field order string[]

---@param ctx AnyGuideZygorCtx
---@param msg string
local function Warn(ctx, msg)
	if not ctx.counts[msg] then ctx.counts[msg] = 0 table.insert(ctx.order, msg) end
	ctx.counts[msg] = ctx.counts[msg] + 1
end

--- "Zone/0 45.20,42.40 < 20", "Zone 45.2,42.4", "45.2,42.4" -> point (nil when it can't be placed).
---@param s string
---@param ctx AnyGuideZygorCtx
---@return AnyGuidePoint?
local function Point(s, ctx)
	s = s:gsub('%s*"[^"]*"%s*$', "")   -- a "title" after the coordinates
	local mapText, x, y, rest = s:match("^%s*(.-)%s*,?%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*(.-)%s*$")
	if not x then return nil end
	local radius = tonumber(rest:match("^<%s*([%d%.]+)") or "")
	local map
	if mapText ~= "" then
		mapText = mapText:gsub("%s*/%s*%d+$", "")
		map = tonumber(mapText) or MAPS[mapText]
		if not map then Warn(ctx, ("no map for the zone '%s'; its points are left out"):format(mapText)) return nil end
		ctx.map = map
	else
		map = ctx.map
		if not map then return nil end
	end
	local px, py = (tonumber(x) or 0) / 100, (tonumber(y) or 0) / 100
	-- every coordinate in a Zygor guide is a classic one (the Forever port only shifts those with the zone written out)
	if not tonumber(mapText) then px, py = Shift(map, px, py) end
	return { map = map, x = px, y = py, radius = radius }
end

--- One line -> its parts. Returns nil for an empty line; step-level parts (labels, conditions) go to `step` directly.
---@param line string
---@param step AnyGuideZygorStep
---@param ctx AnyGuideZygorCtx
---@return AnyGuideZygorLine?, boolean? dropped
local function ReadLine(line, step, ctx)
	---@type AnyGuideZygorLine
	local rec = { tips = {} }
	local any, n = false, 0
	line = line:gsub("\\|", "%%PIPE%%"):gsub("\\_", "%%UNDER%%")
	for piece in (line .. "|"):gmatch("%s*(.-)%s*|+") do
		local chunk = piece
		if chunk ~= "" then
			n = n + 1
			chunk = chunk:gsub("%%PIPE%%", "|"):gsub("^'%s*", "' ")
			local cmd, params = chunk:match("^(%S*)%s*(.-)$")
			if cmd == "label" then
				step.label = params:gsub('^"(.-)"$', "%1")
			elseif cmd == "map" then
				local m = MAPS[(params:gsub("%s*/%s*%d+$", ""))]
				if m then ctx.map = m end
			elseif cmd == "mapmarker" then
				-- where the mobs or things of a step are (Zygor's orange dots on the maps), not a point to walk to
				local saved = ctx.map
				local p = Point(params, ctx)
				ctx.map = saved
				if p then step.markers = step.markers or {} table.insert(step.markers, p) end
			elseif cmd == "only" then
				local expr = params:match("^if%s+(.*)$")
				local c, partial
				if expr then c, partial = Expr(expr) else c, partial = RaceClass(params) end
				if partial then Warn(ctx, ('only if: can\'t read "%s"; read as always'):format(expr or params)) end
				-- on a line of its own it is the step's condition, else the line's
				if n == 1 then step.conds[#step.conds + 1] = c else rec.cond = Conditions.All(rec.cond, c) end
			elseif cmd == "tip" then
				table.insert(rec.tips, Colour(params))
				any = true
			elseif cmd == "goto" or cmd == "at" then
				rec.point = Point(params, ctx) or rec.point
			elseif cmd == "q" or cmd == "quest" then
				local q, o = params:match("^(%d+)/?(%d*)")
				rec.quest, rec.objective = tonumber(q), tonumber(o)
			elseif cmd == "future" then rec.future = true
			elseif cmd == "c" then rec.complete = true
			elseif cmd == "n" then rec.nocomplete = true
			elseif cmd == "noway" then rec.noway = true
			elseif cmd == "or" then
				-- "|or", "|or 2" (two of them), "|or 2 name" (a named group), as Zygor reads them
				local count, group = params:match("^(%d+)%s+(.+)$")
				rec.orCount = tonumber(count or params) or 1
				rec.orGroup = group or ("or" .. rec.orCount)
			elseif cmd == "next" then
				local to = params:gsub('^"(.-)"$', "%1")
				if to ~= "" and to ~= "+1" then rec.next = to end
			elseif cmd == "override" then rec.override = true
			elseif cmd == "multiq" then
				rec.quests = {}
				for q in params:gmatch("%d+") do table.insert(rec.quests, tonumber(q)) end
			elseif DROP[cmd] then
				Warn(ctx, ("a line with |%s (a Zygor-window script) is left out"):format(cmd))
				return nil, true
			elseif (cmd == "complete" or cmd == "condition") and params:find("ZGV", 1, true) then
				Warn(ctx, "a line with |complete ZGV... (a Zygor-window script) is left out")
				return nil, true
			elseif ACTIONS[cmd] then
				if not rec.action then rec.action, rec.params = cmd, params end
				any = true
			elseif IGNORE[cmd] then
				-- nothing to do here
			elseif cmd == "'" then
				if params ~= "" then rec.text = Colour(params) end
				any = true
			elseif cmd:find("^%l+$") and (n > 1 or OTHER[cmd]) then
				Warn(ctx, ("unknown command |%s"):format(cmd))
			else
				-- plain text, possibly with [Zone x,y] coordinates in it
				local text = chunk:gsub("%[(.-)%]", function(inner)
					local p = Point(inner, ctx)
					if not p then return nil end
					rec.point = rec.point or p
					return ""
				end)
				text = Colour(text)
				if text ~= "" and not rec.text then rec.text = text end
				any = true
			end
		end
	end
	-- (a line with only "|next" is a jump of the step's)
	return (any or rec.next) and rec or nil
end

---@class AnyGuideZygorStep : AnyGuideStep
---@field conds AnyGuideCond[]
---@field sticky string[]       the labels of the side boxes (sticky steps) open when the step began
---@field hasCompletable boolean
---@field nexts? {label: string, goal?: AnyGuideGoal, cond?: AnyGuideCond}[]   its |next jumps, by label until Assemble

--- What `|q N` (without an objective) means on a line that isn't a quest objective: shown while the quest is in the
--- log, or (with |future) until it is turned in. Once hidden, a step without other open lines is passed over.
---@param rec AnyGuideZygorLine
local function QuestGate(rec)
	if rec.quests then
		-- |multiq: the same, for all of them
		local list = { rec.future and "and" or "or" }
		for _, q in ipairs(rec.quests) do table.insert(list, rec.future and { "done", q } or { "onquest", q }) end
		return rec.future and { "not", list } or list
	end
	if not rec.quest or rec.objective then return nil end
	if rec.future then return { "not", { "done", rec.quest } } end
	return { "onquest", rec.quest }
end

local COMPLETABLE = { accept = true, turnin = true, objective = true, kill = true, collect = true, equip = true,
	cast = true, learn = true, level = true, home = true, hearth = true, ["goto"] = true, confirm = true }

--- A line -> a goal (nil when there's nothing to show).
---@param rec AnyGuideZygorLine
---@param step AnyGuideZygorStep
---@param ctx AnyGuideZygorCtx
---@return AnyGuideGoal?
local function MakeGoal(rec, step, ctx)
	local a, p = rec.action, rec.params or ""
	local name, id, count, all, list = Thing(p)
	local goal ---@type AnyGuideGoal?
	local text = rec.text
	-- lines done while a condition holds (Zygor checks them itself): the condition, when it can be read
	local done ---@type AnyGuideCond?
	if a == "havebuff" or a == "nobuff" then
		-- "Name##spell", or a bare number: a spell id or (as in "|nobuff 136230") an aura's icon
		local n = id or tonumber(name)
		local icon = tonumber(name:match("^texture:(%d+)$") or "")
		local c = (id and { "aura", id, count }) or (n and { "or", { "aura", n }, { "auraicon", n } })
			or (icon and { "auraicon", icon })
		if c then done = a == "havebuff" and c or { "not", c } end
	elseif (a == "unequipped" or a == "unequip") and id then
		done = { "not", { "equipped", id } }
	elseif a == "complete" or a == "condition" then
		local c, partial = Expr(p)
		if not partial then done = c or TRUE end
	end
	if a == "talk" then
		goal = { kind = "talk", id = id, text = text or ("Talk to " .. Named(name, "FRIENDLY")), target = { name = name, id = id },
			targets = Targets(list) }
	elseif a == "accept" or a == "turnin" then
		-- quest titles may have commas ("Me Brother, Nipsy##6662"): one quest per line
		local title, qid = p:match("^(.-)##?(%d+)")
		name, id = title or name, tonumber(qid)
		if not id then Warn(ctx, ("%s without a quest id is left out: %s"):format(a, p)) return nil end
		goal = { kind = a, quest = id, text = text or ((a == "accept" and "Accept " or "Turn in ") .. name) }
	elseif a == "kill" then
		local t = { name = name, id = id, enemy = true }
		local label = text or ("Kill " .. (count and (count .. " ") or "") .. Named(all, "ENEMY"))
		if rec.quest and rec.objective then
			goal = { kind = "kill", quest = rec.quest, objective = rec.objective, count = count, id = id, mobName = name,
				text = text or ("Kill " .. Named(all, "ENEMY")), target = t }
		else
			-- without a quest objective nothing tells when it's done: a line that only targets
			goal = { kind = "text", id = id, mobName = name, text = label, target = t }
		end
		goal.targets = Targets(list, true)
	elseif a == "collect" or a == "get" or a == "buy" then
		local verb = a == "buy" and "Buy " or "Collect "
		goal = { kind = "collect", id = id, count = count or 1, text = text or (verb .. Named(name, "LOOT")) }
		if rec.quest and rec.objective then goal.quest, goal.objective = rec.quest, rec.objective
		elseif not id then goal.kind = "confirm" end
	elseif a == "use" then
		goal = { kind = id == HEARTHSTONE and "hearth" or "use", id = id, text = text or ("Use " .. Named(name, "LOOT")) }
		if id == HEARTHSTONE and not text then goal.text = "Use your Hearthstone" end
	elseif a == "goal" then
		-- a quest objective by name ("goal 5 Things Done |q 123/1")
		goal = { kind = "text", text = text or name }
	elseif a == "cast" then
		goal = { kind = id and "cast" or "confirm", id = id, text = text or ("Cast " .. name) }
	elseif a == "hearth" then
		goal = { kind = "hearth", id = HEARTHSTONE, text = text or ("Hearth to " .. p) }
	elseif a == "click" or a == "clicknpc" then
		goal = { kind = "text", text = text or ("Click " .. Named(all, a == "click" and "PICK" or "FRIENDLY")) }
		if a == "clicknpc" then goal.target, goal.targets = { name = name, id = id }, Targets(list) end
	elseif a == "ding" or a == "level" then
		local lvl, xp = p:match("^(%d+),?(%d*)")
		if not lvl then return nil end
		goal = { kind = "level", level = tonumber(lvl), xp = tonumber(xp), text = text or ("Reach level " .. lvl) }
	elseif a == "home" then
		-- the engine compares the place after "to" with the game's bind location
		goal = { kind = "home", text = "Set your Hearthstone to " .. p }
	elseif a == "fpath" then
		goal = { kind = "confirm", text = text or ("Get the " .. name .. " flight path") }
	elseif a == "fly" then
		goal = { kind = "confirm", text = text or ("Fly to " .. p) }
	elseif a == "equip" or a == "equipped" then
		-- "|n": just a hint to put it on; the line still gives the item's button
		goal = { kind = rec.nocomplete and "use" or (id and "equip" or "confirm"), id = id, text = text or ("Equip " .. Named(name, "LOOT")) }
	elseif a == "learnspell" then
		goal = { kind = id and "learn" or "confirm", id = id, text = text or ("Learn " .. name) }
	elseif a == "trash" or a == "bank" then
		-- done once the item is gone from the bags: the line shows only while you have it
		goal = { kind = "confirm", text = text or ((a == "trash" and "Destroy " or "Put in the bank: ") .. Named(name, "LOOT")) }
		if id then goal.cond = { "items>=", id, 1 } end
	elseif a == "vendor" or a == "trainer" or a == "stablemaster" then
		local verbs = { vendor = "Sell items to ", trainer = "Train at ", stablemaster = "Visit " }
		goal = { kind = "confirm", text = text or (verbs[a] .. Named(name, "FRIENDLY")), target = { name = name, id = id } }
	elseif done then
		-- "Enter the cave |complete subzone(...)", "|havebuff ...", "|unequipped ...": done once the condition holds
		-- (and can still be ticked off by hand). A line without text counts only as one of several (|or) or to jump.
		local verbs = { havebuff = "Get the buff ", nobuff = "Get rid of the buff ", unequipped = "Take off ", unequip = "Take off " }
		if not text and verbs[a] then text = verbs[a] .. Named(name, "LOOT") end
		if not text and (rec.orGroup or rec.next) then text = "Continue" end
		if not text then return nil end
		goal = { kind = "confirm", text = text, done = done }
	elseif a then
		-- confirm, gossip, complete <lua> we can't read and the rest: ticked off by the player
		if not text then return nil end
		if a == "complete" or a == "condition" then Warn(ctx, ('|%s "%s" is ticked off by hand'):format(a, p))
		elseif a ~= "confirm" and a ~= "gossip" then Warn(ctx, ("|%s is ticked off by hand"):format(a)) end
		goal = { kind = "confirm", text = text }
	elseif text then
		goal = { kind = "text", text = text }
	end
	if not goal then return nil end

	-- a quest objective on a line that isn't a kill or collect: the line counts it
	if rec.quest and rec.objective and goal.kind ~= "kill" and goal.kind ~= "collect"
		and goal.kind ~= "accept" and goal.kind ~= "turnin" then
		goal.kind, goal.quest, goal.objective = "objective", rec.quest, rec.objective
	end
	-- "Hearth to X |goto ... |c": a text line with a waypoint that is reached by arriving, whatever else the step has
	if rec.complete and rec.point and goal.kind == "text" and not goal.target then goal.kind, goal.point = "goto", rec.point end
	if goal.kind ~= "accept" and goal.kind ~= "turnin" then goal.cond = Conditions.All(goal.cond, QuestGate(rec)) end
	if rec.nocomplete and COMPLETABLE[goal.kind] and goal.kind ~= "objective" then goal.kind = "text" end
	goal.cond = Conditions.All(goal.cond, rec.cond)
	goal.orGroup, goal.orCount = rec.orGroup, rec.orCount
	-- a ticked confirm line (or one with |override) finishes its step, as in Zygor: how its menus of choices work
	if (a == "confirm" or rec.override) and COMPLETABLE[goal.kind] then goal.finishes = true end
	-- the line's own |goto: hovering the line offers it as a waypoint, as in Zygor
	goal.point = goal.point or rec.point
	return goal
end

--- One step's lines -> a step.
---@param lines string[]
---@param sticky string[]
---@param ctx AnyGuideZygorCtx
---@return AnyGuideZygorStep
local function ParseStep(lines, sticky, ctx)
	---@type AnyGuideZygorStep
	local step = { index = 0, goals = {}, side = {}, tips = {}, path = {}, conds = {}, sticky = sticky, hasCompletable = false,
		nexts = {} }
	local last ---@type AnyGuideGoal?
	local points = {} ---@type {p: AnyGuidePoint, goal?: AnyGuideGoal, cond?: AnyGuideCond}[]
	local talk ---@type table?   the NPC of the last talk line, which accept and turn-in lines target
	local skipTips = false
	for _, raw in ipairs(lines) do
		local first = raw:match("^(%S+)")
		if first == "path" then
			-- "path follow strict; loop on; ..." and "path 45.2,42.4  46.0,43.1 ...": map points along the way
			local body = raw:gsub("^path%s*", ""):gsub("^%+%s*", ""):gsub("%s*[\t;]+%s*", ";"):gsub("  +", ";") .. ";"
			for coord in body:gmatch("(.-);") do
				local p = coord:find("%d,%s*%d") and Point(coord, ctx)
				if p then table.insert(step.path, p) end
			end
		else
			local rec, dropped = ReadLine(raw, step, ctx)
			-- the notes under a line that was left out go with it
			if dropped then skipTips = true end
			if rec then
				local goal = MakeGoal(rec, step, ctx)
				if goal then
					skipTips = false
					if goal.kind == "talk" then talk = goal.target end
					if (goal.kind == "accept" or goal.kind == "turnin" or goal.kind == "confirm") and talk and not goal.target then
						goal.target = talk
					end
					table.insert(step.goals, goal)
					last = goal
					if COMPLETABLE[goal.kind] then step.hasCompletable = true end
				end
				-- a jump goes with its line; one on a line of its own holds while that line's condition does
				if rec.next and (goal or not rec.action) then
					table.insert(step.nexts, { label = rec.next, goal = goal, cond = not goal and rec.cond or nil })
				elseif rec.next then
					Warn(ctx, "|next on a line that is left out is not followed")
				end
				if rec.point and not rec.noway then
					table.insert(points, { p = rec.point, goal = goal, cond = rec.cond })
				end
				-- a tip with a condition of its own is a line, as RestedXP's reader does it; others follow their line
				for _, tip in ipairs(rec.tips) do
					if tip ~= "" and not skipTips then
						if not goal and rec.cond then
							local g = { kind = "text", text = tip, cond = rec.cond }
							table.insert(step.goals, g)
							last = g
						else
							table.insert(step.tips, { text = tip, after = goal or last })
						end
					end
				end
			end
		end
	end

	-- who the action key targets: the step's NPC, else the first thing it kills
	for _, g in ipairs(step.goals) do
		if g.kind == "talk" then step.target = g.target break end
	end
	if not step.target then
		for _, g in ipairs(step.goals) do
			if g.mobName and g.target then step.target = g.target break end
		end
	end
	for _, g in ipairs(step.goals) do
		if not g.target and (g.kind == "objective" or g.kind == "collect") and step.target then g.target = step.target end
	end

	-- destination: the last waypoint; the others (and path lines) are points along the way
	local dest = points[#points]
	-- (several lines at one NPC repeat its waypoint: each place counts once)
	local function same(a, b) return a.map == b.map and math.abs(a.x - b.x) < 1e-4 and math.abs(a.y - b.y) < 1e-4 end
	local before = {}
	for i = 1, #points - 1 do
		local p = points[i].p
		if not same(p, dest.p) and not (before[#before] and same(before[#before], p)) then table.insert(before, p) end
	end
	for i = #before, 1, -1 do table.insert(step.path, 1, before[i]) end
	if not dest and step.path[1] then dest = { p = table.remove(step.path, 1) } end
	if dest then
		step.dest = dest.p
		if not step.hasCompletable then
			-- a step that is only travel ("Enter the cave"): arriving completes it; its own text line becomes the goal
			local g = dest.goal
			if g and g.kind == "text" and not g.target then
				g.kind, g.point = "goto", dest.p
			else
				g = { kind = "goto", point = dest.p, text = "Go to the marked spot", cond = dest.cond }
				table.insert(step.goals, g)
			end
			step.hasCompletable = true
		end
	end
	if not step.hasCompletable and #step.goals > 0 then
		table.insert(step.goals, { kind = "confirm", text = "Continue when ready" })
	end
	step.cond = Conditions.All(unpack(step.conds))
	return step
end

--- What a step works on, as keys (as the RestedXP reader has it), so a side box isn't shown with its own step.
local function ObjectivesOf(step)
	local keys = {}
	for _, g in ipairs(step.goals) do
		if g.quest and (g.kind == "objective" or g.kind == "kill" or (g.kind == "collect" and g.objective)) then
			keys[g.quest .. "/" .. (g.objective or 1)] = true
		end
	end
	return keys
end

--- Sticky steps go into the steps they accompany, as side boxes: each step gets the goals of the steps labelled with
--- the stickies open when it began (Zygor shows the sticky step's lines alongside). The sticky step itself stays a
--- step of its own, as in Zygor.
---@param steps AnyGuideZygorStep[]
---@return AnyGuideStep[]
local function Assemble(steps)
	local byLabel = {} ---@type table<string, AnyGuideZygorStep>
	for _, s in ipairs(steps) do if s.label and not byLabel[s.label] then byLabel[s.label] = s end end
	local copies = {} ---@type table<AnyGuideZygorStep, AnyGuideGoal[]>
	local function Copies(s)
		if copies[s] then return copies[s] end
		local list = {}
		for _, g in ipairs(s.goals) do
			if g.kind ~= "goto" and g.text ~= "Continue when ready" then
				local copy = setmetatable({}, { __index = g })
				copy.cond = Conditions.All(s.cond, g.cond)
				table.insert(list, copy)
			end
		end
		copies[s] = list
		return list
	end
	for _, s in ipairs(steps) do
		local own = ObjectivesOf(s)
		for _, label in ipairs(s.sticky) do
			local box = byLabel[label]
			if box and box ~= s and box.label ~= s.label then
				local keys = ObjectivesOf(box)
				local shares = false
				for k in pairs(keys) do if own[k] then shares = true end end
				if not shares then for _, g in ipairs(Copies(box)) do table.insert(s.side, g) end end
			end
		end
	end
	for i, s in ipairs(steps) do s.index = i end
	return steps
end

--- "Leveling Guides\\Westfall (13-15)" -> the guide's id here: faction and Zygor title, so Alliance and Horde guides
--- with the same title stay apart.
local function NameOf(title, header)
	return (header.faction and (header.faction .. ":") or "") .. title
end

---@param text string
---@param source string
---@param meta table
---@param ctx AnyGuideZygorCtx
---@return AnyGuideGuide?, string?
local function ParseGuide(text, source, meta, ctx)
	local header = type(meta.header) == "table" and meta.header or {}
	local full = type(meta.title) == "string" and meta.title or "Zygor guide"
	-- guides Zygor itself never lists: the startup wizard, Season of Discovery guides
	if header.visible then
		local c = Expr(header.visible)
		if c == FALSE then return nil, ("'%s' is not a guide to follow (Zygor hides it); left out"):format(full) end
	end
	local hide ---@type AnyGuideCond?
	if header.hideif then
		local partial
		hide, partial = Expr(header.hideif)
		if hide == nil and not partial then return nil, ("'%s' is hidden in Zygor (hideif %s); left out"):format(full, header.hideif) end
		if partial then hide = nil end
	end

	text = text:gsub("\r", ""):gsub("||", "\n")
	local raw = {} ---@type {lines: string[], sticky: string[]}[]
	local cur
	local open = {} ---@type string[]
	local function Close(label)
		for i = #open, 1, -1 do if open[i] == label then table.remove(open, i) end end
	end
	for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
		local l = rawLine:gsub("%s*%-%-.*", "", 1):gsub("%s*//.*", "", 1)
		l = l:gsub("^%.*%s*", ""):gsub("^%*%s*", ""):gsub("^|%s*", ""):gsub("%s+$", "")
		local cmd, params = l:match("^(%S*)%s*(.-)$")
		local label = params and params:gsub('^%s*"(.-)"%s*$', "%1")
		if l == "" then
			-- blank or a comment
		elseif cmd == "step" then
			-- "step" right after "step" is one step, as in Zygor
			if not (cur and #cur.lines == 0) then
				cur = { lines = {} }
				table.insert(raw, cur)
			end
			cur.sticky = {}
			for _, s in ipairs(open) do table.insert(cur.sticky, s) end
		elseif cmd == "stickystart" then
			Close(label)
			table.insert(open, label)
		elseif cmd == "stickystop" then
			Close(label)
		elseif cur then
			-- the step labelled after an open sticky closes it (it is that sticky's own step)
			if cmd == "label" then Close(label) end
			table.insert(cur.lines, l)
		end
	end

	-- steps with nothing to show are left out (a step with only jumps stays); their labels go to the next step
	local steps = {}
	local labels, pending = {}, {} ---@type table<string, integer[]>, string[]
	for _, r in ipairs(raw) do
		local s = ParseStep(r.lines, r.sticky, ctx)
		if s.label then table.insert(pending, s.label) end
		if #s.goals > 0 or #s.nexts > 0 then
			table.insert(steps, s)
			for _, l in ipairs(pending) do
				labels[l] = labels[l] or {}
				table.insert(labels[l], #steps)
			end
			pending = {}
		end
	end
	if #steps == 0 then return nil, ("'%s' has no steps"):format(full) end
	Assemble(steps)

	-- |next "label": the step with that label nearest this one ("+label" / "-label": the next / previous one), as
	-- Zygor finds it
	for i, s in ipairs(steps) do
		for _, n in ipairs(s.nexts) do
			local sign, label = n.label:match("^([+-]?)(.*)$")
			local back, fore
			for _, at in ipairs(labels[label] or {}) do
				if at < i then back = at elseif at > i and not fore then fore = at end
			end
			local to
			if sign == "+" then to = fore elseif sign == "-" then to = back
			elseif not fore or (back and i - back < fore - i) then to = back else to = fore end
			if to then
				s.jumps = s.jumps or {}
				table.insert(s.jumps, { to = to, goal = n.goal, cond = n.cond })
			elseif n.label:find("\\", 1, true) then
				Warn(ctx, ('|next to another guide ("%s") is not followed'):format(n.label))
			else
				Warn(ctx, ('|next "%s": no step with that label; not followed'):format(n.label))
			end
		end
		s.nexts = nil
	end

	local path, title = full:match("^(.*)\\([^\\]+)$")
	title = title or full
	local group = "Zygor" .. (header.trial and " (trial)" or "") .. (path and (": " .. path) or "")
	local cond = header.faction and { "faction", header.faction } or nil ---@type AnyGuideCond?
	if header.visible then
		local c, partial = Expr(header.visible)
		if partial then Warn(ctx, ('can\'t read who the guide is for: "%s"'):format(header.visible)) end
		cond = Conditions.All(cond, c)
	end
	if hide then cond = Conditions.All(cond, { "not", hide }) end
	return {
		title = title .. (header.trial and " (trial)" or ""),
		name = NameOf(full, header) .. (header.trial and ":trial" or ""),
		group = group,
		next = type(header.next) == "string" and NameOf(header.next, header) or nil,
		cond = cond,
		format = "zygor",
		source = source,
		steps = steps,
	}
end

--- One guide's text, with its title and header in `meta` (see the top of this file).
function Zygor.Parse(text, source, meta)
	local ctx = { counts = {}, order = {} } ---@type AnyGuideZygorCtx
	local g, why = ParseGuide(text, source, type(meta) == "table" and meta or {}, ctx)
	local warnings = {}
	if why then table.insert(warnings, why) end
	local title = g and g.title or "?"
	for _, msg in ipairs(ctx.order) do
		local n = ctx.counts[msg]
		table.insert(warnings, ("%s: %s%s"):format(title, msg, n > 1 and (" (x" .. n .. ")") or ""))
	end
	return { g }, warnings
end
