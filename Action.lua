-- Actions: keybindable actions for the current step, like Zygor's action buttons but without a bar. Hidden secure
-- buttons each do one thing the step (or its side tasks) needs: use an item, cast a spell, or target an NPC or mob.
-- Action 1 is the step's main action; actions 2-4 take the step's other targets and items, then the side tasks.
-- Bind them in Key Bindings > AnyGuide. Secure buttons can't change in combat, so a step change during a fight takes
-- effect when combat ends.
local _, ns = ...
---@cast ns AnyGuideNS

local Engine = ns.Engine

---@class AnyGuideAction
local Action = {}
ns.Action = Action

local COUNT = 4

---@class AnyGuideActionInfo
---@field kind "item"|"spell"|"target"
---@field goal? AnyGuideGoal   the line the action belongs to (for the key hint)
---@field value string|integer
---@field enemy? boolean       a target to attack (else to talk to)

---@class AnyGuideActionSlot
---@field button Button
---@field binding string
---@field current? AnyGuideActionInfo
---@field interacting boolean  the key is "Interact with Target" now

local slots = {} ---@type AnyGuideActionSlot[]
for i = 1, COUNT do
	-- action 1 keeps its first name, so a key bound before there were more stays bound
	local name = i == 1 and "AnyGuideActionButton" or "AnyGuideActionButton" .. i
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate") --[[@as Button]]
	button:SetSize(1, 1)
	button:SetAlpha(0)
	button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
	button:RegisterForClicks("AnyDown", "AnyUp")
	local binding = "CLICK " .. name .. ":LeftButton"
	-- the names Key Bindings shows (FrameXML globals)
	_G["BINDING_NAME_" .. binding] = i == 1 and "Step action" or ("Step action " .. i)
	slots[i] = { button = button, binding = binding, interacting = false }
end

local pending = false

--- The step's actions, most important first: its items, equipment, spells and targets, then its side tasks'.
---@return AnyGuideActionInfo[]
local function Pick()
	local _, step = Engine.Current()
	if not step then return {} end
	local list, seen = {}, {}
	local function add(kind, value, goal, enemy)
		local key = kind .. ":" .. tostring(value)
		if seen[key] or #list >= COUNT then return end
		seen[key] = true
		table.insert(list, { kind = kind, value = value, goal = goal, enemy = enemy })
	end
	local function open(g) return Engine.IsVisible(g) and not Engine.IsComplete(g, step) end
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
		local line
		for _, g in ipairs(step.goals) do
			if g.target and g.target.name == step.target.name and Engine.IsVisible(g) then line = g break end
		end
		add("target", step.target.name, line, step.target.enemy)
	end
	for _, g in ipairs(step.goals) do
		if g.target and open(g) then add("target", g.target.name, g, g.target.enemy) end
	end
	-- then the side tasks
	for _, g in ipairs(step.side) do
		if g.kind == "use" and g.id and Engine.IsVisible(g) then add("item", g.id, g)
		elseif g.target and open(g) then add("target", g.target.name, g, g.target.enemy) end
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
		elseif a then
			b:SetAttribute("type", "macro")
			b:SetAttribute("macrotext", ns.TargetMacro(tostring(a.value), a.enemy))
		end
	end
end

-- The "magic key" part (as Zygor does it): once an action's NPC or mob is targeted, that action's key becomes the
-- game's own "Interact with Target", so the next press talks to the NPC or attacks the mob. Override bindings can't
-- change in combat either; the switch then waits for combat to end.
---@param slot AnyGuideActionSlot
local function TargetIsOurs(slot)
	local a = slot.current
	if not (a and a.kind == "target") then return false end
	local ok, same = pcall(function()
		return UnitExists("target") and not UnitIsDead("target") and UnitName("target") == a.value
	end)
	return ok and same or false
end

function Action.Rebind()
	if InCombatLockdown() then pending = true return end
	local changed = false
	for _, slot in ipairs(slots) do
		local want = TargetIsOurs(slot)
		if want ~= slot.interacting then
			ClearOverrideBindings(slot.button)
			if want then
				for _, key in ipairs({ GetBindingKey(slot.binding) }) do SetOverrideBinding(slot.button, true, key, "INTERACTTARGET") end
			end
			slot.interacting = want
			changed = true
		end
	end
	if changed then ns:Fire("ANYGUIDE_UPDATE") end
end

--- The key bound to an action, if any.
---@param i? integer   which action (default 1)
---@return string?
function Action.Key(i)
	local key = GetBindingKey(slots[i or 1].binding)
	return key and GetBindingText(key, "KEY_") or nil
end

--- The window's hint next to a line: the key of the action that belongs to it, and what pressing it does now.
---@param goal AnyGuideGoal
---@return string?
function Action.Hint(goal)
	for i, slot in ipairs(slots) do
		if slot.current and slot.current.goal == goal then
			local key = Action.Key(i)
			if not key then return nil end
			if slot.interacting then return key .. ": " .. (slot.current.enemy and "attack" or "talk") end
			return key
		end
	end
end

ns:On("ANYGUIDE_STEP", function() Apply() Action.Rebind() end)
ns:On("ANYGUIDE_UPDATE", function() Apply() Action.Rebind() end)
ns:On("PLAYER_TARGET_CHANGED", function() Action.Rebind() end)
ns:On("PLAYER_REGEN_ENABLED", function() if pending then Apply() Action.Rebind() ns:Fire("ANYGUIDE_UPDATE") end end)
ns:On("UPDATE_BINDINGS", function()
	-- the player changed their keys: the interact overrides must follow the new keys
	if not InCombatLockdown() then
		for _, slot in ipairs(slots) do
			if slot.interacting then ClearOverrideBindings(slot.button) slot.interacting = false end
		end
	end
	ns:Fire("ANYGUIDE_UPDATE")
end)

-- the other key bindings (Key Bindings > AnyGuide)
_G["BINDING_NAME_ANYGUIDE_NEXTSTEP"] = "Next step"
_G["BINDING_NAME_ANYGUIDE_PREVSTEP"] = "Previous step"
_G["BINDING_NAME_ANYGUIDE_TOGGLE"] = "Show/hide window"
function AnyGuide.NextStep() Engine.Step(1) end
function AnyGuide.PrevStep() Engine.Step(-1) end
function AnyGuide.Toggle() ns.Window.Toggle() end
