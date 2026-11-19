-- Profession guides from data: a profession's route (skill ranges and what to make in each), its recipes (spell, item,
-- the skill each is learned at, reagents) and its trainers and vendors become a guide, built by the rules in
-- GUIDELINES.md, so every profession guide works the same way:
--
-- - Trainer visits, a step of their own just before the range that needs them: a visit comes where a range needs a
--   recipe you don't know yet, or a rank you haven't trained. It teaches every recipe the guide still needs that can
--   be learned at that skill, and every rank that can be trained there: required when a range before the next visit
--   goes past your cap, else optional (and offered again at the next visit). Its trainer is the nearest one who
--   teaches all of that.
-- - The steps: the prerequisites (tools) to collect, learning the profession, then per range: a step for each part
--   it makes that later ranges use ("Make 30 Heavy Blasting Powder": done once they're in your bags, passed over once
--   the last range that uses them is done; a tool, one, for good), then the range itself ("Make Whirring Bronze Gizmo
--   to 150"), done by the skill alone. Their materials (count x the recipe's reagents: for the parts still to make,
--   or the points left in the range) go down as you make them, and show what's in your bags but don't hold a step.
-- - A material sold by vendors (flux) is a materials line like the others, with where it's sold (clicking it shows
--   the way to the nearest); plans and schematics are bought, and used to learn them, just before their range.
-- - An introduction, ticked by hand: the counts are for a point per craft; a yellow recipe needs a few more.
-- - The totals: a side box beside every step with the raw materials the ranges you haven't started need.
-- - To sell: a side box beside every step with the guide's items in your bags beyond what the ranges not done yet
--   need (what it makes only for the points, spare materials); not the tools.
local _, pack = ...

local RANK = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }

---@class ProfPlace
---@field map integer
---@field x number
---@field y number
---@field name string   the NPC
---@field id integer

