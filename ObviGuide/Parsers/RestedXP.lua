-- Parser for RestedXP guide syntax (the format of RXPGuides guide files): text in, neutral guides out.
-- ObviGuide reads only text handed to ObviGuide.Add; it never looks at the RestedXP addon itself.
--
-- The format, as far as ObviGuide uses it:
--   #name / #displayname / #group / #next lines (each may end in "<< condition")
--   step [<< condition]       a step; the condition: '/' separates alternatives, words in one must all hold, '!' negates
--     #label X                 a name other steps refer to
--     #completewith X          a side box: shown alongside the following steps until step X (or just the next)
--     #hidewindow              a helper step with nothing to show
--     .directive args >>text   a goal or a condition; "<< cond" and " --comment" may follow
--     >>text                   a description line; *text a tip; +text a line the player ticks off
local _, ns = ...
---@cast ns ObviGuideNS

local Conditions = ns.Conditions
local HEARTHSTONE = 6948   -- item id

---@class ObviGuideParser
local RXP = {}
ns.Parsers.rxp = RXP

-- RestedXP's colour tags (|cRXP_ENEMY_ ...), mapped to the colours all formats share
local COLORS = ns.Colors

---@param s string?
---@return string
local function Clean(s)
	if not s then return "" end
	s = s:gsub("|cRXP_(%u+)_", function(tag) return "|c" .. (COLORS[tag] or "ffffffff") end)
	s = s:gsub("::%d+", "")                     -- Name::npcid
	s = s:gsub("|T([^|]-)|t", function(spec)    -- keep icons, but small and inline
		local path = spec:match("^([^:]+)")
		return path and ("|T" .. path .. ":0|t") or ""   -- text height; the window places it
	end)
	return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Plain text for names: no colours, icons or brackets.
