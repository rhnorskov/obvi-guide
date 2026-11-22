-- Actions: keybindable actions for the current step, like Zygor's action buttons but without a bar. Hidden secure
-- buttons each do one thing the step (or its side tasks) needs: use an item, cast a spell, target an NPC or mob, or
-- interact with an object in the world. Action 1 is the step's main action; actions 2-4 take the step's other targets
-- and items, then the side tasks.
-- Bind them in Key Bindings > Obvi Guide. Secure buttons can't change in combat, so a step change during a fight takes
-- effect when combat ends.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

---@class ObviGuideAction
local Action = {}
ns.Action = Action

local COUNT = 4

---@class ObviGuideActionInfo
---@field kind "item"|"spell"|"target"|"interact"|"craft"   interact: the key is the game's Interact (an object to click)
---@field goal? ObviGuideGoal   the line the action belongs to (for the key hint)
---@field value string|integer|string[]   a target: one name, or several (any of them)
---@field enemy? boolean       a target to attack (else to talk to)

---@class ObviGuideActionSlot
---@field button Button
---@field binding string
---@field current? ObviGuideActionInfo
---@field interacting boolean  the key is "Interact with Target" now
---@field keep? boolean   its target is tagged by someone else: the next press targets the next one of that name
---@field gossip? ObviGuideGoal   the "Select …" line whose dialogue option the key picks while the dialogue shows
---@field training? ObviGuideGoal   the "Learn …"/"Train …" line the key trains while a trainer's window is open

local slots = {} ---@type ObviGuideActionSlot[]
for i = 1, COUNT do
	-- action 1 keeps its first name, so a key bound before there were more stays bound
	local name = i == 1 and "ObviGuideActionButton" or "ObviGuideActionButton" .. i
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate") --[[@as Button]]
	button:SetSize(1, 1)
	button:SetAlpha(0)
	button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
	button:RegisterForClicks("AnyDown", "AnyUp")
	local binding = "CLICK " .. name .. ":LeftButton"
	-- the names Key Bindings shows (FrameXML globals)
	_G["BINDING_NAME_" .. binding] = "Action Button " .. i
	slots[i] = { button = button, binding = binding, interacting = false }
end

-- each action's plain button for crafting, which its secure button clicks (Action.Craft, below)
local crafters = {} ---@type Button[]
for i = 1, COUNT do
	local b = CreateFrame("Button", "ObviGuideCraftButton" .. i, UIParent)
	b:Hide()
	b:SetScript("OnClick", function(self)
		local g = self["goal"]
		if g then Action.Craft(g) end
	end)
	crafters[i] = b
end

local pending = false

