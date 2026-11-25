-- Auctionator shopping lists: a step whose Collect lines are still short offers a link under the last of them that
-- makes an Auctionator shopping list of what's missing (each item by its exact name, with how many). The list is named
-- after the guide and replaced each time, so a guide has one. At the auction house Auctionator searches it right away.
-- Shown only while Auctionator is loaded. Left out: a quest's items (the auction house doesn't have those) and things
-- vendors sell (a line that says where to buy it).
local _, ns = ...
---@cast ns ObviGuideNS

local Engine = ns.Engine

---@class ObviGuideShopping
local Shopping = {}
ns.Shopping = Shopping

local CALLER = "Obvi Guide"   -- who Auctionator's API is told is calling (its errors name it)

---@class ObviGuideShopLink : Button
---@field text FontString
---@field step? ObviGuideStep   the step it makes the list for

--- Auctionator's API, while it's loaded.
local function API()
	local a = _G["Auctionator"]
	local v1 = type(a) == "table" and type(a.API) == "table" and a.API.v1
	if type(v1) == "table" and v1.CreateShoppingList and v1.ConvertToSearchString then return v1 end
end

--- Whether a line is something to buy at the auction house: an item to collect that isn't for a quest, and that no
--- vendor sells.
---@param g ObviGuideGoal
---@return boolean
local function Buyable(g)
	if not (g.kind == "collect" and g.id ~= nil and g.quest == nil and g.objective == nil and g.places == nil) then
		return false
	end
	-- nor what can't be on the auction house: bound when picked up, a quest's item (Gnomeregan's punch cards)
	local _, _, _, _, _, _, _, _, _, _, _, classID, _, bindType = C_Item.GetItemInfo(g.id)
	return not (bindType == 1 or bindType == 4 or classID == 12)
end

--- An item's name as the auction house has it (the game's, in the player's language), else as the guide writes it.
---@param g ObviGuideGoal
---@return string?
local function ItemName(g)
	local name = C_Item.GetItemInfo(g.id)
	if name and name ~= "" then return name end
	local written = g.text:match("%[(.-)%]")
	return written and (written:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or nil
end

--- What a step still needs from the auction house, in its lines' order: each item once, with how many are missing.
---@param step ObviGuideStep
---@return {name: string, count: integer}[]
function Shopping.List(step)
	local out, by = {}, {}
	for _, g in ipairs(step.goals) do
		if Buyable(g) and Engine.IsVisible(g) and not Engine.IsComplete(g, step) then
			local short = Engine.Need(g) - C_Item.GetItemCount(g.id)
			local name = short > 0 and ItemName(g)
			if name then
				if by[g.id] then
					by[g.id].count = math.max(by[g.id].count, short)
				else
					by[g.id] = { name = name, count = short }
					table.insert(out, by[g.id])
				end
			end
		end
	end
	return out
end

--- The line a step's link goes under (its last line to buy at the auction house) while anything is missing, else nil.
---@param step ObviGuideStep
---@return ObviGuideGoal?
function Shopping.Offer(step)
	if not API() or #Shopping.List(step) == 0 then return nil end
	local last
	for _, g in ipairs(step.goals) do if Buyable(g) and Engine.IsVisible(g) then last = g end end
	return last
end

--- Makes the guide's Auctionator shopping list (replacing it) of what the step still needs, and says so in chat.
---@param step ObviGuideStep
function Shopping.Export(step)
	local api, list = API(), Shopping.List(step)
	if not api or #list == 0 then return end
	local guide = Engine.GuideOf(step)
	local name = ("Obvi Guide: %s"):format(guide and guide.title or "shopping"):gsub("%^", "")   -- (^ splits lists)
	local said = {}
	local ok, err = pcall(function()
		local terms = {}
		for _, x in ipairs(list) do
			table.insert(terms, api.ConvertToSearchString(CALLER, { searchString = x.name, isExact = true, quantity = x.count }))
			table.insert(said, ("%d %s"):format(x.count, x.name))
		end
		api.CreateShoppingList(CALLER, name, terms)
	end)
	if not ok then
		ns.Print("Auctionator couldn't make the shopping list: %s", tostring(err))
		return
	end
	ns.Print("Auctionator shopping list |cffffd100%s|r: %s.", name, table.concat(said, ", "))
end

--- The link a guide window shows under a step's last line to buy; clicking it makes the shopping list.
---@param parent Frame
---@return ObviGuideShopLink
function Shopping.NewLink(parent)
	local b = CreateFrame("Button", nil, parent) --[[@as ObviGuideShopLink]]
	b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.text:SetPoint("TOPLEFT")
	b.text:SetText("|cffffd100Auctionator shopping list|r")
	b:SetSize(b.text:GetStringWidth(), b.text:GetStringHeight())
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", -3, 2)
	hl:SetPoint("BOTTOMRIGHT", 3, -2)
	hl:SetColorTexture(1, 1, 1, 0.06)
	b:SetScript("OnClick", function(self) if self.step then Shopping.Export(self.step) end end)
	-- hovering it lists what goes on the list
	b:SetScript("OnEnter", function(self)
		if not self.step then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("|cffffd100Click|r to make an Auctionator shopping list of what's missing:")
		for _, x in ipairs(Shopping.List(self.step)) do GameTooltip:AddLine(("%d %s"):format(x.count, x.name), 1, 1, 1) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	return b
end
