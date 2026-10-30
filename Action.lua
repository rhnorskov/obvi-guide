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
---@field kind "item"|"spell"|"target"|"interact"   interact: the key is the game's Interact (an object to click)
---@field goal? ObviGuideGoal   the line the action belongs to (for the key hint)
---@field value string|integer|string[]   a target: one name, or several (any of them)
---@field enemy? boolean       a target to attack (else to talk to)

---@class ObviGuideActionSlot
---@field button Button
---@field binding string
---@field current? ObviGuideActionInfo
---@field interacting boolean  the key is "Interact with Target" now
---@field gossip? ObviGuideGoal   the "Select …" line whose dialogue option the key picks while the dialogue shows

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
	for _, g in ipairs(step.goals) do
		if g.id and Engine.IsVisible(g) and (g.kind == "use" or (g.kind == "hearth" and not Engine.IsComplete(g, step))) then
			add("item", g.id, g)
		end
	end
	for _, g in ipairs(step.goals) do
		if g.kind == "equip" and g.id and C_Item.GetItemCount(g.id) > 0 and open(g) then add("item", g.id, g) end
	end
	for _, g in ipairs(step.goals) do
		if g.kind == "cast" and g.id and open(g) then add("spell", g.id, g) end
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
		if a and a.kind == "item" then
			b:SetAttribute("type", "item")
			b:SetAttribute("item", "item:" .. a.value)
		elseif a and a.kind == "spell" then
			b:SetAttribute("type", "spell")
			b:SetAttribute("spell", a.value)
		elseif a and a.kind == "interact" then
			-- (nothing to click: the key itself becomes Interact, see Rebind)
		elseif a then
			b:SetAttribute("type", "macro")
			local v = a.value
			b:SetAttribute("macrotext", ns.TargetMacro(type(v) == "table" and v or tostring(v), a.enemy))
		end
	end
end

-- The "magic key" part (as Zygor does it): once an action's NPC or mob is targeted, that action's key becomes the
-- game's own "Interact with Target", so the next press talks to the NPC or attacks the mob. Override bindings can't
-- change in combat either; the switch then waits for combat to end.
---@param slot ObviGuideActionSlot
local function TargetIsOurs(slot)
	local a = slot.current
	if not (a and a.kind == "target") then return false end
	local ok, same = pcall(function()
		if not UnitExists("target") or UnitIsDead("target") then return false end
		local name = UnitName("target")
		local v = a.value
		if type(v) == "table" then   -- one action for several mobs: any of them
			for _, n in ipairs(v) do if n == name then return true end end
			return false
		end
		return name == a.value
	end)
	return ok and same or false
end

function Action.Rebind()
	if InCombatLockdown() then pending = true return end
	local changed = false
	for _, slot in ipairs(slots) do
		-- (a slot picking a dialogue option keeps that until the dialogue closes, see Gossip below)
		local want = TargetIsOurs(slot) or (slot.current ~= nil and slot.current.kind == "interact")
		if not slot.gossip and want ~= slot.interacting then
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
	for i, slot in ipairs(slots) do
		local a = slot.current
		local key = a and a.goal == goal and Action.Key(i)
		if a and key then
			local verb = a.kind == "interact" and "interact" or (a.enemy and "attack" or "talk")
			local hint = slot.interacting and (key .. ": " .. verb) or key
			if slot.gossip then hint = key end   -- (the key picks the dialogue option now; that line says so)
			-- a target's key goes after its name in the line's text (several mobs: one key after each)
			local v = a.value
			table.insert(out, { name = a.kind == "target" and type(v) ~= "table" and tostring(v) or nil, hint = hint })
		end
		-- the "Select …" line whose dialogue option the key picks right now
		local pickKey = slot.gossip == goal and Action.Key(i)
		if pickKey then table.insert(out, { hint = pickKey .. ": select" }) end
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

ns:On("OBVIGUIDE_STEP", function() Apply() Action.Rebind() end)
ns:On("OBVIGUIDE_UPDATE", function() Apply() Action.Rebind() end)
ns:On("PLAYER_TARGET_CHANGED", function() Action.Rebind() end)
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
_G["BINDING_NAME_OBVIGUIDE_TOGGLE"] = "Show/hide window"
_G["BINDING_NAME_OBVIGUIDE_PICKER"] = "Choose a guide"
function ObviGuide.NextStep() Engine.Step(1) end
function ObviGuide.PrevStep() Engine.Step(-1) end
function ObviGuide.Toggle() ns.Window.Toggle() end
function ObviGuide.Guides() ns.GuidePicker.Toggle() end