--- The step's actions, most important first: its items, equipment, spells and targets, then its side tasks'.
---@return ObviGuideActionInfo[]
local function Pick()
	local _, step = Engine.Current()
	if not step then return {} end
	local list, seen = {}, {}
	local function add(kind, value, goal, enemy)
		local key = kind .. ":" .. (type(value) == "table" and table.concat(value, ",") or tostring(value))
		if seen[key] or #list >= COUNT then return end
		seen[key] = true
		-- a mob already in an action for several mobs gets no second action of its own (e.g. a "collect" line
		-- whose target is one of the mobs a kill line names)
		if type(value) == "table" then for _, n in ipairs(value) do seen[kind .. ":" .. n] = true end end
		table.insert(list, { kind = kind, value = value, goal = goal, enemy = enemy })
	end
	local function open(g) return Engine.IsVisible(g) and not Engine.IsComplete(g, step) end
	-- a line's targets: an action for each when it names several mobs ("Kill Raging Reef Crawler, Encrusted Tide
	-- Crawler"), as Zygor's action buttons do; the window shows each key after its mob's name
	local function targets(g) return g.targets or { g.target } end
	-- items to use first, but only ones in the bags: an item still to be got ("Use Dark Iron Map", looted from the mobs
	-- the step kills) goes after the targets, so the key for what you do first comes first
	local later = {} ---@type ObviGuideGoal[]
	for _, g in ipairs(step.goals) do
		if g.id and Engine.IsVisible(g) and (g.kind == "use" or (g.kind == "hearth" and not Engine.IsComplete(g, step))) then
			if C_Item.GetItemCount(g.id) > 0 then add("item", g.id, g) else table.insert(later, g) end
		end
	end
	for _, g in ipairs(step.goals) do
		if g.kind == "equip" and g.id and C_Item.GetItemCount(g.id) > 0 and open(g) then add("item", g.id, g) end
	end
	for _, g in ipairs(step.goals) do
		if g.kind == "cast" and g.id and open(g) then add("spell", g.id, g) end
	end
	-- a recipe to make, once it's known (before that, the key talks to the trainer); while the step isn't done
	local _, done = Engine.StepState(step)
	for _, g in ipairs(step.goals) do
		if g.craft and not done and Engine.IsVisible(g) and C_SpellBook.IsSpellKnown(g.craft) then add("craft", g.craft, g) end
	end
	-- the step's own target first (its NPC, or what it kills), then the other things its lines target
	if step.target then
		local line, finished = nil, false
		for _, g in ipairs(step.goals) do
			if g.target and g.target.name == step.target.name and Engine.IsVisible(g) then
				-- a line that's done needs no action any more (its key goes to what's left)
				if open(g) then line = g break end
				finished = true
			end
		end
		if finished and not line then
			-- (nothing: the step's target was its line's, and that line is done)
		elseif line and line.targets and #line.targets > 1 then
			-- its line names several mobs: their actions in the line's order (so the first mob isn't added twice)
			for _, t in ipairs(targets(line)) do add("target", t.name, line, t.enemy) end
		else
			add("target", step.target.name, line, step.target.enemy)
		end
	end
	for _, g in ipairs(step.goals) do
		if g.target and open(g) then
			for _, t in ipairs(targets(g)) do add("target", t.name, g, t.enemy) end
		end
	end
	for _, g in ipairs(later) do add("item", g.id, g) end
	-- a thing in the world to click ("Click the Box of Scrolls"): the key is the game's own Interact, which uses the
	-- object the game highlights nearby. Every reader colours such names the same ("click" purple), so that tells.
	local pick = "|c" .. ns.Colors.PICK
	for _, g in ipairs(step.goals) do
		if g.text and g.text:find(pick, 1, true) and open(g) then add("interact", "interact", g) break end
	end
	-- then the side tasks
	for _, g in ipairs(step.side) do
		if g.kind == "use" and g.id and Engine.IsVisible(g) then add("item", g.id, g)
		elseif g.target and open(g) then
			for _, t in ipairs(targets(g)) do add("target", t.name, g, t.enemy) end
		end
	end
	return list
end

local SetMacro ---@type fun(slot: ObviGuideActionSlot)

local function Apply()
	if InCombatLockdown() then pending = true return end
	pending = false
	local list = Pick()
	for i, slot in ipairs(slots) do
		local b, a = slot.button, list[i]
		slot.current = a
		b:SetAttribute("type", nil)
		b:SetAttribute("item", nil)
		b:SetAttribute("spell", nil)
		b:SetAttribute("macrotext", nil)
		b:SetAttribute("clickbutton", nil)
		crafters[i]["goal"] = nil
		if a and a.kind == "item" then
			b:SetAttribute("type", "item")
			b:SetAttribute("item", "item:" .. a.value)
		elseif a and a.kind == "spell" then
			b:SetAttribute("type", "spell")
			b:SetAttribute("spell", a.value)
		elseif a and a.kind == "craft" then
			-- the window open: make it; else open the window (cast the profession)
			local profession = a.goal and Action.ProfessionSpell(a.goal)
			if a.goal and Action.CraftReady(a.goal) then
				crafters[i]["goal"] = a.goal
				b:SetAttribute("type", "click")
				b:SetAttribute("clickbutton", crafters[i])
			elseif profession then
				b:SetAttribute("type", "spell")
				b:SetAttribute("spell", profession)
			end
		elseif a and a.kind == "interact" then
			-- (nothing to click: the key itself becomes Interact, see Rebind)
		elseif a then
			b:SetAttribute("type", "macro")
		end
		SetMacro(slot)
	end
end

