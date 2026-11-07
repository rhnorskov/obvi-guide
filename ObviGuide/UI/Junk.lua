-- Destroy the cheapest item: for full bags. Finds the bag item worth the least at a vendor (the whole stack's price)
-- and asks before destroying it; grey items first. Leaves alone what can't be sold (quest items, hearthstone,
-- keys...), tools (Blacksmith Hammer, Mining Pick, fishing poles...) and the items the loaded guide still uses or
-- collects. The key binding (Key Bindings > Obvi Guide), the window's gear menu, or
-- "/og junk"; Enter in the question destroys it.
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

--- The item ids the loaded guide's lines still use, collect or equip, from the current step on.
---@return table<integer, boolean>
local function GuideItems()
	local keep = {}
	local guide, step = Engine.Current()
	if not guide then return keep end
	for i = step and step.index or 1, #guide.steps do
		local s = guide.steps[i]
		for _, list in ipairs({ s.goals, s.side }) do
			for _, g in ipairs(list) do
				local k = g.kind
				if g.id and (k == "use" or k == "collect" or k == "equip") then keep[g.id] = true end
			end
		end
	end
	return keep
end

-- tools: cheap at a vendor, but needed in the bags (professions, fishing, lockpicking, fire)
local TOOLS = {
	[2901] = true,    -- Mining Pick
	[5956] = true,    -- Blacksmith Hammer
	[7005] = true,    -- Skinning Knife
	[6219] = true,    -- Arclight Spanner
	[10498] = true,   -- Gyromatic Micro-Adjustor
	[9149] = true,    -- Philosopher's Stone
	[4471] = true,    -- Flint and Tinder
	[5060] = true,    -- Thieves' Tools
	[6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true,   -- the runed enchanting rods
	[6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true,   -- fishing poles
}

---@class ObviGuideJunk
---@field bag integer
---@field slot integer
---@field link string
---@field count integer
---@field value integer    the stack's vendor price, in copper
---@field quality integer

--- The bag slot with the cheapest item that can be sold (nil if none). Grey items come first, whatever they're worth.
---@return ObviGuideJunk?
local function Cheapest()
	local keep = GuideItems()
	local best ---@type ObviGuideJunk?
	for bag = 0, 4 do   -- the backpack and the four bags
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and not keep[info.itemID] and not TOOLS[info.itemID] and not info.isLocked then
				local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
				local price = select(11, C_Item.GetItemInfo(info.itemID))
				if price and price > 0 and not (quest and (quest.isQuestItem or quest.questID)) then
					local value = price * (info.stackCount or 1)
					local quality = info.quality or 1
					local grey, bestGrey = quality == 0, best and best.quality == 0
					if not best or (grey and not bestGrey)
						or (grey == bestGrey and (value < best.value or (value == best.value and quality < best.quality))) then
						best = { bag = bag, slot = slot, link = info.hyperlink, count = info.stackCount or 1, value = value,
							quality = quality }
					end
				end
			end
		end
	end
	return best
end

local POPUP = "OBVIGUIDE_DESTROY_CHEAPEST"
local StaticPopupDialogs = _G["StaticPopupDialogs"] ---@type table
local StaticPopup_Show = _G["StaticPopup_Show"] ---@type fun(which: string, a?: string, b?: string, data?: any): Frame?

StaticPopupDialogs[POPUP] = {
	text = "Destroy %s?\n(sells for %s)",
	button1 = "Destroy",
	button2 = "Cancel",
	OnAccept = function(_, data)
		-- only if that slot still holds the same item (the bags may have changed since the question)
		local info = C_Container.GetContainerItemInfo(data.bag, data.slot)
		if not info or info.hyperlink ~= data.link then ns.Print("your bags changed: nothing destroyed") return end
		ClearCursor()
		C_Container.PickupContainerItem(data.bag, data.slot)
		if CursorHasItem() then
			DeleteCursorItem()
			ns.Print("destroyed %s", data.link)
		end
	end,
	enterClicksFirstButton = true,
	hideOnEscape = true,
	timeout = 0,
	whileDead = true,
}

--- Asks to destroy the cheapest item in the bags.
function ns.DestroyCheapest()
	local junk = Cheapest()
	if not junk then ns.Print("nothing in your bags to destroy (only items a vendor buys, and not the guide's)") return end
	local name = junk.count > 1 and (junk.link .. " x" .. junk.count) or junk.link
	StaticPopup_Show(POPUP, name, C_CurrencyInfo.GetCoinTextureString(junk.value), junk)
end

_G["BINDING_NAME_OBVIGUIDE_DESTROYCHEAPEST"] = "Destroy the cheapest item"
function ObviGuide.DestroyCheapest() ns.DestroyCheapest() end
