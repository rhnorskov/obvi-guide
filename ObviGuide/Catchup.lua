-- Quest Catchup, after Zygor's Smart Injection System: a quest may need earlier quests you skipped (a chain begun in a
-- guide you didn't follow). QuestieDB knows each quest's pre-quests; the ones not done yet are looked up in the guides,
-- and their steps, cut down to those quests, become a short guide of their own. It opens in a tab beside the guide and
-- leads back to it when done.
-- Started for the quests the guide still has for you (from the current step to the end of the guide, and in the guide
-- after it): "/og catchup" or the gear menu. Or for one quest: clicking a quest the window shows greyed out ("needs
-- Blessed Arm"), or "/og catchup <quest>" with its id, its name or a link to it.
-- The steps come first from the guides leading to this one, then this one's earlier steps, then any other guide for
-- this character that has the quest (only those are read: a guide not read yet is first looked through for the
-- quest's id). Needs QuestieDB (its public library, LibQuestieDB); without it there's nothing to know the pre-quests
-- from.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

---@class ObviGuideCatchup
local Catchup = {}
ns.Catchup = Catchup

local NAME = "obvi-catchup"
-- lines about a quest: kept when it's one of the quests to catch up on
local QUEST_LINES = { accept = true, turnin = true, objective = true, kill = true, collect = true }
-- lines that only describe or help, kept in a step that is kept
local HELP_LINES = { text = true, talk = true, use = true }

---@param q integer
local function Done(q) return C_QuestLog.IsQuestFlaggedCompleted(q) end

---@param g ObviGuideGoal
---@return integer?
local function QuestOf(g)
	if g.quest then return QUEST_LINES[g.kind] and g.quest or nil end
	for _, w in ipairs(g.with or {}) do if w.quest and QUEST_LINES[w.kind] then return w.quest end end
end

--- The guides leading to `g` (each one whose next is the one after it, for this character), earliest first; read,
--- unless `unread` (then as they are: a guide's title and next are known before it's read).
---@param g ObviGuideGuide
---@param unread? boolean
---@return ObviGuideGuide[]
local function Before(g, unread)
	local list, seen, cur = {}, { [g] = true }, g
	while true do
		local prev
		for _, other in ipairs(ns.guides) do
			if not seen[other] and other.next and (other.next == cur.title or other.next == cur.name)
				and ns.Conditions.Eval(other.cond) then
				prev = other
				break
			end
		end
		if not prev then break end
		seen[prev] = true
		local read = unread and prev or ns.Ready(prev)
		if not read then break end
		table.insert(list, 1, read)
		cur = read
	end
	return list
end

--- Whether a guide may have one of these quests: a guide read already, by its lines; one not read yet, by its text
--- (the quest's id as a number of its own in it), so that only those are read.
---@param guide ObviGuideGuide
---@param quests table<integer, boolean>
local function Mentions(guide, quests)
	local p = guide.pending
	if not p then
		for _, s in ipairs(guide.steps or {}) do
			for _, goal in ipairs(s.goals) do local q = QuestOf(goal) if q and quests[q] then return true end end
		end
		return false
	end
	local ok, text = pcall(function() return type(p.text) == "function" and p.text() or p.text end)
	if not ok or type(text) ~= "string" then return false end
	for q in pairs(quests) do if text:find("%f[%d]" .. q .. "%f[%D]") then return true end end
	return false
end

--- The other guides for this character that may have these quests (not `g`, the ones leading to it, nor a catch-up),
--- in the order they were added; read.
---@param skip table<ObviGuideGuide, boolean>
---@param quests table<integer, boolean>
---@return ObviGuideGuide[]
local function Others(skip, quests)
	local list = {}
	for _, other in ipairs(ns.guides) do
		if not skip[other] and other.name ~= NAME and ns.Conditions.Eval(other.cond) and Mentions(other, quests) then
			local read = ns.Ready(other)
			if read then list[#list + 1] = read end
		end
	end
	return list
end

--- The pre-quests of `q` not done yet, and theirs, into `out`. Breadcrumbs are never needed. Of alternatives (any one
--- will do) the first one the earlier guides accept is taken, or all of them when none is there.
---@param DB table
---@param q integer
---@param out table<integer, boolean>
---@param offered table<integer, boolean>   the quests the earlier guides accept
---@param depth integer
---@param guides ObviGuideGuide[]   the guides up to this one, for chains QuestieDB doesn't know
local function Missing(DB, q, out, offered, depth, guides)
	if depth > 40 then return end
	local function add(p)
		if Done(p) or out[p] or Engine.Breadcrumb(DB, p) or not Engine.ForMe(DB, p) then return end
		out[p] = true
		Missing(DB, p, out, offered, depth + 1, guides)
	end
	-- QuestieDB's, or the guide's word for a chain it doesn't know (Engine.PreQuests), here or in the guides before
	local pre = Engine.PreQuests(q)
	if not pre then
		for _, g in ipairs(guides) do
			local inGuide = Engine.ChainedIn(q, g)
			if inGuide then pre = { all = {}, any = inGuide } break end
		end
	end
	if not pre then return end
	for _, p in ipairs(pre.all) do add(p) end
	local single = pre.any
	if #single > 0 then
		for _, p in ipairs(single) do if Done(p) then return end end
		for _, p in ipairs(single) do if offered[p] then add(p) return end end
		for _, p in ipairs(single) do add(p) end
	end
end

--- What catching up on a quest is worth: the XP (at your level) of the quests it would do, the quest itself, and the
--- quests after it in its chain (QuestieDB's next quest) that you'd otherwise miss too. Nil without QuestieDB's quest
--- XP. Remembered until a quest is taken or turned in, or you level.
local worth = {} ---@type table<integer, integer|false>
local worthQuests = {} ---@type table<integer, table<integer, boolean>>   the quests each worth counts
local paces = {} ---@type table<integer, {minutes: number, ratio: number}|false>
local rates = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGuide, number|false>

---@param quest integer
---@return integer?
function Catchup.Worth(quest)
	if worth[quest] ~= nil then return worth[quest] or nil end
	local DB = _G["LibQuestieDB"] ---@type table?
	if not (DB and DB.Quest) then return nil end
	local quests = {} ---@type table<integer, boolean>
	local g = Engine.Current()
	Missing(DB, quest, quests, {}, 0, g and { g } or {})
	quests[quest] = true
	local after = quest
	for _ = 1, 10 do
		local ok, nxt = pcall(DB.Quest.nextQuestInChain, after)
		if not (ok and type(nxt) == "number" and nxt > 0) or Done(nxt) or quests[nxt] then break end
		quests[nxt], after = true, nxt
	end
	local total, known = 0, false
	for q in pairs(quests) do
		local xp = not Done(q) and Engine.QuestXP(q)
		if xp then total, known = total + xp, true end
	end
	worth[quest], worthQuests[quest] = known and total or false, quests
	return known and total or nil
end
local function Forget() worth, worthQuests, paces = {}, {}, {} rates = setmetatable({}, { __mode = "k" }) end
ns:On("QUEST_TURNED_IN", Forget)
ns:On("QUEST_ACCEPTED", Forget)
ns:On("PLAYER_LEVEL_UP", Forget)

--- XP as the game's XP bar counts it: "9,770 XP, 3.8 bars" (a bar: one of its 20 parts, at your level now).
---@param xp integer
---@return string
function Catchup.XPText(xp)
	local max = UnitXPMax("player")
	if not max or max <= 0 then return Catchup.Number(xp) .. " XP" end
	local bars = xp / (max / 20)
	local count = bars >= 10 and tostring(math.floor(bars + 0.5)) or ("%.1f"):format(bars)
	return ("%s XP, %s bar%s"):format(Catchup.Number(xp), count, count == "1.0" and "" or "s")
end

--- XP as bars of the game's XP bar only: "3.8 bars" (a bar: one of its 20 parts, at your level now).
---@param xp integer
---@return string
function Catchup.Bars(xp)
	local max = UnitXPMax("player")
	if not max or max <= 0 then return Catchup.Number(xp) .. " XP" end
	local bars = xp / (max / 20)
	local count = bars >= 10 and tostring(math.floor(bars + 0.5)) or ("%.1f"):format(bars)
	return ("%s bar%s"):format(count, count == "1.0" and "" or "s")
end

--- "12,345"
---@param n integer
function Catchup.Number(n)
	local s = tostring(n)
	while true do
		local k
		s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if k == 0 then return s end
	end
end

--- What a line does for its quest ("322 accept"), so the same line from another guide isn't taken twice.
---@param g ObviGuideGoal
---@param q integer
local function LineKey(g, q)
	return ("%d %s %s"):format(q, g.kind, tostring(g.objective or g.id or ""))
end

--- A step cut down to the lines for `needed` quests (and the lines that only describe), or nil when it has none. A
--- quest line another guide gave already (in `from`, by LineKey) is left out.
---@param s ObviGuideStep
---@param needed table<integer, boolean>
---@param from table<string, ObviGuideGuide>
---@param src ObviGuideGuide
---@return ObviGuideStep?
local function Cut(s, needed, from, src)
	local goals, kept, any = {}, {}, false
	for _, g in ipairs(s.goals) do
		local q = QuestOf(g)
		if q and needed[q] then
			local key = LineKey(g, q)
			if from[key] == nil or from[key] == src then
				from[key] = src
				goals[#goals + 1], kept[g], any = g, true, true
			end
		elseif not q and HELP_LINES[g.kind] then
			goals[#goals + 1], kept[g] = g, true
		end
	end
	if not any then return end
	local tips = {}
	for _, t in ipairs(s.tips or {}) do if not t.after or kept[t.after] then tips[#tips + 1] = t end end
	return { index = 0, cond = s.cond, skip = s.skip, goals = goals, side = {}, tips = tips, dest = s.dest,
		target = s.target, path = s.path or {}, markers = s.markers }
end

---@class ObviGuideCatchupSaved
---@field guide? string      the guide it leads back to
---@field step? integer      at this step
---@field quests integer[]   the quests to catch up on
---@field title? string      the catch-up's own title (made for one quest)

--- The steps for the `needed` quests, from the guides leading to `saved.guide`, its steps before `saved.step`, then any
--- other guide: the catch-up guide, added to the guide list (in place of an earlier one). Returns it, and which needed
--- quests no step has.
-- How long things take, roughly, the same for the catch-up and the guide so the two compare: a step's own doing,
-- the way between steps at running speed (riding from 40), and a flat while for another continent (boat, tram).
local STEP_SECONDS = 30
local OTHER_CONTINENT = 300

---@return number yards per second
local function Speed() return UnitLevel("player") >= 40 and 11 or 7 end

--- Seconds to go from one spot to the next (nil: no spot to go from or to: no way to count).
---@param a? ObviGuidePoint|{continent: number, world: vector2}
---@param b? ObviGuidePoint
---@return number
local function Way(a, b)
	if not (a and b) then return 0 end
	local c1, w1
	if a.world then c1, w1 = a.continent, a.world else c1, w1 = ns.Travel.World(a --[[@as ObviGuidePoint]]) end
	local c2, w2 = ns.Travel.World(b)
	if not (w1 and w2) then return 0 end
	if c1 ~= c2 then return OTHER_CONTINENT end
	local dx, dy = w1.x - w2.x, w1.y - w2.y
	return math.sqrt(dx * dx + dy * dy) / Speed()
end

--- The guide's own pace: the XP (at your level) of the quests it turns in, per second of following it (its steps,
--- and the way between them). Nil when it has none.
---@param g ObviGuideGuide
---@return number?
local function Rate(g)
	if rates[g] == nil then
		local total, seconds, last = 0, 0, nil
		for _, s in ipairs(g.steps) do
			for _, goal in ipairs(s.goals) do
				if goal.kind == "turnin" and goal.quest then total = total + (Engine.QuestXP(goal.quest) or 0) end
			end
			seconds = seconds + STEP_SECONDS
			if s.dest then seconds, last = seconds + Way(last, s.dest), s.dest end
		end
		rates[g] = total > 0 and seconds > 0 and total / seconds or false
	end
	return rates[g] or nil
end

--- Whether catching up on a quest is worth the time: roughly how long it takes (the way from here through the
--- earlier quests' steps and back, and the steps of the quest and its chain after it in this guide, which are on the
--- way anyway), and its XP per minute against the guide's own ("1.3": a third more XP per minute than going on with
--- the guide). Nil when it can't be told.
---@param quest integer
---@return {minutes: number, ratio: number}?
function Catchup.Pace(quest)
	if paces[quest] ~= nil then return paces[quest] or nil end
	paces[quest] = false
	local xp = Catchup.Worth(quest)
	local quests = worthQuests[quest]
	local g, cur = Engine.Current()
	local rate = g and cur and g.name ~= NAME and Rate(g)
	if not (xp and xp > 0 and quests and g and cur and rate) then return nil end
	local here = cur.dest ---@type ObviGuidePoint|{continent: number, world: vector2}|nil
	do
		local continent, world = ns.Travel.PlayerWorld()
		if continent and world then here = { continent = continent, world = world } end
	end
	local steps, seconds, from, at = 0, 0, {}, here
	local function detour(s, src)
		if not Cut(s, quests, from, src) then return end
		steps, seconds = steps + 1, seconds + STEP_SECONDS
		if s.dest then seconds, at = seconds + Way(at, s.dest), s.dest end
	end
	-- (only the guides with one of the quests are read: a chain back to level 1 isn't read while the window draws)
	for _, before in ipairs(Before(g, true)) do
		local read = Mentions(before, quests) and ns.Ready(before) or nil
		for _, s in ipairs(read and read.steps or {}) do if read then detour(s, read) end end
	end
	for i = 1, cur.index - 1 do detour(g.steps[i], g) end
	if steps > 0 then seconds = seconds + Way(at, cur.dest) end   -- and back
	for i = cur.index, #g.steps do
		if Cut(g.steps[i], quests, from, g) then steps, seconds = steps + 1, seconds + STEP_SECONDS end
	end
	if steps == 0 or seconds <= 0 then return nil end
	local pace = { minutes = seconds / 60, ratio = (xp / seconds) / rate }
	paces[quest] = pace
	return pace
end

--- The verdict on catching up on a quest, by its pace against the guide's: "worth" (at least 1.2x the guide's XP per
--- minute), "even" (0.8x to 1.2x) or "not"; nil when it can't be told.
---@param quest integer
---@return "worth"|"even"|"not"|nil, boolean? behind   (true: worth it because you're behind the guide's pace)
function Catchup.Verdict(quest)
	local pace = Catchup.Pace(quest)
	if not pace then return nil end
	-- behind the guide's pace you'll need the XP anyway, and quests beat grinding: worth it
	local behind = Catchup.Behind()
	if behind and behind >= 0.25 then return "worth", true end
	return pace.ratio >= 1.2 and "worth" or pace.ratio >= 0.8 and "even" or "not"
end

--- A guide's levels from its title: "Duskwood & Stranglethorn Vale (30-32)" -> 30, 32.
---@param g? ObviGuideGuide
---@return integer?, integer?
local function Levels(g)
	local a, b = (g and g.title or ""):match("%((%d+)%-(%d+)%)%s*$")
	return tonumber(a), tonumber(b)
end

local shares = setmetatable({}, { __mode = "k" }) ---@type table<ObviGuideGuide, number[]>

--- How far behind the guide's pace you are, in levels (0.6: six tenths of a level), or nil when it can't be told. The
--- guide should take you from its first level to the level the next guide starts at (else its own last), along the
--- way as its quest XP goes: a step with half the guide's quest XP before it is halfway. Mob kills are in that pace
--- already (the guide's levels count on them). Negative: ahead.
---@return number?
function Catchup.Behind()
	local g, cur = Engine.Current()
	if not (g and cur) or g.name == NAME then return nil end
	local from, to = Levels(g)
	-- (the next guide by its title only: not read for this)
	local nextGuide
	for _, other in ipairs(ns.guides) do
		if g.next and (other.title == g.next or other.name == g.next) then nextGuide = other break end
	end
	local nextFrom = Levels(nextGuide)
	to = nextFrom or to
	if not (from and to and to > from) then return nil end
	local share = shares[g]
	if not share then
		-- the guide's quest XP before each step, as a share of all of it (at the guide's own levels: each quest's base XP)
		share = {}
		local DB = _G["LibQuestieDB"] ---@type table?
		local ok, xpdb = pcall(function() return DB and DB.Support.Get("QuestXP").db end)
		local sum, before = 0, {}
		for i, s in ipairs(g.steps) do
			before[i] = sum
			for _, goal in ipairs(s.goals) do
				local e = ok and xpdb and goal.kind == "turnin" and goal.quest and xpdb[goal.quest]
				if type(e) == "table" and e[2] then sum = sum + e[2] end
			end
		end
		for i = 1, #g.steps do share[i] = sum > 0 and before[i] / sum or 0 end
		shares[g] = sum > 0 and share or {}
		share = shares[g]
	end
	local p = share[cur.index]
	if not p then return nil end
	local max = UnitXPMax("player")
	local level = UnitLevel("player") + (max and max > 0 and UnitXP("player") / max or 0)
	return from + p * (to - from) - level
end

---@param saved ObviGuideCatchupSaved
---@return ObviGuideGuide, integer[]
local function Build(saved)
	local needed = {} ---@type table<integer, boolean>
	for _, q in ipairs(saved.quests) do needed[q] = true end
	local g = saved.guide and ns.FindGuide(saved.guide)
	local steps, found, from = {}, {}, {}
	local function take(s, src)
		local cut = Cut(s, needed, from, src)
		if not cut then return end
		cut.index = #steps + 1
		steps[#steps + 1] = cut
		for _, goal in ipairs(cut.goals) do local q = QuestOf(goal) if q then found[q] = true end end
	end
	local skip = {}
	if g then
		skip[g] = true
		for _, before in ipairs(Before(g)) do
			skip[before] = true
			for _, s in ipairs(before.steps) do take(s, before) end
		end
		for i = 1, (saved.step or 1) - 1 do take(g.steps[i], g) end
	end
	local rest = {}
	for q in pairs(needed) do if not found[q] then rest[q] = true end end
	if next(rest) then
		for _, other in ipairs(Others(skip, rest)) do for _, s in ipairs(other.steps) do take(s, other) end end
	end
	local lost = {}
	for q in pairs(needed) do if not found[q] then lost[#lost + 1] = q end end
	table.sort(lost)
	---@type ObviGuideGuide
	local cg = { title = saved.title or ("Catch-up for " .. (g and g.title or "a quest")), name = NAME,
		group = "Catch-up", next = g and (g.name or g.title) or nil, format = "obviguide", source = "ObviGuide",
		steps = steps, back = g and { guide = g.name or g.title, step = saved.step or 1 } or nil }
	for i, other in ipairs(ns.guides) do if other.name == NAME then table.remove(ns.guides, i) break end end
	table.insert(ns.guides, cg)
	ns:Fire("OBVIGUIDE_GUIDES_ADDED")
	return cg, lost
end

-- (with its place in a chain of quests of the same name: "The Night Watch (part 2)")
---@param _ table?
---@param q integer
local function QuestName(_, q) return Engine.QuestLabel(q) end

-- a line's quest title, lower case, without colours and "Accept"
---@param text? string
local function Title(text)
	text = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return (text:gsub("^Accept%s+", ""):lower())
end

--- The quest "/og catchup <quest>" names: its id, a link to it, or its name as a guide accepts it (the guides with the
--- name in their text are read to find its id). Several quests of that name (a chain: The Night Watch 56, 57, 58):
--- the first one, in the guides' order, not done yet.
---@param arg string
---@return integer?
local function QuestFrom(arg)
	local id = tonumber(arg) or tonumber(arg:match("|Hquest:(%d+)"))
	if id then return id end
	local want = Title((arg:gsub("^%[", ""):gsub("%]$", "")))
	local first ---@type integer?
	for _, guide in ipairs(ns.guides) do
		if guide.name ~= NAME and ns.Conditions.Eval(guide.cond) then
			local p, maybe = guide.pending, true
			if p then
				local ok, text = pcall(function() return type(p.text) == "function" and p.text() or p.text end)
				maybe = ok and type(text) == "string" and text:lower():find(want, 1, true) ~= nil
			end
			local read = maybe and ns.Ready(guide)
			for _, s in ipairs(read and read.steps or {}) do
				for _, goal in ipairs(s.goals) do
					if goal.kind == "accept" and goal.quest and Title(goal.text) == want then
						if not Done(goal.quest) then return goal.quest end
						first = first or goal.quest
					end
				end
			end
		end
	end
	return first   -- (all done)
end

--- Works out the skipped quests and opens the catch-up guide for them: for the quests the guide still has for you,
--- or (given) for one quest: what it needs, and the quest itself when the guide doesn't have it from here on.
---@param quest? integer|string   a quest id, or what "/og catchup" was given
function Catchup.Start(quest)
	local DB = _G["LibQuestieDB"] ---@type table?
	if not (DB and DB.Quest) then
		ns.Print("Quest Catchup needs QuestieDB: it knows which quests come before which.")
		return
	end
	local g, cur = Engine.Current()
	if g and g.name == NAME then ns.Print("this is the catch-up already; go back to your guide's tab to start again") return end
	if type(quest) == "string" then
		local arg = quest
		quest = arg:match("%S") and QuestFrom(arg) or nil
		if not quest and arg:match("%S") then ns.Print("Quest Catchup: no guide has a quest '%s'.", arg) return end
	end
	if not quest and not (g and cur) then ns.Print("open a guide first: Quest Catchup looks for what it still needs") return end

	-- the quests the guide has from here on, and in the guide after it
	local ahead = {} ---@type integer[]
	local function accepts(guide, from)
		for i = from, #guide.steps do
			for _, goal in ipairs(guide.steps[i].goals) do
				if goal.kind == "accept" and goal.quest then ahead[#ahead + 1] = goal.quest end
			end
		end
	end
	if g and cur then
		accepts(g, cur.index)
		local after = g.next and ns.FindGuide(g.next)
		if after and after ~= g then accepts(after, 1) end
	end

	-- what the guides before this point accept (to choose between alternative pre-quests)
	local offered = {}
	local function offers(s)
		for _, goal in ipairs(s.goals) do if goal.kind == "accept" and goal.quest then offered[goal.quest] = true end end
	end
	local chain = {} ---@type ObviGuideGuide[]   this guide and the ones leading to it, latest first
	if g and cur then
		chain[1] = g
		for _, before in ipairs(Before(g)) do
			table.insert(chain, 2, before)
			for _, s in ipairs(before.steps) do offers(s) end
		end
		for i = 1, cur.index - 1 do offers(g.steps[i]) end
	end

	local needed = {} ---@type table<integer, boolean>
	if quest then
		---@cast quest integer
		local name = QuestName(DB, quest)
		if Done(quest) then ns.Print("Quest Catchup: you've done %s already.", name) return end
		Missing(DB, quest, needed, offered, 0, chain)
		local later = false
		for _, q in ipairs(ahead) do if q == quest then later = true end end
		if not later and not C_QuestLog.IsOnQuest(quest) then needed[quest] = true end
		if not next(needed) then ns.Print("Quest Catchup: nothing to do before %s; you can take it.", name) return end
	else
		for _, q in ipairs(ahead) do
			if not Done(q) and not C_QuestLog.IsOnQuest(q) and Engine.ForMe(DB, q) then Missing(DB, q, needed, offered, 0, chain) end
		end
		if not next(needed) then
			ns.Print("Quest Catchup: nothing skipped that the rest of this guide needs.")
			return
		end
	end

	local list = {}
	for q in pairs(needed) do list[#list + 1] = q end
	table.sort(list)
	---@type ObviGuideCatchupSaved
	local saved = { guide = g and cur and (g.name or g.title) or nil, step = cur and cur.index or nil, quests = list,
		title = quest and ("Catch-up for " .. QuestName(DB, quest --[[@as integer]])) or nil }
	local cg, lost = Build(saved)
	if ns.charDB then ns.charDB.catchup = saved end

	local names = {}
	for _, q in ipairs(list) do names[#names + 1] = QuestName(DB, q) end
	if quest then
		local xp = Catchup.Worth(quest --[[@as integer]])
		ns.Print("Quest Catchup for %s: %s.%s", QuestName(DB, quest --[[@as integer]]), table.concat(names, ", "),
			xp and xp > 0 and (" Worth %s with what follows it."):format(Catchup.XPText(xp)) or "")
	else
		ns.Print("Quest Catchup: %d skipped quest%s needed later: %s.", #list, #list == 1 and " is" or "s are",
			table.concat(names, ", "))
	end
	if #lost > 0 then
		local missing = {}
		for _, q in ipairs(lost) do missing[#missing + 1] = ("%s (%d)"):format(QuestName(DB, q), q) end
		ns.Print("Not in any guide: %s.", table.concat(missing, ", "))
	end
	if #cg.steps == 0 then return end
	Engine.Open(NAME, true)
end

--- Back from a finished catch-up guide to the guide it was made for: its tab, or (closed meanwhile) opened again at the
--- step it was on. The catch-up's tab is closed.
---@param cg ObviGuideGuide
function Catchup.Return(cg)
	local back = cg.back
	if not (back and ns.charDB) then return end
	ns.charDB.catchup = nil
	local tabs, shown = Engine.Tabs()
	local target = ns.FindGuide(back.guide)
	for i, tab in ipairs(tabs) do
		if i ~= shown and tab.guide and ns.FindGuide(tab.guide) == target then
			Engine.CloseTab(shown)
			Engine.SwitchTab(i < shown and i or i - 1)
			return
		end
	end
	Engine.Load(back.guide, back.step)
end

-- after a reload the catch-up guide is made again from the quests saved for it, once its guide is here
local function Rebuild()
	local saved = ns.charDB and ns.charDB.catchup
	if not saved then return end
	for _, other in ipairs(ns.guides) do if other.name == NAME then return end end
	-- (its tab closed meanwhile: nothing to make it for)
	local open = false
	for _, tab in ipairs((Engine.Tabs())) do if tab.guide == NAME then open = true end end
	if not open then ns.charDB.catchup = nil return end
	if saved.guide and not ns.FindGuide(saved.guide) then return end
	Build(saved)
end
ns:On("PLAYER_ENTERING_WORLD", Rebuild)
ns:On("OBVIGUIDE_GUIDES_ADDED", Rebuild)