-- The "magic key" part (as Zygor does it): once an action's NPC or mob is targeted, that action's key becomes the
-- game's own "Interact with Target", so the next press talks to the NPC or attacks the mob. Override bindings can't
-- change in combat either; the switch then waits for combat to end.
-- A mob someone else has tagged isn't ours: the key doesn't attack it, and its next press targets the next one of
-- that name instead (see TargetMacro's keep).
---@param a? ObviGuideActionInfo
---@return "ours"|"tagged"|nil
local function TargetMatch(a)
	if not (a and a.kind == "target") then return nil end
	local ok, match = pcall(function()
		if not UnitExists("target") or UnitIsDead("target") then return nil end
		local name = UnitName("target")
		local v, same = a.value, false
		if type(v) == "table" then   -- one action for several mobs: any of them
			for _, n in ipairs(v) do if n == name then same = true end end
		else
			same = name == v
		end
		if not same then return nil end
		return a.enemy and UnitIsTapDenied("target") and "tagged" or "ours"
	end)
	return ok and match or nil
end

---@param slot ObviGuideActionSlot
local function TargetIsOurs(slot)
	return TargetMatch(slot.current) == "ours"
end

-- the target macro of a slot: while its target is tagged by someone else, the next press goes on to the next one
---@param slot ObviGuideActionSlot
function SetMacro(slot)
	local a = slot.current
	if not (a and a.kind == "target") then slot.keep = nil return end
	slot.keep = TargetMatch(a) == "tagged"
	local v = a.value
	slot.button:SetAttribute("macrotext", ns.TargetMacro(type(v) == "table" and v or tostring(v), a.enemy, slot.keep))
end

-- an NPC's dialogue or quest window is open: the key isn't "Interact with Target" meanwhile, since the game takes
-- that key in an open quest window as accepting the quest shown (pressing it again after talking to Mebok Mizzyrix
-- took a quest the guide doesn't do); it comes back when the window closes
local talking = false

function Action.Rebind()
	if InCombatLockdown() then pending = true return end
	local changed = false
	for _, slot in ipairs(slots) do
		-- (a slot picking a dialogue option, or training, keeps that until the window closes, see Gossip and Training
		-- below)
		if slot.current and slot.current.kind == "target" and (TargetMatch(slot.current) == "tagged") ~= slot.keep then
			SetMacro(slot)
			changed = true
		end
		local want = not talking and (TargetIsOurs(slot) or (slot.current ~= nil and slot.current.kind == "interact"))
		if not slot.gossip and not slot.training and want ~= slot.interacting then
			ClearOverrideBindings(slot.button)
			if want then
				for _, key in ipairs({ GetBindingKey(slot.binding) }) do SetOverrideBinding(slot.button, true, key, "INTERACTTARGET") end
			end
			slot.interacting = want
			changed = true
		end
	end
	if changed then ns:Fire("OBVIGUIDE_UPDATE") end
end

--- The key bound to an action, if any.
---@param i? integer   which action (default 1)
---@return string?
function Action.Key(i)
	local key = GetBindingKey(slots[i or 1].binding)
	return key and GetBindingText(key, "KEY_") or nil
end

--- The window's hint next to a line: the key of the action that belongs to it, and what pressing it does now.
---@param goal ObviGuideGoal
---@return string?
function Action.Hint(goal)
	local hints = Action.Hints(goal)
	return hints[1] and hints[1].hint
end

--- Every action key that belongs to a line, with the target it's for (a line naming several mobs has one each).
---@param goal ObviGuideGoal
---@return {name?: string, hint: string}[]
function Action.Hints(goal)
	local out = {}
	-- whether another kill line kills this mob too: the key made for that line shows here as well, after the name
	-- (two lines killing Kurzen Jungle Fighters share its key); a line that only targets it (collecting what it
	-- drops, "Large River Crocolisk Skin") doesn't repeat it
	local function names(name)
		if goal.kind ~= "kill" or not (goal.text and goal.text:find(name, 1, true)) then return false end
		for _, t in ipairs(goal.targets or { goal.target }) do if t.name == name then return true end end
		return false
	end
	-- a "Sell …" line at an open merchant: clicking it sells
	if goal.kind == "sell" then
		if Action.MerchantOpen() then table.insert(out, { hint = "click: sell" }) end
		return out
	end
	-- a "Make …" line says what its next press does: open the profession's window, or make so many (with its key)
	if goal.craft and C_SpellBook.IsSpellKnown(goal.craft) then
		local what = "open"
		if Action.CraftReady(goal) then
			local n = Action.CraftCount(goal)
			what = n == 0 and "made" or ("make " .. (n or "all"))
		end
		local key
		for i, slot in ipairs(slots) do
			if slot.current and slot.current.goal == goal then key = Action.Key(i) break end
		end
		table.insert(out, { hint = key and (key .. ": " .. what) or what })
		return out
	end
	for i, slot in ipairs(slots) do
		local a = slot.current
		local mine = a and (a.goal == goal or (a.kind == "target" and type(a.value) == "string" and names(a.value)))
		local key = mine and Action.Key(i)
		-- (while the key trains, it shows on the line it trains only)
		if a and key and not slot.training then
			local verb = a.kind == "interact" and "interact" or (a.enemy and "attack" or "talk")
			local hint = slot.interacting and (key .. ": " .. verb) or (slot.keep and (key .. ": tagged, next") or key)
			if slot.gossip then hint = key end   -- (the key picks the dialogue option now; that line says so)
			-- a target's key goes after its name in the line's text (several mobs: one key after each)
			local v = a.value
			table.insert(out, { name = a.kind == "target" and type(v) ~= "table" and tostring(v) or nil, hint = hint })
		end
		-- the "Select …" line whose dialogue option the key picks right now
		local pickKey = slot.gossip == goal and Action.Key(i)
		if pickKey then table.insert(out, { hint = pickKey .. ": select" }) end
		-- the "Learn …"/"Train …" line the key trains right now
		local trainKey = slot.training == goal and Action.Key(i)
		if trainKey then table.insert(out, { hint = trainKey .. ": train" }) end
	end
	return out
end

-- Dialogue options: while an NPC's dialogue is open and the step has a "Select …" line with the option's id (Zygor's
-- |gossip), and that very option is offered, the action key that talked to the NPC picks it. Without an id, or when
-- the option isn't there, the key stays as it was. Picking an option needs no secure button: a plain one does it.
local picker = CreateFrame("Button", "ObviGuideGossipButton", UIParent)
picker:Hide()
picker:SetScript("OnClick", function(self)
	local option = self["option"]
	if option then C_GossipInfo.SelectOption(option) end
end)

--- Lets go of a dialogue option: the slot's key goes back to what the step needs.
local function GossipDone()
	if InCombatLockdown() then return end
	local any = false
	for _, slot in ipairs(slots) do
		if slot.gossip then
			ClearOverrideBindings(slot.button)
			slot.gossip, slot.interacting, any = nil, false, true
		end
	end
	picker["option"] = nil
	if any then Action.Rebind() ns:Fire("OBVIGUIDE_UPDATE") end
end

local function Gossip()
	GossipDone()
	if InCombatLockdown() then return end
	local _, step = Engine.Current()
	if not step then return end
	local offered = {}
	for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do if o.gossipOptionID then offered[o.gossipOptionID] = true end end
	local goal
	for _, g in ipairs(step.goals) do
		if g.gossip and offered[g.gossip] and Engine.IsVisible(g) then goal = g break end
	end
	if not goal then return end
	-- the key that talks (a friendly target), else action 1
	local slot = slots[1]
	for _, s in ipairs(slots) do
		if s.current and s.current.kind == "target" and not s.current.enemy then slot = s break end
	end
	local keys = { GetBindingKey(slot.binding) }
	if #keys == 0 then return end
	picker["option"] = goal.gossip
	ClearOverrideBindings(slot.button)
	for _, key in ipairs(keys) do SetOverrideBindingClick(slot.button, true, key, "ObviGuideGossipButton") end
	slot.gossip = goal
	ns:Fire("OBVIGUIDE_UPDATE")
end

ns:On("GOSSIP_SHOW", Gossip)
ns:On("GOSSIP_CLOSED", GossipDone)
-- the professions window opening or closing: a craft line's click and key change (open it / make it)
ns:On("TRADE_SKILL_SHOW", function() ns:Fire("OBVIGUIDE_UPDATE") end)
ns:On("TRADE_SKILL_CLOSE", function() ns:Fire("OBVIGUIDE_UPDATE") end)

-- Crafting: a "Make …" line that names its recipe (`:Crafts`) makes it when clicked, or with its action key. While
-- the profession's window is closed, the press opens it the way the spellbook does, by casting the profession (a
-- secure action: C_TradeSkillUI.OpenTradeSkill from our own code didn't open it on Forever); once it's open and has
-- read its recipes, the press makes what the line asks (or all you can, when that's fewer, or the line gives no count),
-- through the window's own calls as Zygor does, which need no secure button.

--- Whether a line's recipe can be made now: it's known and its profession's window is open, with the recipe in it.
---@param g ObviGuideGoal
---@return boolean
function Action.CraftReady(g)
	if not (g.craft and C_SpellBook.IsSpellKnown(g.craft)) then return false end
	local frame = _G["ProfessionsFrame"]   -- (the professions window, loaded on demand)
	return frame ~= nil and frame:IsShown() and C_TradeSkillUI.IsTradeSkillReady()
		and C_TradeSkillUI.GetRecipeInfo(g.craft) ~= nil
end

--- The spell that opens a craft line's profession (its name, as the spellbook has it), or nil.
---@param g ObviGuideGoal
---@return string?
function Action.ProfessionSpell(g)
	local line = g.craftSkill and ns.Conditions.SkillLine(g.craftSkill)
	if not (line and GetProfessions) then return nil end
	for _, i in pairs({ GetProfessions() }) do
		local name, _, _, _, _, _, skillLine = GetProfessionInfo(i)
		if skillLine == line then return name end
	end
end

--- How many a craft line still needs made: its count, for the skill points its range has left (25 for 105-125, at
--- 115: 13), else its count; nil when it has none (all you can).
---@param g ObviGuideGoal
---@return integer?
function Action.CraftCount(g)
	local n, from, to = g.craftCount, g.craftFrom, g.craftTo
	-- (up to N in your bags: what's still to make)
	if g.craftItem and n then return math.max(0, n - C_Item.GetItemCount(g.craftItem)) end
	if not (n and from and to and to > from and g.craftSkill) then return n end
	local skill = ns.Conditions.Skill(g.craftSkill) or from
	local left = math.min(to - from, math.max(0, to - math.max(skill, from)))
	return math.ceil(n * left / (to - from))
end

--- Makes a line's recipe, when its window is open. Returns whether it did.
---@param g ObviGuideGoal
---@return boolean
function Action.Craft(g)
	if not Action.CraftReady(g) then return false end
	local recipe = g.craft --[[@as integer]]
	local page = _G["ProfessionsFrame"].CraftingPage
	if page and page.SelectRecipe then pcall(page.SelectRecipe, page, C_TradeSkillUI.GetRecipeInfo(recipe)) end
	local can = C_TradeSkillUI.GetCraftableCount(recipe) or 0
	-- (none to make: one, so the game says what's missing)
	local n = Action.CraftCount(g)
	if n == 0 then return true end   -- (nothing left to make)
	C_TradeSkillUI.CraftRecipe(recipe, math.max(1, math.min(n or can, can)))
	return true
end

-- Selling: while a merchant's window is open, clicking a "Sell …" line sells your spare of it (what you have beyond
-- what the guide still needs): whole stacks, smallest first, while they fit in the spare; the rest split off a
-- stack and sold from the cursor.
local merchantOpen = false
ns:On("MERCHANT_SHOW", function() merchantOpen = true ns:Fire("OBVIGUIDE_UPDATE") end)
ns:On("MERCHANT_CLOSED", function() merchantOpen = false ns:Fire("OBVIGUIDE_UPDATE") end)

--- Whether a merchant's window is open.
function Action.MerchantOpen() return merchantOpen end

--- Sells a sell line's spare at the open merchant. Returns how many it sold (nil: no merchant open).
---@param g ObviGuideGoal
---@return integer?
function Action.Sell(g)
	if not (merchantOpen and g.kind == "sell" and g.id) then return nil end
	local spare = C_Item.GetItemCount(g.id) - (g.keep or 0)
	local stacks = {}
	-- the backpack, the four bags and (on a client with one) the reagent bag, where crafting reagents may go
	for bag = 0, _G["NUM_TOTAL_EQUIPPED_BAG_SLOTS"] or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID == g.id and not info.isLocked then
				table.insert(stacks, { bag = bag, slot = slot, count = info.stackCount or 1 })
			end
		end
	end
	table.sort(stacks, function(a, b) return a.count < b.count end)
	local sold, rest = 0, nil
	for _, st in ipairs(stacks) do
		if st.count <= spare - sold then
			C_Container.UseContainerItem(st.bag, st.slot)
			sold = sold + st.count
		else
			rest = rest or st
		end
	end
	-- the rest of the spare shares a stack with what's kept: split it off onto the cursor and sell that
	local left = spare - sold
	if rest and left > 0 and not CursorHasItem() then
		C_Container.SplitContainerItem(rest.bag, rest.slot, left)
		if CursorHasItem() then
			SellCursorItem()
			sold = sold + left
		end
	end
	return sold
end

-- Training: while a trainer's window is open, a "Learn …" line (a recipe, by its spell) or a "Train …" line (a
-- profession, or its next rank) that the trainer offers is trained by clicking it, and the action key that talked to
-- the trainer trains the first one the step still needs, then the next. Buying a trainer's service needs no secure
-- button either. A recipe is found by its spell (the service's tooltip has it), else its name; a rank by its English
-- words, as the trainer lists it ("Journeyman Engineer").
-- On WoW Forever GetTrainerServiceInfo gives the name, then the service's state ("available", "used", ...); the
-- rank text comes fifth (as WhatsTraining reads it).
local RANK = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local trainerOpen = false

--- The open trainer's service for a line, or nil when the trainer doesn't offer it now (or no trainer is open).
---@param g ObviGuideGoal
---@return integer?
function Action.Service(g)
	if not trainerOpen then return nil end
	local spell, name, rank
	if g.kind == "learn" and g.id then
		spell, name = g.id, C_Spell.GetSpellName(g.id)
	elseif g.kind == "skill" and g.skill and (g.cap or g.level == 1) then
		rank = RANK[g.cap or 75]
	end
	if not (spell or rank) then return nil end
	for i = 1, GetNumTrainerServices() do
		local service, state = GetTrainerServiceInfo(i)
		if state == "available" and service then
			if spell then
				-- (the tooltip data's id: the spell, for a spell's service)
				local data = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i) --[[@as table?]]
				if (data and data.id == spell) or service == name then return i end
			elseif service:find(rank, 1, true) and service:find(g.skill:sub(1, 5), 1, true) then
				return i
			end
		end
	end
end

--- Trains a line's service at the open trainer. Returns whether there was one to train.
---@param g ObviGuideGoal
---@return boolean
function Action.Train(g)
	local i = Action.Service(g)
	if i then BuyTrainerService(i) end
	return i ~= nil
end

local trainer = CreateFrame("Button", "ObviGuideTrainButton", UIParent)
trainer:Hide()
trainer:SetScript("OnClick", function(self)
	local g = self["goal"]
	if g then Action.Train(g) end
end)

--- Lets go of training: the slot's key goes back to what the step needs.
local function TrainDone()
	trainer["goal"] = nil
	if InCombatLockdown() then return end
	local any = false
	for _, slot in ipairs(slots) do
		if slot.training then
			ClearOverrideBindings(slot.button)
			slot.training, slot.interacting, any = nil, false, true
		end
	end
	if any then Action.Rebind() ns:Fire("OBVIGUIDE_UPDATE") end
end

--- The first line of the step that the open trainer can train now, onto the key that talked to the trainer.
local function Training()
	if not trainerOpen or InCombatLockdown() then return end
	local _, step = Engine.Current()
	if not step then TrainDone() return end
	local goal
	for _, g in ipairs(step.goals) do
		if Engine.IsVisible(g) and not Engine.IsComplete(g, step) and Action.Service(g) then goal = g break end
	end
	ns.Debug("trainer: %d services; %s", GetNumTrainerServices(), goal and ("trains '" .. goal.text .. "'") or "nothing to train")
	if not goal then TrainDone() return end
	trainer["goal"] = goal
	local slot = slots[1]
	for _, s in ipairs(slots) do
		if s.training then slot = s break end
		if s.current and s.current.kind == "target" and not s.current.enemy then slot = s break end
	end
	if slot.training == goal then return end
	local keys = { GetBindingKey(slot.binding) }
	if #keys == 0 then return end
	ClearOverrideBindings(slot.button)
	for _, key in ipairs(keys) do SetOverrideBindingClick(slot.button, true, key, "ObviGuideTrainButton") end
	slot.training = goal
	ns:Fire("OBVIGUIDE_UPDATE")
end

ns:On("TRAINER_SHOW", function() trainerOpen = true Training() end)
-- after each thing trained (the list changes): on to the next
ns:On("TRAINER_UPDATE", function() Training() end)
ns:On("TRAINER_CLOSED", function() trainerOpen = false TrainDone() end)
-- the guide moved on with the window still open (the step trained all it needed): the next step's lines
ns:On("OBVIGUIDE_STEP", function() if trainerOpen then Training() end end)

ns:On("OBVIGUIDE_STEP", function() Apply() Action.Rebind() end)
ns:On("OBVIGUIDE_UPDATE", function() Apply() Action.Rebind() end)
ns:On("PLAYER_TARGET_CHANGED", function() Action.Rebind() end)
-- the target is tagged (or let go) by someone else while targeted
ns:On("UNIT_FLAGS", function(_, unit) if unit == "target" then Action.Rebind() end end)
for _, event in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
	ns:On(event, function() talking = true Action.Rebind() end)
end
for _, event in ipairs({ "GOSSIP_CLOSED", "QUEST_FINISHED" }) do
	ns:On(event, function() talking = false Action.Rebind() end)
end
ns:On("PLAYER_REGEN_ENABLED", function() if pending then Apply() Action.Rebind() ns:Fire("OBVIGUIDE_UPDATE") end end)
ns:On("UPDATE_BINDINGS", function()
	-- the player changed their keys: the interact overrides must follow the new keys
	if not InCombatLockdown() then
		for _, slot in ipairs(slots) do
			if slot.interacting then ClearOverrideBindings(slot.button) slot.interacting = false end
		end
	end
	ns:Fire("OBVIGUIDE_UPDATE")
end)

-- the other key bindings (Key Bindings > ObviGuide)
_G["BINDING_NAME_OBVIGUIDE_NEXTSTEP"] = "Next step"
_G["BINDING_NAME_OBVIGUIDE_PREVSTEP"] = "Previous step"
_G["BINDING_NAME_OBVIGUIDE_TOGGLE"] = "Show/hide windows"
_G["BINDING_NAME_OBVIGUIDE_PICKER"] = "Choose a guide"
function ObviGuide.NextStep() Engine.Step(1) end
function ObviGuide.PrevStep() Engine.Step(-1) end
function ObviGuide.Toggle() ns.Window.Toggle() end
function ObviGuide.Guides() ns.GuidePicker.Toggle() end

--- Opens a guide (by title or id) in the window at its first step, held there as if chosen with the arrows, and
--- without the ticks of an earlier run. For Obvi Guide: Scribe's Test button.
---@param title string
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.Load(title)
	local g = ns.FindGuide(title)
	if not g then ns.Print("no guide called '%s'", title) return end
	if ns.charDB and ns.charDB.marks then ns.charDB.marks[g.title] = nil end
	Engine.Load(title, 1)
	Engine.GoTo(1)
	ns.Window.Show()
end

--- The guides added this session, in order (a new list of Obvi Guide's own guide tables: read them, don't change
--- them). A guide not opened yet may have no steps until ObviGuide.Read. For Obvi Guide: Scribe's "Open guide".
---@return table[]
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.List()
	local list = {}
	for i, g in ipairs(ns.guides) do list[i] = g end
	return list
end

--- A guide from ObviGuide.List with its steps read (some formats are read only when first used); nil if unreadable.
---@param guide table
---@return table?
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.Read(guide) return ns.Ready(guide) end
