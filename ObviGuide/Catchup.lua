-- Quest Catchup, after Zygor's Smart Injection System: the quests the guide still has for you (from the current step
-- to the end of the guide, and in the guide after it) may need earlier quests you skipped. QuestieDB knows each
-- quest's pre-quests; the ones not done yet are looked up in the guides before this point (the guides leading to this
-- one, and this one's earlier steps), and their steps, cut down to those quests, become a short guide of their own. It
-- opens in a tab beside the guide and leads back to it when done. "/og catchup" or the gear menu starts it.
-- Needs QuestieDB (its public library, LibQuestieDB); without it there's nothing to know the pre-quests from.
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
		if Done(p) or out[p] or DB.Quest.breadcrumbForQuestId(p) or not Engine.ForMe(DB, p) then return end
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

--- A step cut down to the lines for `needed` quests (and the lines that only describe), or nil when it has none.
---@param s ObviGuideStep
---@param needed table<integer, boolean>
---@return ObviGuideStep?
local function Cut(s, needed)
	local goals, kept, any = {}, {}, false
	for _, g in ipairs(s.goals) do
		local q = QuestOf(g)
		if (q and needed[q]) or (not q and HELP_LINES[g.kind]) then
			goals[#goals + 1], kept[g] = g, true
			if q then any = true end
		end
	end
	if not any then return end
	local tips = {}
	for _, t in ipairs(s.tips or {}) do if not t.after or kept[t.after] then tips[#tips + 1] = t end end
	return { index = 0, cond = s.cond, skip = s.skip, goals = goals, side = {}, tips = tips, dest = s.dest,
		target = s.target, path = s.path or {}, markers = s.markers }
end

--- The steps before `step` of `g` (the guides leading to it, then its own) for the `needed` quests: the catch-up guide,
--- added to the guide list (in place of an earlier one). Returns it, and which needed quests no step has.
---@param g ObviGuideGuide
---@param step integer
---@param needed table<integer, boolean>
---@return ObviGuideGuide, integer[]
local function Build(g, step, needed)
	local steps, found = {}, {}
	local function take(s)
		local cut = Cut(s, needed)
		if not cut then return end
		cut.index = #steps + 1
		steps[#steps + 1] = cut
		for _, goal in ipairs(cut.goals) do local q = QuestOf(goal) if q then found[q] = true end end
	end
	for _, before in ipairs(Before(g)) do for _, s in ipairs(before.steps) do take(s) end end
	for i = 1, step - 1 do take(g.steps[i]) end
	local lost = {}
	for q in pairs(needed) do if not found[q] then lost[#lost + 1] = q end end
	table.sort(lost)
	---@type ObviGuideGuide
	local cg = { title = "Catch-up for " .. g.title, name = NAME, group = "Catch-up", next = g.name or g.title,
		format = "obviguide", source = "ObviGuide", steps = steps, back = { guide = g.name or g.title, step = step } }
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

--- Works out what the guide needs from before this point and opens the catch-up guide for it.
function Catchup.Start()
	local DB = _G["LibQuestieDB"] ---@type table?
	if not (DB and DB.Quest) then
		ns.Print("Quest Catchup needs QuestieDB: it knows which quests come before which.")
		return
	end
	local g, cur = Engine.Current()
	if g and g.name == NAME then ns.Print("this is the catch-up already; go back to your guide's tab to start again") return end
	if not (g and cur) then ns.Print("open a guide first: Quest Catchup looks for what it still needs") return end

	-- the quests still to come: this guide from here on, and the guide after it
	local ahead = {} ---@type integer[]
	local function accepts(guide, from)
		for i = from, #guide.steps do
			for _, goal in ipairs(guide.steps[i].goals) do
				if goal.kind == "accept" and goal.quest then ahead[#ahead + 1] = goal.quest end
			end
		end
	end
	accepts(g, cur.index)
	local after = g.next and ns.FindGuide(g.next)
	if after and after ~= g then accepts(after, 1) end

	-- what the guides before this point accept (to choose between alternative pre-quests)
	local offered = {}
	local function offers(s)
		for _, goal in ipairs(s.goals) do if goal.kind == "accept" and goal.quest then offered[goal.quest] = true end end
	end
	for _, before in ipairs(Before(g)) do for _, s in ipairs(before.steps) do offers(s) end end
	for i = 1, cur.index - 1 do offers(g.steps[i]) end

	local needed = {} ---@type table<integer, boolean>
	for _, q in ipairs(ahead) do
		if not Done(q) and not C_QuestLog.IsOnQuest(q) and Engine.ForMe(DB, q) then Missing(DB, q, needed, offered, 0) end
	end
	if not next(needed) then
		ns.Print("Quest Catchup: nothing skipped that the rest of this guide needs.")
		return
	end

	local cg, lost = Build(g, cur.index, needed)
	local list = {}
	for q in pairs(needed) do list[#list + 1] = q end
	table.sort(list)
	if ns.charDB then ns.charDB.catchup = { guide = g.name or g.title, step = cur.index, quests = list } end

	local names = {}
	for _, q in ipairs(list) do names[#names + 1] = QuestName(DB, q) end
	ns.Print("Quest Catchup: %d skipped quest%s needed later: %s.", #list, #list == 1 and " is" or "s are",
		table.concat(names, ", "))
	if #lost > 0 then
		local missing = {}
		for _, q in ipairs(lost) do missing[#missing + 1] = ("%s (%d)"):format(QuestName(DB, q), q) end
		ns.Print("Not in the guides before this point: %s.", table.concat(missing, ", "))
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
	local g = ns.FindGuide(saved.guide)
	if not g then return end
	local needed = {}
	for _, q in ipairs(saved.quests or {}) do needed[q] = true end
	Build(g, saved.step, needed)
end
ns:On("PLAYER_ENTERING_WORLD", Rebuild)
ns:On("OBVIGUIDE_GUIDES_ADDED", Rebuild)
