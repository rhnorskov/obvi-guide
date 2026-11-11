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

--- The guides leading to `g` (each one whose next is the one after it, for this character), earliest first; read.
---@param g ObviGuideGuide
---@return ObviGuideGuide[]
local function Before(g)
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
		local read = ns.Ready(prev)
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
local function Missing(DB, q, out, offered, depth)
	if depth > 40 then return end
	local function add(p)
		if Done(p) or out[p] or Engine.Breadcrumb(DB, p) or not Engine.ForMe(DB, p) then return end
		out[p] = true
		Missing(DB, p, out, offered, depth + 1)
	end
	for _, p in ipairs(DB.Quest.preQuestGroup(q) or {}) do add(p) end
	local single = DB.Quest.preQuestSingle(q)
	if single and #single > 0 then
		for _, p in ipairs(single) do if Done(p) then return end end
		for _, p in ipairs(single) do if offered[p] then add(p) return end end
		for _, p in ipairs(single) do add(p) end
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

---@param DB table?
---@param q integer
local function QuestName(DB, q)
	return (DB and DB.Quest.name(q)) or C_QuestLog.GetTitleForQuestID(q) or ("quest " .. q)
end

-- a line's quest title, lower case, without colours and "Accept"
---@param text? string
local function Title(text)
	text = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return (text:gsub("^Accept%s+", ""):lower())
end

--- The quest "/og catchup <quest>" names: its id, a link to it, or its name as a guide accepts it (the guides with the
--- name in their text are read to find its id).
---@param arg string
---@return integer?
local function QuestFrom(arg)
	local id = tonumber(arg) or tonumber(arg:match("|Hquest:(%d+)"))
	if id then return id end
	local want = Title(arg:gsub("^%[", ""):gsub("%]$", ""))
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
					if goal.kind == "accept" and goal.quest and Title(goal.text) == want then return goal.quest end
				end
			end
		end
	end
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
	if g and cur then
		for _, before in ipairs(Before(g)) do for _, s in ipairs(before.steps) do offers(s) end end
		for i = 1, cur.index - 1 do offers(g.steps[i]) end
	end

	local needed = {} ---@type table<integer, boolean>
	if quest then
		---@cast quest integer
		local name = QuestName(DB, quest)
		if Done(quest) then ns.Print("Quest Catchup: you've done %s already.", name) return end
		Missing(DB, quest, needed, offered, 0)
		local later = false
		for _, q in ipairs(ahead) do if q == quest then later = true end end
		if not later and not C_QuestLog.IsOnQuest(quest) then needed[quest] = true end
		if not next(needed) then ns.Print("Quest Catchup: nothing to do before %s; you can take it.", name) return end
	else
		for _, q in ipairs(ahead) do
			if not Done(q) and not C_QuestLog.IsOnQuest(q) and Engine.ForMe(DB, q) then Missing(DB, q, needed, offered, 0) end
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
		ns.Print("Quest Catchup for %s: %s.", QuestName(DB, quest --[[@as integer]]), table.concat(names, ", "))
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