---@param s string?
---@return string
local function Plain(s)
	s = Clean(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("[%[%]]", "")
	return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local RACES = Conditions.RACES

--- An RXP condition string ("Alliance Hunter/Horde !Druid") as a condition tree.
---@param s string?
---@return ObviGuideCond?
local function Cond(s)
	if not s then return nil end
	s = s:gsub("%-%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then return nil end
	if s:find("^skip") then return { "false" } end
	local alts = { "or" }
	for alt in (s .. "/"):gmatch("([^/]*)/") do
		local terms = { "and" }
		for word in alt:gmatch("%S+") do
			local neg = word:sub(1, 1) == "!"
			local w = neg and word:sub(2) or word
			local lw = w:lower()
			local test
			if lw == "alliance" or lw == "horde" then test = { "faction", lw == "alliance" and "Alliance" or "Horde" }
			elseif Conditions.ClassToken(w) then test = { "class", Conditions.ClassToken(w) }
			elseif RACES[lw] then test = { "race", lw == "undead" and "scourge" or lw }
			end
			if test then table.insert(terms, neg and { "not", test } or test) end
		end
		if #terms == 1 then return nil end  -- an alternative that always holds
		table.insert(alts, #terms == 2 and terms[2] or terms)
	end
	return #alts == 2 and alts[2] or alts
end

---@param s string
---@return integer[]
local function Ids(s)
	local ids = {}
	for n in (s or ""):gmatch("%-?%d+") do table.insert(ids, math.abs(tonumber(n) or 0)) end
	return ids
end

--- "map,x,y[,radius[,flag]]" -> point (or nil), flag. "map/continent,worldY,worldX" is in world yards.
---@return ObviGuidePoint?, string?
local function Point(arg)
	local f = {}
	for part in (arg .. ","):gmatch("([^,]*),") do table.insert(f, (part:gsub("^%s+", ""):gsub("%s+$", ""))) end
	if #f < 3 then return nil end
	local mapText, a, b = f[1], tonumber(f[2]), tonumber(f[3])
	if not (a and b) then return nil end
	local radius, flag = tonumber(f[4]), f[5]
	local map, continent = mapText:match("^(%d+)/(%d+)$")
	if map then
		-- world position (RXP order: west, north) -> map position on that uiMapID
		local mapID, contID = tonumber(map) --[[@as integer]], tonumber(continent) --[[@as integer]]
		local _, pos = C_Map.GetMapPosFromWorldPos(contID, CreateVector2D(b, a), mapID)
		if not pos then return nil end
		return { map = mapID, x = pos.x, y = pos.y, radius = radius }, flag
	end
	local mapID = tonumber(mapText)
	if not mapID then return nil end  -- zone names are not supported yet
	return { map = mapID, x = a / 100, y = b / 100, radius = radius }, flag
end

---@class ObviGuideRXPStep : ObviGuideStep
---@field sideOf? string          for a side box: the label of the step it ends with ("next" for the next step)
---@field hidden? boolean
---@field mobs table<string, integer>
---@field talk? {name: string, id: integer}
---@field hasCompletable boolean
---@field condText string

--- {kind, id} for any of the ids ({"not", {kind, id}} each, when negated).
---@param kind string
---@param ids integer[]
---@param negate? boolean
---@return ObviGuideCond
local function AnyId(kind, ids, negate)
	local any = { "or" }
	for _, id in ipairs(ids) do table.insert(any, negate and { "not", { kind, id } } or { kind, id }) end
	return any
end

--- A goal folded into another or replaced: the notes that followed it now follow the new one.
---@param step ObviGuideStep
---@param from ObviGuideGoal
---@param to ObviGuideGoal
local function Moved(step, from, to)
	for _, tip in ipairs(step.tips) do if tip.after == from then tip.after = to end end
end

--- One step's lines -> a step.
---@param header string   the "step << cond" line
---@param lines string[]
---@return ObviGuideRXPStep
local function ParseStep(header, lines)
	local condText = header:match("^step%s*<<%s*(.-)%s*$") or ""
	---@type ObviGuideRXPStep
	local step = { index = 0, goals = {}, side = {}, tips = {}, path = {}, mobs = {}, hasCompletable = false, condText = condText }
	local conds = { Cond(condText) }
	-- the line a note follows: the last goal, or a .goto line (its goal only exists once the step is read, see below)
	local last ---@type ObviGuideGoal?
	local function addGoal(goal, completable)
		table.insert(step.goals, goal)
		last = goal
		if completable then step.hasCompletable = true end
	end
	local equipText = false
	local points = {}
	local skips = {}

	for _, raw in ipairs(lines) do
		local l = raw:gsub("^%s+", ""):gsub("%s+$", "")
		if l == "" or l:find("^%-%-") then
			-- blank or commented out
		elseif l:sub(1, 1) == "#" then
			local tag, val = l:match("^#(%S+)%s*(.*)$")
			if tag == "hidewindow" then step.hidden = true
			elseif tag == "completewith" then step.sideOf = val
			elseif tag == "label" then step.label = val
			end
		else
			-- split off " --comment", "<< cond" and ">>text"
			local body, comment, lcond, text = l, nil, nil, nil
			if l:sub(1, 1) ~= "+" then
				local b, c = body:match("^(.-)%s%-%-(.*)$")
				if b then body, comment = b, c:gsub("^%s+", "") end
			end
			local b2, lc = body:match("^(.-)%s<<%s*(.*)$")
			if b2 then body, lcond = b2, lc end
			local b3, t = body:match("^(.-)>>(.*)$")
			if b3 then body, text = b3, t end
			body = body:gsub("%s+$", "")
			local lineCond = Cond(lcond)
			local cleanText = text and Clean(text)

			if body == "" and cleanText then
				if cleanText:lower():find("equip") then equipText = true end
				addGoal({ kind = "text", text = cleanText, cond = lineCond })
			elseif body:sub(1, 1) == "*" then
				local tip = Clean(body:sub(2))
				if tip ~= "" then
					if lineCond then addGoal({ kind = "text", text = tip, cond = lineCond })
					else table.insert(step.tips, { text = tip, after = last }) end
				end
			elseif body:sub(1, 1) == "+" then
				local t2 = Clean(body:sub(2))
				local item = l:match("^%+.-Equip the.-%[") and true
				if item then equipText = true end
				addGoal({ kind = "confirm", text = t2, cond = lineCond }, true)
			elseif body:sub(1, 1) == "." then
				local dir, arg = body:match("^%.(%S+)%s*(.*)$")
				arg = arg or ""
				local ids = Ids(arg)
				local name = text and Plain(text) or (comment and Plain(comment)) or ""
				if dir == "goto" then
					local p, flag = Point(arg:gsub("%-%-.*$", ""))
					if p then
						local pt = { p = p, flag = flag, text = cleanText, cond = lineCond, prev = last }
						table.insert(points, pt)
						last = pt --[[@as ObviGuideGoal]]   -- a stand-in for notes, swapped for the goal below
					end
				elseif dir == "target" then
					local n, id = arg:match("^(.-)::(%d+)")
					if n and not step.talk then step.talk = { name = Plain(n), id = tonumber(id) --[[@as integer]] } end
				elseif dir == "mob" then
					for part in (arg .. ","):gmatch("([^,]*),") do
						local n, id = part:match("^%s*%+?(.-)::(%d+)")
						if n then step.mobs[Plain(n)] = tonumber(id) end
					end
				elseif dir == "accept" then
					addGoal({ kind = "accept", quest = ids[1], text = cleanText or ("Accept quest " .. ids[1]), cond = lineCond }, true)
				elseif dir == "turnin" then
					addGoal({ kind = "turnin", quest = ids[1], text = cleanText or ("Turn in quest " .. ids[1]), cond = lineCond }, true)
				elseif dir == "complete" then
					local d = comment and comment:gsub("^|", "") or cleanText or ""
					local need, what = d:match("^%d+/(%d+)%s+(.+)$")
					local mob = what and what:match("^(.-)%s+slain$")
					local g = { kind = mob and "kill" or "objective", quest = ids[1], objective = ids[2] or 1,
						count = tonumber(need), text = mob and ("Kill " .. mob) or (what or d), cond = lineCond }
					g.mobName = mob
					addGoal(g, true)
				elseif dir == "collect" then
					-- the name, without a "|1/1 " count marker (RestedXP's "--|1/1 Shiny Bauble" comments) or "(3)"
					local n = name ~= "" and name:gsub("^|?%d+/%d+%s*", ""):gsub("%s*%(%d+%)%s*$", ""):gsub("^.-%f[%w]an?%s+", "") or "item"
					addGoal({ kind = "collect", id = ids[1], count = ids[2] or 1, quest = ids[3], objective = ids[4],
						text = n, cond = lineCond }, true)
				elseif dir == "use" then
					addGoal({ kind = "use", id = ids[1], text = cleanText or ("Use " .. (comment and Plain(comment) or "item")), cond = lineCond })
				elseif dir == "cast" or dir == "usespell" then
					if cleanText then addGoal({ kind = "cast", id = ids[1], text = cleanText, cond = lineCond }, true) end
				elseif dir == "train" then
					if arg:find(",") then table.insert(conds, { "not", { "knows", ids[1] } })
					else addGoal({ kind = "learn", id = ids[1], text = cleanText or "Train a spell", cond = lineCond }, true) end
				elseif dir == "xp" then
					local lt, gt = arg:match("^<%s*(%d+)"), arg:match("^>%s*(%d+)")
					if lt then table.insert(conds, { "level<", tonumber(lt) })
					elseif gt then table.insert(conds, { "level>", tonumber(gt) })
					else
						local lvl, xp = arg:match("^(%d+)%+?(%d*)")
						if lvl then addGoal({ kind = "level", level = tonumber(lvl), xp = tonumber(xp),
							text = cleanText or ("Reach level " .. lvl), cond = lineCond }, true) end
					end
				elseif dir == "home" then
					addGoal({ kind = "home", text = cleanText or "Set your Hearthstone", cond = lineCond }, true)
				-- quest checks as RestedXP's functions.lua has them: with several ids, any one will do
				elseif dir == "isOnQuest" then table.insert(conds, AnyId("onquest", ids))
				elseif dir == "isNotOnQuest" then table.insert(conds, { "not", AnyId("onquest", ids) })
				elseif dir == "isQuestComplete" then table.insert(conds, { "ready", ids[1] })
				elseif dir == "isQuestTurnedIn" then table.insert(conds, AnyId("done", ids))
				-- "not complete" is not "on the quest and not done yet": it also holds without the quest
				elseif dir == "isQuestNotComplete" then table.insert(conds, { "not", { "ready", ids[1] } })
				-- "available" only means "not turned in yet"; having the quest doesn't hide the step
				elseif dir == "isQuestAvailable" then table.insert(conds, AnyId("done", ids, true))
				elseif dir == "itemcount" then
					local id, n = arg:match("^(%d+),%s*(<?%s*%d+)")
					if id then
						local lt = n:match("^<%s*(%d+)")
						table.insert(conds, lt and { "items<", tonumber(id), tonumber(lt) } or { "items>=", tonumber(id), tonumber(n) })
					end
				elseif dir == "subzoneskip" or dir == "zoneskip" then
					-- the step counts as done while the player is in that (sub)zone; flag 1 reverses it ("not in"),
					-- flag 2 limits it to places without a map (dungeons)
					local where, flags = arg:match("^([^,]+),?%s*(%d*)")
					flags = tonumber(flags) or 0
					local test
					if dir == "subzoneskip" then
						test = { "area", tonumber(where) or 0 }
					else
						test = { "map" }
						for id in (where or ""):gmatch("[^%+/]+") do table.insert(test, tonumber(id)) end
					end
					if flags % 2 == 1 then test = { "not", test } end
					if math.floor(flags / 2) % 2 == 1 then test = { "and", test, { "nomap" } } end
					skips[#skips + 1] = test
				elseif dir == "hs" then
					-- the Hearthstone: its icon, and the line (and action key) uses it; done once it is cast
					addGoal({ kind = "hearth", id = HEARTHSTONE, text = cleanText or "Use your Hearthstone", cond = lineCond }, true)
				elseif dir == "fly" or dir == "fp" or dir == "vendor" or dir == "trainer" or dir == "zone"
					or dir == "subzone" or dir == "deathskip" or dir == "abandon" or dir == "link" then
					-- (".fp Name": done once the game lists that flight point as discovered, see Engine)
					local flight = dir == "fp" and arg:gsub("%s*%-%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", "") or nil
					if flight == "" then flight = nil end
					if cleanText then addGoal({ kind = "confirm", text = cleanText, cond = lineCond, flight = flight }, true) end
				end
				-- everything else (gossip skips, macros, money, cooldowns, auras, zone skips...) is RestedXP-only
			end
		end
	end

	-- equipping: "buy and equip a X" + collect, or "+Equip the X" + use -> one 'equip' goal the game can check
	if equipText then
		-- each "+Equip the X" takes the .use line for that same item: a step can have one per class
		-- ("Equip the Honed Greathammer << Paladin" ... ".use 257345 << Paladin -- Honed Greathammer")
		local uses = {} ---@type ObviGuideGoal[]
		for _, g in ipairs(step.goals) do if g.kind == "use" and g.id then table.insert(uses, g) end end
		local folded = {} ---@type table<ObviGuideGoal, boolean>
		local function UseFor(text)
			local plain = Plain(text)
			for _, u in ipairs(uses) do
				local name = Plain(u.text):gsub("^Use%s+", "")
				if name ~= "" and plain:find(name, 1, true) then return u end
			end
			return #uses == 1 and uses[1] or nil
		end
		for _, g in ipairs(step.goals) do
			local u = g.kind == "confirm" and g.text:find("Equip the") and UseFor(g.text)
			if g.kind == "collect" and (g.count or 1) == 1 and not g.quest then
				-- "Collect X" becomes "Equip X", not "Equip Collect X"
				g.kind = "equip"; g.text = "Equip " .. (g.text:gsub("^Collect%s+", ""))
			elseif u then
				g.kind = "equip"; g.id = u.id; folded[u] = true
			end
		end
		local kept = {}
		for _, g in ipairs(step.goals) do if not folded[g] then table.insert(kept, g) end end
		step.goals = kept
	end

	-- kill goals get their npc id from .mob lines
	for _, g in ipairs(step.goals) do
		if g.kind == "kill" and g.mobName then g.id = step.mobs[g.mobName] end
	end

	-- one description line plus one objective or kill: that goal becomes the line (as RestedXP shows it);
	-- it keeps its kind, quest and mob, so progress and targeting still work
	local texts, objs = {}, {}
	for _, g in ipairs(step.goals) do
		if g.kind == "text" and not g.cond then table.insert(texts, g) end
		if g.kind == "objective" or g.kind == "kill" then table.insert(objs, g) end
	end
	if #texts == 1 and #objs == 1 then
		local t, o = texts[1], objs[1]
		-- when the description doesn't name what the objective counts ("Click on the Crates" for "Abandoned
		-- Belongings"), keep that name for the progress: "(7/8 Abandoned Belongings)"
		local own = Plain(o.text):gsub("^Kill%s+", "")
		local stem = (#own > 6 and own:sub(1, -3) or own):lower()
		if own ~= "" and not Plain(t.text):lower():find(stem, 1, true) then o.what = own end
		o.text = t.text
		for i, g in ipairs(step.goals) do if g == t then table.remove(step.goals, i) break end end
		Moved(step, t, o)
	end

	-- talk to the target first, when the step deals with an NPC (and drop RestedXP's own "Talk to X." line then)
	if step.talk then
		for _, g in ipairs(step.goals) do
			if g.kind == "accept" or g.kind == "turnin" or g.kind == "learn" or g.kind == "home" then
				local talk = { kind = "talk", id = step.talk.id, text = "Talk to |cff00ff25" .. step.talk.name .. "|r" }
				-- it takes the place of RestedXP's own "Talk to X." line (first if there is none)
				local pos
				for i = #step.goals, 1, -1 do
					local t = step.goals[i]
					if t.kind == "text" and not t.cond and Plain(t.text):find("^Talk to") then
						table.remove(step.goals, i)
						Moved(step, t, talk)
						pos = i
					end
				end
				-- ... which some steps write as a note ("*Talk to X."): the notes after it follow the talk line
				for ti = #step.tips, 1, -1 do
					local tip = step.tips[ti]
					if Plain(tip.text):find("^Talk to") then
						local anchor = tip.after
						for k = ti + 1, #step.tips do if step.tips[k].after == anchor then step.tips[k].after = talk end end
						table.remove(step.tips, ti)
						if not pos then
							pos = 1
							for k, g2 in ipairs(step.goals) do if g2 == anchor then pos = k + 1 end end
						end
					end
				end
				table.insert(step.goals, pos or 1, talk)
				break
			end
		end
	end

	-- who the action key targets: the step's NPC, else the first thing it kills
	if step.talk then
		step.target = { name = step.talk.name, id = step.talk.id }
	else
		for _, g in ipairs(step.goals) do
			if g.kind == "kill" and g.mobName then step.target = { name = g.mobName, id = g.id, enemy = true } break end
		end
		if not step.target then
			for n, id in pairs(step.mobs) do step.target = { name = n, id = id, enemy = true } break end
		end
	end

	-- each line's own target (clicking it, and the extra action keys): a kill line its mob; an objective naming one
	-- of the step's mobs that mob ("Enchanted Skyhopper Exterminated" -> Skyhopper); else the step's target
	for _, g in ipairs(step.goals) do
		if g.kind == "kill" and g.mobName then
			g.target = { name = g.mobName, id = g.id, enemy = true }
		elseif g.kind == "objective" or g.kind == "collect" then
			local text = Plain(g.text):lower()
			for n, id in pairs(step.mobs) do
				local stem = (#n > 6 and n:sub(1, -3) or n):lower()
				if text:find(stem, 1, true) then g.target = { name = n, id = id, enemy = true } break end
			end
			g.target = g.target or step.target
		elseif (g.kind == "talk" or g.kind == "accept" or g.kind == "turnin") and step.target then
			g.target = step.target
		end
	end

	-- destination: the last .goto that is a real stop (flag 0 marks a path point); the others are path points
	local dest
	for _, pt in ipairs(points) do if pt.flag ~= "0" then dest = pt end end
	for _, pt in ipairs(points) do if pt ~= dest then table.insert(step.path, pt.p) end end
	local gotoGoal
	if dest then
		step.dest = dest.p
		if not step.hasCompletable then
			-- a step that is only travel ("Enter the cave"): arriving completes it
			gotoGoal = { kind = "goto", point = dest.p, text = dest.text or "Go to the marked spot", cond = dest.cond }
			addGoal(gotoGoal, true)
		end
	end
	-- notes that followed a .goto line follow its goal, or (without one) the line before the .goto
	for _, pt in ipairs(points) do Moved(step, pt --[[@as ObviGuideGoal]], gotoGoal or pt.prev) end
	if not step.hasCompletable and not step.sideOf then
		addGoal({ kind = "confirm", text = "Continue when ready" }, true)
	end
	step.cond = Conditions.All(unpack(conds))
	if #skips == 1 then step.skip = skips[1] elseif #skips > 1 then step.skip = { "or", unpack(skips) } end
	return step
end

--- What a step works on, as keys: quest objectives ("quest/objective") and the quests it accepts or turns in
--- ("accept:quest", "turnin:quest"), so a side box that repeats a step's own talk/turn-in isn't shown with it.
local function ObjectivesOf(step)
	local keys = {}
	for _, g in ipairs(step.goals) do
		if g.quest and (g.kind == "objective" or g.kind == "kill" or (g.kind == "collect" and g.objective)) then
			keys[g.quest .. "/" .. (g.objective or 1)] = true
		elseif g.quest and (g.kind == "accept" or g.kind == "turnin") then
			keys[g.kind .. ":" .. g.quest] = true
		end
	end
	return keys
end

local function Shares(a, b)
	for k in pairs(a) do if b[k] then return true end end
	return false
end

--- Side boxes ("#completewith") go into the steps they accompany. RestedXP ends one at its target step, done or
--- not, and so do we. A later box with the same objective and condition that starts while this one is still up (and
--- before a real step on that objective) is the same box, running on to that box's own target.
---@param steps ObviGuideRXPStep[]
---@return ObviGuideStep[]
local function Assemble(steps)
	local function nextReal(from)
		for k = from, #steps do if not steps[k].sideOf then return k end end
	end
	local function targetOf(i)
		local s = steps[i]
		if s.sideOf ~= "next" then
			for k = i + 1, #steps do if steps[k].label == s.sideOf and not steps[k].sideOf then return k end end
		end
		return nextReal(i + 1)
	end
	local ends, absorbed = {}, {}
	for i, s in ipairs(steps) do
		if s.sideOf and not absorbed[i] then
			local mine, e, cur = ObjectivesOf(s), targetOf(i), i
			while next(mine) do
				local j
				for k = cur + 1, #steps do
					local other = steps[k]
					if Shares(ObjectivesOf(other), mine) and not (other.sideOf and other.condText ~= s.condText) then j = k break end
				end
				if not j then break end
				-- only a box that starts while this one is still up is the same box; a later one stands on its own
				if steps[j].sideOf and e and j > e then break end
				if steps[j].sideOf then
					absorbed[j] = true
					local t = targetOf(j)
					if t and (not e or t > e) then e = t end
					cur = j
				else
					-- a real step on the same objective ends the chain; the box still lasts only as long as its
					-- #completewith says, as RestedXP has it
					break
				end
			end
			ends[i] = e or #steps
		end
	end

	local out = {}
	local active = {}
	for i, s in ipairs(steps) do
		if s.sideOf then
			if not absorbed[i] then
				local side = {}
				-- the box's notes come along as text lines, each after the line it follows (side boxes have no notes)
				local placed = {}
				local function NotesAfter(goal)
					for _, tip in ipairs(s.tips) do
						if tip.after == goal and not placed[tip] then
							placed[tip] = true
							table.insert(side, { kind = "text", text = "|cffd0b070" .. tip.text .. "|r", cond = s.cond })
						end
					end
				end
				NotesAfter(nil)
				for _, g in ipairs(s.goals) do
					local copy = setmetatable({}, { __index = g })
					copy.cond = Conditions.All(s.cond, g.cond)
					table.insert(side, copy)
					NotesAfter(g)
				end
				for _, tip in ipairs(s.tips) do
					if not placed[tip] then table.insert(side, { kind = "text", text = "|cffd0b070" .. tip.text .. "|r", cond = s.cond }) end
				end
				if #side > 0 then table.insert(active, { goals = side, last = ends[i], keys = ObjectivesOf(s) }) end
			end
		else
			-- a side box is not shown on a step that works on the same objective itself (that would show it twice)
			local own = ObjectivesOf(s)
			for _, a in ipairs(active) do
				if not Shares(a.keys, own) then for _, g in ipairs(a.goals) do table.insert(s.side, g) end end
			end
			table.insert(out, s)
			s.index = #out
			local still = {}
			for _, a in ipairs(active) do if i < a.last then table.insert(still, a) end end
			active = still
		end
	end
	return out
end

--- The value of a header line for this character: lines may repeat with "<< condition" per faction or class.
local function HeaderValue(lines, key)
	local fallback
	for _, l in ipairs(lines) do
		local v = l:match("^#" .. key .. "%s+(.*)$")
		if v then
			local val, c = v:match("^(.-)%s*<<%s*(.*)$")
			if val then
				if Conditions.Eval(Cond(c)) then return val end
			else
				fallback = fallback or v
			end
		end
	end
	return fallback
end

---@param body string  one guide's text
---@return ObviGuideGuide?, string?
local function ParseGuide(body, source)
	body = body:gsub("\r", "")
	local lines = {}
	for l in (body .. "\n"):gmatch("([^\n]*)\n") do table.insert(lines, l) end
	local header, rxpSteps, cur = {}, {}, nil
	for _, l in ipairs(lines) do
		if l:find("^step") then
			cur = { head = l, lines = {} }
			table.insert(rxpSteps, cur)
		elseif cur then
			table.insert(cur.lines, l)
		else
			table.insert(header, l)
		end
	end
	for _, l in ipairs(header) do if l:find("^#internal") then return nil, "internal list skipped" end end
	local steps = {}
	for _, s in ipairs(rxpSteps) do
		local st = ParseStep(s.head, s.lines)
		if not st.hidden then table.insert(steps, st) end
	end
	local name = HeaderValue(header, "displayname") or HeaderValue(header, "name")
	if not name or #steps == 0 then return nil, "a guide without a name or steps" end
	return {
		title = name,
		name = HeaderValue(header, "name"),
		group = HeaderValue(header, "group") or "RestedXP format",
		next = HeaderValue(header, "next"),
		format = "rxp",
		source = source,
		steps = Assemble(steps),
	}
end

--- Text with one or more guides: RXPGuides.RegisterGuide([[...]]) blocks (a whole guide file), or a single guide.
function RXP.Parse(text, source)
	local guides, warnings = {}, {}
	local bodies = {}
	local pos = 1
	while true do
		local s, e, eq = text:find("RegisterGuide%(%s*%[(=*)%[", pos)
		if not s then break end
		local close = "]" .. eq .. "]"
		local cs = text:find(close, e + 1, true)
		if not cs then break end
		table.insert(bodies, text:sub(e + 1, cs - 1))
		pos = cs + #close
	end
	if #bodies == 0 then bodies = { text } end
	for _, body in ipairs(bodies) do
		local g, why = ParseGuide(body, source)
		if g then table.insert(guides, g) elseif why then table.insert(warnings, why) end
	end
	return guides, warnings
end