---@class ProfRecipe
---@field spell integer       the recipe's spell (a recipe you know is a spell you know)
---@field item integer        what it makes
---@field learn integer       the skill it's learned at
---@field reagents table<integer, integer>   item id -> how many one craft takes
---@field known? boolean      known with the profession
---@field teach? integer      the plans, schematic or manual that teach it (used), instead of a trainer
---@field sold? ProfPlace[]   where they're sold (the same table for one seller: bought in one visit)
---@field source? string      where they come from, when no one sells them (a note)
---@field quest? ProfQuest    a quest that gives them
---@field at? ProfPlace[]     someone other than the trainers who teaches it
---@field tier? integer       the trainer rank who teaches it, when it isn't the one above its skill (75, 150...)
---@field tool? boolean       made once and kept for good (it's needed to make others)

---@class ProfQuest
---@field id integer
---@field title string
---@field at ProfPlace[]     who gives it (and takes it back)
---@field level? integer
---@field pre? {id: integer, title: string}   a quest to take first
---@field items? table<integer, integer>   what it asks for (item id -> how many)

---@class ProfRange
---@field [1] integer   from
---@field [2] integer   to
---@field [3] string|{[1]: string, [2]: integer?}   the recipe (its name), or {name, count}; more after it: more recipes
---@field count? integer   how many (the first recipe's; default: one per point)
---@field anvil? boolean   made at an anvil (the trainer has none)
---@field alt? string      a choice the site gives: a note, and no materials step (the totals count the main one)
---@field note? string

---@class ProfRank
---@field cap integer     the cap it brings (150, 225, 300)
---@field skill integer   the skill it's trained at
---@field level? integer  the level it needs (none: any)
---@field book? integer   a book that teaches it (used), instead of the trainers
---@field sold? ProfPlace[]   where the book is sold
---@field at? ProfPlace[]     someone other than the trainers who teaches it
---@field items? table<integer, integer>   what they ask for first (a quest's hand-in)
---@field note? string

---@class ProfGuide
---@field title string
---@field id string
---@field only? string
---@field skill string        the profession, by its English name
---@field credit string       the first step's note
---@field intro? string       a note for the introduction (what holds for every recipe: "Every recipe needs an anvil.")
---@field items table<integer, string>   the names of the raw materials, tools and schematics (by item id)
---@field recipes table<string, ProfRecipe>
---@field ranks ProfRank[]
---@field trainers table<integer, ProfPlace[]>   by the highest cap they train (75, 150, 225, 300)
---@field tools? {item: integer, at: ProfPlace[]}[]   bought after learning the profession
---@field buy? table<integer, ProfPlace[]>   reagents bought from vendors: item id -> where
---@field route ProfRange[]

--- A place: where an NPC stands.
---@param map integer
---@param x number
---@param y number
---@param name string
---@param id integer
---@return ProfPlace
function pack.Place(map, x, y, name, id) return { map = map, x = x, y = y, name = name, id = id } end

--- A range's recipes, as {name, count} (the first one's count from the range, else one per point).
---@param r ProfRange
---@return {[1]: string, [2]: integer}[]
local function Makes(r)
	local out = {}
	for k = 3, #r do
		local m = r[k]
		local name, count = m, nil
		if type(m) == "table" then name, count = m[1], m[2] end
		if k == 3 then count = count or r.count end
		table.insert(out, { name, count or (r[2] - r[1]) })
	end
	return out
end

--- The trainer tier that teaches a recipe learned at `learn`: the lowest cap above it.
---@param learn integer
local function TierFor(learn)
	for _, cap in ipairs({ 75, 150, 225, 300 }) do if learn < cap then return cap end end
	return 300
end

---@class ProfVisit
---@field learn string[]   the recipes it teaches, in the route's order
---@field ranks {rank: ProfRank, optional: boolean}[]
---@field tier integer      the lowest trainer rank who teaches all of it
---@field upto integer      the skill it's needed until (the end of the last range that makes what it teaches)

--- Where to learn everything: the trainer visits, by the range they come before. A visit comes where a range needs
--- a recipe you don't know yet, or a cap you haven't got. It teaches every recipe the guide still needs that can be
--- learned at that skill, and every rank that can be trained: required when a range before the next visit goes past
--- the cap you have, else optional (offered again at the next visit).
--- A rank the trainers don't teach: from a book, or someone else.
---@param rank ProfRank
local function Special(rank) return rank.book ~= nil or rank.at ~= nil end

--- The ranks the trainers don't teach, by the range they come before: the first that goes past the cap you'd have
--- without them.
---@param def ProfGuide
---@return table<integer, ProfRank>
local function SpecialRanks(def)
	local out, cap = {}, 75
	local ranks = {}
	for _, rank in ipairs(def.ranks) do table.insert(ranks, rank) end
	table.sort(ranks, function(a, b) return a.cap < b.cap end)
	for i, r in ipairs(def.route) do
		for _, rank in ipairs(ranks) do
			if r[2] > cap and rank.cap > cap then
				if Special(rank) then out[i] = rank end
				cap = rank.cap
			end
		end
	end
	return out
end

---@param def ProfGuide
---@return table<integer, ProfVisit>
local function Visits(def)
	local route, known, cap, trained, visits = def.route, {}, 75, {}, {}
	for name, r in pairs(def.recipes) do if r.known then known[name] = true end end
	local specials = SpecialRanks(def)
	local function fromTrainer(name)
		local r = def.recipes[name]
		return not (r.known or r.teach or r.at or r.quest)
	end
	--- Whether range j needs a visit: a recipe from a trainer not known yet, or a cap you haven't got (that a
	--- trainer teaches: a special rank comes before its range by itself).
	local function needs(j)
		if specials[j] then cap = math.max(cap, specials[j].cap) end
		if route[j][2] > cap then return true end
		for _, m in ipairs(Makes(route[j])) do if fromTrainer(m[1]) and not known[m[1]] then return true end end
		return false
	end
	local i = 1
	while i <= #route do
		if not needs(i) then
			i = i + 1
		else
			local s = route[i][1]
			local visit = { learn = {}, ranks = {}, tier = 75, upto = route[i][2] } ---@type ProfVisit
			-- every recipe the guide still needs that's learnable now
			for j = i, #route do
				for _, m in ipairs(Makes(route[j])) do
					local name = m[1]
					if fromTrainer(name) and not known[name] and def.recipes[name].learn <= s then
						known[name] = true
						table.insert(visit.learn, name)
						visit.tier = math.max(visit.tier, def.recipes[name].tier or TierFor(def.recipes[name].learn))
					end
				end
			end
			-- the next visit, as far as the recipes go
			local nextAt = #route + 1
			for j = i + 1, #route do
				for _, m in ipairs(Makes(route[j])) do
					if fromTrainer(m[1]) and not known[m[1]] then nextAt = math.min(nextAt, j) end
				end
			end
			-- the ranks: required when a range before then goes past your cap
			local newCap = cap
			for _, rank in ipairs(def.ranks) do
				if not Special(rank) and not trained[rank] and rank.skill <= s then
					local required = false
					for j = i, nextAt - 1 do if route[j][2] > cap then required = true end end
					table.insert(visit.ranks, { rank = rank, optional = not required })
					visit.tier = math.max(visit.tier, rank.cap)
					if required then trained[rank], newCap = true, math.max(newCap, rank.cap) end
				end
			end
			cap = newCap
			visits[i] = visit
			-- needed until the last range that makes what it teaches (or, for ranks alone, this one) is done
			local taught = {}
			for _, name in ipairs(visit.learn) do taught[name] = true end
			for j = i, #route do
				for _, m in ipairs(Makes(route[j])) do if taught[m[1]] then visit.upto = math.max(visit.upto, route[j][2]) end end
			end
			-- on to the next range that needs a visit
			local j = i + 1
			while j <= #route and not needs(j) do j = j + 1 end
			i = j
		end
	end
	return visits
end

--- Builds the guide.
---@param def ProfGuide
function pack.Guide(def)
	ObviGuide.Guide(function(g)
		g.title, g.id, g.group, g.only = def.title, def.id, "Professions", def.only
		local SKILL = def.skill

		-- markers
		local function Item(id)
			for name, r in pairs(def.recipes) do if r.item == id then return g.Item(name, id) end end
			return g.Item(def.items[id] or ("item " .. id), id)
		end
		local made = {} ---@type table<integer, string>   item id -> the recipe that makes it
		for name, r in pairs(def.recipes) do made[r.item] = name end

		--- A step at an NPC, or the nearest of several.
		---@param places ProfPlace[]
		---@param build fun(s: ObviGuideStepBuilder)
		local function At(places, build)
			g:Step(function(s)
				s.nearest = #places > 1 or nil
				for _, p in ipairs(places) do
					s:Goto(p.map, p.x, p.y)
					s:Talk(g.Npc(p.name, p.id))
				end
				build(s)
			end)
		end
		--- The trainers who teach up to `tier` or more.
		local function Trainers(tier)
			local out = {}
			for _, cap in ipairs({ 75, 150, 225, 300 }) do
				if cap >= tier then for _, p in ipairs(def.trainers[cap] or {}) do table.insert(out, p) end end
			end
			return out
		end
		local function Learn(s, name)
			local r = def.recipes[name]
			if r.teach then return s:Use(Item(r.teach)):Done("knows " .. r.spell) end
			return s:Learn(g.Spell(name, r.spell))
		end
		local function Spell(name) return g.Spell(name, def.recipes[name].spell) end

		-- per range: the materials (count x reagents), and what parts each range makes that later ones use
		local route, mats = def.route, {}
		for i, r in ipairs(route) do
			local list, seen = {}, {}
			for _, m in ipairs(Makes(r)) do
				for id, n in pairs(def.recipes[m[1]].reagents) do
					if not seen[id] then seen[id] = { id, 0 } table.insert(list, seen[id]) end
					seen[id][2] = seen[id][2] + n * m[2]
				end
			end
			table.sort(list, function(a, b) return a[1] < b[1] end)
			mats[i] = list
		end
		--- What a range has to keep of a part it makes: how many later ranges use, and the end of the last of them.
		local function Keep(i, name)
			if def.recipes[name].tool then return 1, nil end
			local item, n, used = def.recipes[name].item, 0, nil
			for j = i + 1, #route do
				for _, m in ipairs(mats[j]) do if m[1] == item then n, used = n + m[2], route[j][2] end end
			end
			if n > 0 then return n, used end
		end

		-- the totals: beside every step to the last, the raw materials of the ranges not started yet
		g:Side("last", function(s)
			s:Say("To collect:")
			local order, by = {}, {}
			-- (a range with a choice counts its main option)
			for i, r in ipairs(route) do
				for _, m in ipairs(mats[i]) do
					if not made[m[1]] then
						if not by[m[1]] then by[m[1]] = {} table.insert(order, m[1]) end
						table.insert(by[m[1]], { from = r[1], n = m[2] })
					end
				end
			end
			for _, id in ipairs(order) do
				local list, prev = by[id], nil
				for k = 1, #list do
					if list[k].from ~= prev then
						local sum = 0
						for j = k, #list do sum = sum + list[j].n end
						local cond = ("skill %s <= %d"):format(SKILL, list[k].from)
						if prev then cond = ("%s and skill %s > %d"):format(cond, SKILL, prev) end
						s:Collect(Item(id), { count = sum }):Only(cond)
						prev = list[k].from
					end
				end
			end
		end)

		-- things to sell: beside every step to the last, the guide's items in your bags beyond what the ranges not done
		-- yet need (the one you're in too): what it makes only for the points, and spare materials. Not the tools.
		g:Side("last", function(s)
			s:Say("To sell:")
			local keep = {} ---@type table<integer, boolean>
			for _, t in ipairs(def.tools or {}) do keep[t.item] = true end
			for _, r in pairs(def.recipes) do
				if r.tool then keep[r.item] = true end
				if r.teach then keep[r.teach] = true end
			end
			-- each item, and what each range needs of it (by the skill it ends at)
			local order, by = {}, {}
			local function add(id, to, n)
				if keep[id] then return end
				if not by[id] then by[id] = {} table.insert(order, id) end
				if to then table.insert(by[id], { to = to, n = n }) end
			end
			for i, r in ipairs(route) do
				for _, m in ipairs(Makes(r)) do add(def.recipes[m[1]].item) end
				for _, m in ipairs(mats[i]) do add(m[1], r[2], m[2]) end
			end
			for _, id in ipairs(order) do
				local list = by[id]
				table.sort(list, function(a, b) return a.to < b.to end)
				-- while below a range's end, keep what it and the ranges after it need; past the last, keep none
				local prev = nil
				for k = 1, #list do
					if list[k].to ~= prev then
						local sum = 0
						for j = k, #list do sum = sum + list[j].n end
						local cond = ("skill %s < %d"):format(SKILL, list[k].to)
						if prev then cond = ("skill %s >= %d and %s"):format(SKILL, prev, cond) end
						s:Sell(Item(id), sum):Only(cond)
						prev = list[k].to
					end
				end
				local line = s:Sell(Item(id), 0)
				if prev then line:Only(("skill %s >= %d"):format(SKILL, prev)) end
			end
		end)

		-- the introduction, ticked by hand: the counts are for a point per craft, which a yellow recipe doesn't always give
		g:Step(function(s)
			s:Do("Counts are for a point per craft: a yellow recipe needs a few more, so get a few spare materials.")
			if def.intro then s:Note(def.intro) end
			s:Note(def.credit)
		end)
		-- the prerequisites (tools), at the nearest seller; then learning the profession
		for _, t in ipairs(def.tools or {}) do
			At(t.at, function(s)
				s:Collect(Item(t.item))
			end)
		end
		At(Trainers(75), function(s)
			s:Train(SKILL)
		end)

		local visits, specials = Visits(def), SpecialRanks(def)

		-- what's bought to learn from (plans, schematics, manuals, rank books): by seller (the `sold` table), all in one
		-- visit before the first range that needs any of it, each ticked once you have it or know what it teaches
		local shops = {} ---@type table<ProfPlace[], {first: integer, last: integer, goods: {item: integer, has: string}[]}>
		local function sells(sold, i, item, has)
			local shop = shops[sold]
			if not shop then shop = { first = i, last = i, goods = {} } shops[sold] = shop end
			shop.first, shop.last = math.min(shop.first, i), math.max(shop.last, route[i][2])
			-- (each thing once: two ranges may make the same recipe)
			for _, x in ipairs(shop.goods) do if x.item == item then return end end
			table.insert(shop.goods, { item = item, has = has })
		end
		for i, r in ipairs(route) do
			for _, m in ipairs(Makes(r)) do
				local rec = def.recipes[m[1]]
				if rec.teach and rec.sold then
					sells(rec.sold, i, rec.teach, ("knows %d or items %d >= 1"):format(rec.spell, rec.teach))
				end
			end
			local rank = specials[i]
			if rank and rank.book and rank.sold then
				sells(rank.sold, i, rank.book, ("skillmax %s >= %d or items %d >= 1"):format(SKILL, rank.cap, rank.book))
			end
		end

		for i, r in ipairs(route) do
			local from, to = r[1], r[2]
			local past = ("skill %s >= %d"):format(SKILL, to)
			-- the shopping for the ranges ahead, at each seller whose first is this range
			for sold, shop in pairs(shops) do
				if shop.first == i then
					At(sold, function(s)
						s.skip = ("skill %s >= %d"):format(SKILL, shop.last)
						for _, x in ipairs(shop.goods) do s:Do(g.Buy("Buy the "), Item(x.item), "."):Done(x.has) end
					end)
				end
			end
			-- a rank the trainers don't teach: its book used, or at whoever teaches it (after what they ask for)
			local rank = specials[i]
			if rank then
				local trained = ("skillmax %s >= %d"):format(SKILL, rank.cap)
				local function build(s)
					s.skip = trained
					if rank.level then s:Level(rank.level) end
					for id, n in pairs(rank.items or {}) do s:Collect(Item(id), { count = n }) end
					if rank.book then
						s:Use(Item(rank.book)):Done(trained)
					else
						s:Train(SKILL, rank.cap)
					end
					if rank.note then s:Note(rank.note) end
				end
				if rank.at then At(rank.at, build) else g:Step(build) end
			end
			-- recipes taught by someone other than the trainers, or by a quest's plans: before the range that needs them
			for _, m in ipairs(Makes(r)) do
				local rec = def.recipes[m[1]]
				local knows = "knows " .. rec.spell
				if rec.at then
					At(rec.at, function(s)
						s.skip = past .. " or " .. knows
						s:Learn(Spell(m[1]))
					end)
				elseif rec.quest then
					local q = rec.quest --[[@as ProfQuest]]
					At(q.at, function(s)
						s.skip = past .. " or " .. knows
						if q.level then s:Level(q.level) end
						if q.pre then s:Accept(q.pre.id, q.pre.title) end
						s:Accept(q.id, q.title)
						for id, n in pairs(q.items or {}) do s:Collect(Item(id), { count = n }) end
						s:Turnin(q.id, q.title)
						Learn(s, m[1])
					end)
				end
			end
			-- a trainer visit: what it can teach that the guide needs, and the ranks (an optional one may wait)
			local visit = visits[i]
			if visit then
				At(Trainers(visit.tier), function(s)
					s.skip = ("skill %s >= %d"):format(SKILL, visit.upto)
					for _, x in ipairs(visit.ranks) do
						local line = s:Train(SKILL, x.rank.cap)
						if x.optional then line:Optional() end
					end
					for _, name in ipairs(visit.learn) do Learn(s, name) end
					for _, x in ipairs(visit.ranks) do
						if x.rank.level then s:Note(("%s needs level %d."):format(RANK[x.rank.cap], x.rank.level)) end
					end
				end)
			end
			-- the parts it makes that later ranges use (or a tool): a step each, "Make 30 Heavy Blasting Powder", done
			-- once they're in your bags, passed over once the last range that uses them is done (a tool: never)
			local leveling = {}
			for _, m in ipairs(Makes(r)) do
				local rec = def.recipes[m[1]]
				local n, used = Keep(i, m[1])
				if n then
					g:Step(function(s)
						if used then s.skip = ("skill %s >= %d"):format(SKILL, used) end
						-- (the materials for the ones still to make)
						local ids = {}
						for id in pairs(rec.reagents) do table.insert(ids, id) end
						table.sort(ids)
						for _, id in ipairs(ids) do
							s:Collect(Item(id), { toMake = { item = rec.item, count = n, each = rec.reagents[id] },
								at = def.buy and def.buy[id] }):Optional()
						end
						if rec.teach and not rec.quest then Learn(s, m[1]) end
						if rec.source then s:Note(rec.source) end
						s:Say("Make " .. n .. " ", Item(rec.item), "."):CraftsUpTo(Spell(m[1]), rec.item, n, SKILL)
						if r.anvil then s:Note("At an anvil.") end
						s:Collect(Item(rec.item), { count = n })
					end)
				else
					table.insert(leveling, m)
				end
			end
			-- then the range itself: crafting to its end (what it makes for the points, else its last part), done by
			-- the skill alone; the materials, for the points left, show what's in your bags but don't hold the step
			if #leveling == 0 then leveling = { Makes(r)[#Makes(r)] } end
			g:Step(function(s)
				if i == #route then s.label = "last" end
				s.skip = past
				-- (one sold by vendors says where: clicking it shows the way to the nearest)
				local need, order = {}, {}
				for _, m in ipairs(leveling) do
					for id, each in pairs(def.recipes[m[1]].reagents) do
						if not need[id] then need[id] = 0 table.insert(order, id) end
						need[id] = need[id] + each * m[2]
					end
				end
				table.sort(order)
				for _, id in ipairs(order) do
					s:Collect(Item(id), { count = need[id], range = { SKILL, from, to }, at = def.buy and def.buy[id] })
						:Optional()
				end
				for _, m in ipairs(leveling) do
					local rec = def.recipes[m[1]]
					-- (one taught by plans or a manual: used here, first)
					if rec.teach and not rec.quest then Learn(s, m[1]) if rec.source then s:Note(rec.source) end end
					-- (click the line, or its action key, to make what the points left need)
					s:Say("Make ", Item(rec.item), " to " .. to .. "."):Crafts(Spell(m[1]), m[2], from)
				end
				if r.anvil then s:Note("At an anvil.") end
				if r.note then s:Note(r.note) end
				if r.alt then s:Note(r.alt) end
				s:Skill(SKILL, to)
			end)
		end
	end)
end
