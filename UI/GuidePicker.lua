-- Guide picker: the loaded guides by their folders in columns, as the Mac's Finder shows them: the top folders (and
-- "Recent", the guides opened last) in the first, what's in the chosen folder in the next, and so on; as many of the
-- last levels as columns fit, with the path above them to step back. The window can be resized (the corner grip). It opens at the current guide's folder. Typing swaps the
-- columns for one list of the guides found: every word must be in the guide's title or folder. Clicking the window's
-- title, "/og guides" or its key opens it. Only the rows on screen are drawn (the game's scroll box), so it copes
-- with thousands of guides.
-- The search also finds guides by the quests and NPCs in them ("In guides"): the first time the picker opens, it
-- gathers their names in the background, a few milliseconds a frame.
local _, ns = ...
---@cast ns ObviGuideNS

---@class ObviGuidePicker
local Picker = {}
ns.GuidePicker = Picker

local RECENT = 5        -- guides kept under "Recent"
local MIN_PANE = 220    -- a column's least width, its scroll bar in it: as many columns as fit, sharing the width
local WIDTH, HEIGHT = 880, 620   -- the window's size at first
local MIN_W, MIN_H = 560, 400    -- and how far it can be resized
local MAX_W, MAX_H = 1600, 1000
local ICON = 16
local DEBOUNCE = 0.15   -- seconds after the last key before the list filters
local NAME_ROWS = 200   -- guides listed under "In guides" at most
local BUDGET = 4        -- milliseconds a frame for gathering the names

-- The list's model: pure functions on plain tables (no game calls), so they can be tested outside the game.

---@class ObviGuideFolder
---@field path string             "Zygor: Leveling Guides\Starter Guides"
---@field name string             its last part, "Starter Guides"
---@field depth integer           0 for a top folder (-1 for the root)
---@field parent? ObviGuideFolder
---@field items (ObviGuideFolder|ObviGuideGuide)[]   subfolders and guides, in the order first added
---@field count integer           the guides inside it, subfolders too

---@class ObviGuideTree
---@field root ObviGuideFolder
---@field folders table<string, ObviGuideFolder>   by path
---@field byName table<string, ObviGuideGuide>     by name and by title (the first one with it)
---@field hay table<ObviGuideGuide, string>        "folder\title" in lower case, what the search looks in
---@field list ObviGuideGuide[]                    the guides in it, in the order added

---@class ObviGuideNames
---@field text string   the guide's quest and NPC names, one per line
---@field low string    the same in lower case (same length: the positions match)

---@class ObviGuidePickerRow
---@field kind "header"|"group"|"guide"|"more"   (more: "...and 12 more", not clickable)
---@field text string
---@field note? string    after the title, in grey: the guide's folder in the search, or the quest or NPC it was found by
---@field depth integer
---@field folder? ObviGuideFolder
---@field path? string    a column's folder: its path (Picker.RECENT for "Recent")
---@field guide? ObviGuideGuide
---@field count? integer
---@field open? boolean   a folder showing what's in it
---@field level? integer      the column it is in (the picker sets it)
---@field selected? boolean   a folder chosen, its guides in the next column (the picker sets it)

--- The folder tree of the guides the filter lets through (the guide list as the menu used to show it).
---@param guides ObviGuideGuide[]
---@param visible? fun(g: ObviGuideGuide): boolean
---@return ObviGuideTree
function Picker.Tree(guides, visible)
	local root = { path = "", name = "", depth = -1, items = {}, count = 0 } ---@type ObviGuideFolder
	local folders, byName, hay, list = { [""] = root }, {}, {}, {}
	local function Folder(path)
		local f = folders[path]
		if f then return f end
		local parent, last = path:match("^(.*)\\([^\\]+)$")
		local up = Folder(parent or "")
		f = { path = path, name = last or path, depth = up.depth + 1, parent = up, items = {}, count = 0 }
		table.insert(up.items, f)
		folders[path] = f
		return f
	end
	for _, g in ipairs(guides) do
		if not visible or visible(g) then
			local f = Folder(g.group or "")
			table.insert(f.items, g)
			local up = f ---@type ObviGuideFolder?
			while up do up.count = up.count + 1 up = up.parent end
			if g.name and not byName[g.name] then byName[g.name] = g end
			if not byName[g.title] then byName[g.title] = g end
			hay[g] = ((g.group or "") .. "\\" .. g.title):lower()
			list[#list + 1] = g
		end
	end
	return { root = root, folders = folders, byName = byName, hay = hay, list = list }
end

--- The search words, in lower case.
---@param text string?
---@return string[]
function Picker.Words(text)
	local words = {}
	for w in (text or ""):lower():gmatch("%S+") do table.insert(words, w) end
	return words
end

--- "A", "A\B", "A\B\C" for "A\B\C": the folders to choose, column by column, to show a guide in it.
---@param path string
---@return string[]
function Picker.Ancestors(path)
	local out, at = {}, 1
	while true do
		local s = path:find("\\", at, true)
		if not s then break end
		table.insert(out, path:sub(1, s - 1))
		at = s + 1
	end
	if path ~= "" then table.insert(out, path) end
	return out
end

--- The guides as a tree of rows. Not searching: "Recent", then the folders, unfolded where `open` says so.
--- Searching: only the guides every word is found in (title or folder), under their folders, all unfolded; then,
--- under "In guides", the other guides with a quest or NPC that has every word in its name. (The picker shows the
--- search through Results.)
---@param tree ObviGuideTree
---@param open table<string, boolean>   unfolded folders, by path
---@param words string[]
---@param recent? string[]               names (or titles) of the guides opened last, newest first
---@param names? table<ObviGuideGuide, ObviGuideNames>   the guides' quest and NPC names, as far as gathered
---@return ObviGuidePickerRow[]
function Picker.Rows(tree, open, words, recent, names)
	local rows = {} ---@type ObviGuidePickerRow[]
	local searching = #words > 0
	local nWords = #words
	if not searching and recent and #recent > 0 then
		rows[1] = { kind = "header", text = "Recent", depth = 0 }
		for _, key in ipairs(recent) do
			local g = tree.byName[key]
			if g then rows[#rows + 1] = { kind = "guide", guide = g, text = g.title, depth = 0 } end
		end
		if #rows == 1 then rows[1] = nil else rows[#rows + 1] = { kind = "header", text = "All guides", depth = 0 } end
	end
	local hay = tree.hay
	local listed = {} ---@type table<ObviGuideGuide, boolean>
	-- returns how many guides it listed
	local function Walk(folder)
		local found = 0
		for _, item in ipairs(folder.items) do
			if item.items then
				---@cast item ObviGuideFolder
				if searching then
					local at = #rows + 1
					local row = { kind = "group", folder = item, text = item.name, depth = item.depth, open = true }
					rows[at] = row
					local n = Walk(item)
					-- nothing in it matched: no row for the folder either (nothing was added after it)
					if n == 0 then rows[at] = nil else row.count = n found = found + n end
				else
					local isOpen = open[item.path] == true
					rows[#rows + 1] = { kind = "group", folder = item, text = item.name, depth = item.depth, open = isOpen, count = item.count }
					if isOpen then Walk(item) end
				end
			else
				---@cast item ObviGuideGuide
				local ok = true
				if searching then
					local h = hay[item]
					for i = 1, nWords do
						if not h:find(words[i], 1, true) then ok = false break end
					end
				end
				if ok then
					rows[#rows + 1] = { kind = "guide", guide = item, text = item.title, depth = folder.depth + 1 }
					found = found + 1
					listed[item] = true
				end
			end
		end
		return found
	end
	Walk(tree.root)
	-- (a word of one or two letters alone is in too many names to be of use)
	local long = false
	for i = 1, nWords do if #words[i] >= 3 then long = true break end end
	if names and long then
		local at, more = #rows + 1, 0
		for _, g in ipairs(tree.list) do
			local entry = not listed[g] and names[g]
			local name = entry and Picker.FindName(entry, words)
			if name then
				if #rows - at + 1 < NAME_ROWS then
					rows[#rows + 1] = { kind = "guide", guide = g, text = g.title, note = name, depth = 0 }
				else
					more = more + 1
				end
			end
		end
		if #rows >= at then table.insert(rows, at, { kind = "header", text = "In guides", depth = 0 }) end
		if more > 0 then rows[#rows + 1] = { kind = "more", text = ("...and %d more"):format(more), depth = 0 } end
	end
	return rows
end

-- the path of the "Recent" column (no folder is called this)
Picker.RECENT = "\1recent"

--- What a column shows for a folder ("" the top, Picker.RECENT the guides opened last): its folders first, then its
--- guides, each in the order added. The top starts with "Recent", while there are any.
---@param tree ObviGuideTree
---@param path string
---@param recent? string[]   names (or titles) of the guides opened last, newest first
---@return ObviGuidePickerRow[]
function Picker.Children(tree, path, recent)
	local rows = {} ---@type ObviGuidePickerRow[]
	if path == Picker.RECENT then
		local seen = {} ---@type table<ObviGuideGuide, boolean>
		for _, key in ipairs(recent or {}) do
			local g = tree.byName[key]
			if g and not seen[g] then
				seen[g] = true
				rows[#rows + 1] = { kind = "guide", guide = g, text = g.title, depth = 0 }
			end
		end
		return rows
	end
	local folder = tree.folders[path]
	if not folder then return rows end
	if path == "" then
		local n = #Picker.Children(tree, Picker.RECENT, recent)
		if n > 0 then rows[1] = { kind = "group", path = Picker.RECENT, text = "Recent", count = n, depth = 0 } end
	end
	for _, item in ipairs(folder.items) do
		if item.items then
			---@cast item ObviGuideFolder
			rows[#rows + 1] = { kind = "group", folder = item, path = item.path, text = item.name, count = item.count, depth = 0 }
		end
	end
	for _, item in ipairs(folder.items) do
		if not item.items then
			---@cast item ObviGuideGuide
			rows[#rows + 1] = { kind = "guide", guide = item, text = item.title, depth = 0 }
		end
	end
	return rows
end

--- The search as one list: the guides found by title or folder, each with its folder after it; then "In guides",
--- those found by a quest or NPC in them. The same finds as Rows, without the folder rows.
---@param tree ObviGuideTree
---@param words string[]
---@param names? table<ObviGuideGuide, ObviGuideNames>
---@return ObviGuidePickerRow[]
function Picker.Results(tree, words, names)
	local out = {} ---@type ObviGuidePickerRow[]
	local where = {} ---@type table<string, string>   "A / B" for "A\B", once a folder
	for _, row in ipairs(Picker.Rows(tree, {}, words, nil, names)) do
		if row.kind ~= "group" then
			local group = row.guide and row.guide.group
			if not row.note and group and group ~= "" then
				where[group] = where[group] or (group:gsub("\\", " / "))
				row.note = where[group]
			end
			row.depth = 0
			out[#out + 1] = row
		end
	end
	return out
end

--- The first of a guide's names that has every word in it (words in lower case), or nil.
---@param entry ObviGuideNames
---@param words string[]
---@return string?
function Picker.FindName(entry, words)
	local low = entry.low
	-- every word somewhere first: most guides are ruled out by this alone
	for i = 1, #words do if not low:find(words[i], 1, true) then return nil end end
	local first, from = words[1], 1
	while true do
		local p = low:find(first, from, true)
		if not p then return nil end
		-- the name (line) it is in: s..e-1
		local s = p
		while s > 1 and low:byte(s - 1) ~= 10 do s = s - 1 end
		local e = low:find("\n", p, true) or #low + 1
		local all = true
		for i = 2, #words do
			local q = low:find(words[i], s, true)
			if not q or q + #words[i] > e then all = false break end
		end
		if all then return entry.text:sub(s, e - 1) end
		from = e + 1
	end
end

--- Text without colour codes and icons.
---@param s string
---@return string
local function Plain(s)
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("%s+", " ")
	return (s:gsub("^ ", ""):gsub(" $", ""))
end

--- A guide's quest and NPC names. A guide read already: from its accept, turn-in and talk lines. One not read yet:
--- from its text, if its format can pick them out cheaply (Names); otherwise it has none.
---@param g ObviGuideGuide
---@return ObviGuideNames
function Picker.Names(g)
	local list, seen = {}, {}
	local function Add(name)
		name = Plain(name)
		local low = name:lower()
		if name ~= "" and not seen[low] then seen[low] = true list[#list + 1] = name end
	end
	local p = g.pending
	if p then
		local parser = ns.Parsers[g.format]
		if parser and parser.Names then
			local text = p.text
			if type(text) == "function" then text = text() end
			if type(text) == "string" then for _, n in ipairs(parser.Names(text)) do Add(n) end end
		end
	else
		for _, step in ipairs(g.steps or {}) do
			for _, goals in ipairs({ step.goals, step.side }) do
				for _, goal in ipairs(goals or {}) do
					local kind = goal.kind
					if kind == "accept" or kind == "turnin" then
						-- the line says "Accept <title>" (RestedXP's may say more, or only "Accept quest 123")
						local title = Plain(goal.text):gsub("^Accept%s+", ""):gsub("^Turn in%s+", "")
						if not title:find("^quest %d+$") then Add(title) end
					elseif kind == "talk" then
						Add(goal.target and goal.target.name or (Plain(goal.text):gsub("^Talk to%s+", "")))
					end
				end
			end
		end
	end
	local text = table.concat(list, "\n")
	return { text = text, low = text:lower() }
end

--- A coroutine that gathers the names of the guides not in `names` yet (and of any added meanwhile). It yields when
--- a frame's share of time is used up, with how far it got (0..1); resume it once a frame.
---@param guides ObviGuideGuide[]
---@param names table<ObviGuideGuide, ObviGuideNames>
---@param clock fun(): number   milliseconds
---@param budget number         milliseconds a frame
---@return thread
function Picker.Indexer(guides, names, clock, budget)
	local none = { text = "", low = "" } ---@type ObviGuideNames
	return coroutine.create(function()
		while true do
			local todo = {}
			for _, g in ipairs(guides) do if not names[g] then todo[#todo + 1] = g end end
			if #todo == 0 then return end
			local start = clock()
			for i, g in ipairs(todo) do
				-- a guide whose text can't be had has no names
				local ok, entry = pcall(Picker.Names, g)
				names[g] = ok and entry or none
				if clock() - start > budget then
					coroutine.yield(i / #todo)
					start = clock()
				end
			end
		end
	end)
end

--- Puts a guide first in the recent list (once), keeping the newest `max`.
---@param list string[]
---@param key string
---@param max integer
function Picker.Remember(list, key, max)
	for i = #list, 1, -1 do if list[i] == key then table.remove(list, i) end end
	table.insert(list, 1, key)
	for i = #list, max + 1, -1 do list[i] = nil end
end

--- How many columns fit in a width, each at least `min` wide with a 1-pixel line between two (but at least 2), and
--- how wide each is then: they share the width.
---@param width number
---@param min number
---@return integer count
---@return number each
function Picker.Fit(width, min)
	local n = math.max(2, math.floor((width + 1) / (min + 1)))
	return n, (width - (n - 1)) / n
end

-- The popup.

-- FrameXML globals the annotations do not declare
local ScrollUtil = _G["ScrollUtil"] ---@type table
local CreateDataProvider = _G["CreateDataProvider"] ---@type fun(t: table): table
local CreateScrollBoxListLinearView = _G["CreateScrollBoxListLinearView"] ---@type fun(): table

-- The look is the game's quest log (the list beside the world map): its background and gold frame, folders as its
-- zone headers (a bronze bar), guides as its quest titles (yellow, a soft glow under the mouse, the one followed
-- checked). Its art is atlases; one a client lacks falls back to a plain texture or nothing, never to a green box.

-- row heights by kind
local EXTENT = { header = 30, group = 26, guide = 22, more = 20 }
local TOP = 92      -- the list panel's top, below the title, the search box and the path
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"   -- a small arrow where the client lacks the atlas

local hasAtlas = {} ---@type table<string, boolean>

--- Whether the client has this atlas (remembered).
---@param name string
---@return boolean
local function HasAtlas(name)
	local known = hasAtlas[name]
	if known == nil then
		known = C_Texture.GetAtlasInfo(name) ~= nil
		hasAtlas[name] = known
	end
	return known
end

--- Puts an atlas on a texture. A client without it gets `fallback`: a texture file, a colour {r, g, b, a}, or
--- nothing.
---@param tex Texture
---@param atlas string
---@param useSize? boolean   the atlas's own size
---@param fallback? string|number[]
---@return boolean   whether it had the atlas
local function Art(tex, atlas, useSize, fallback)
	if HasAtlas(atlas) then
		tex:SetAtlas(atlas, useSize)
		return true
	end
	if type(fallback) == "string" then
		tex:SetTexture(fallback)
	elseif type(fallback) == "table" then
		tex:SetColorTexture(fallback[1], fallback[2], fallback[3], fallback[4] or 1)
	else
		tex:SetTexture(nil)
	end
	return false
end

--- The modern menu's thin chevron (where the client lacks it, the old arrow), `height` high and gold.
---@param tex Texture
---@param height number
local function Chevron(tex, height)
	for _, atlas in ipairs({ "common-dropdown-icon-next", "common-icon-forwardarrow" }) do
		if HasAtlas(atlas) then
			tex:SetAtlas(atlas)
			-- its own shape, scaled to the height
			local info = C_Texture.GetAtlasInfo(atlas)
			tex:SetSize(info and info.height > 0 and height * info.width / info.height or height, height)
			tex:SetDesaturated(true)
			tex:SetVertexColor(NORMAL_FONT_COLOR:GetRGB())
			return
		end
	end
	tex:SetTexture(ARROW)
	tex:SetSize(height, height)
end

---@class ObviGuidePickerButton : Button
---@field icon Texture        a guide's questline mark
---@field label FontString
---@field count FontString    a folder's guides
---@field arrow Texture       a folder's arrow, at the right
---@field barL Texture        a folder's bronze bar: left end and the rest
---@field barM Texture
---@field hlL Texture         the same, lit: under the mouse, or all the time while the folder is chosen
---@field hlM Texture
---@field tab Texture         a section's ("In guides") bar
---@field glow Texture        a guide's glow, under the mouse
---@field box Texture         the followed guide's check box and its check
---@field check Texture
---@field row ObviGuidePickerRow

---@class ObviGuidePickerList   a scroll box with its scroll bar: a column, or the search's list
---@field box table           the scroll box
---@field shade Texture       the quest log's shade at its foot, while there is more below
---@field rows ObviGuidePickerRow[]
---@field path? string        the folder a column shows
---@field frame Frame         the frame it fills
---@field art Texture         the quest log's background at its top
---@field line? Texture       a column's gold line at its right

---@class ObviGuidePickerCrumb : Button   a folder in the path above the columns
---@field label FontString
---@field sep Texture         the arrow before it
---@field level integer       clicking it lets go the folders chosen from this column on
---@field last boolean        the folder chosen last (white)

local frame ---@type Frame?
local search ---@type EditBox
local columnsFrame ---@type Frame
local columns = {} ---@type ObviGuidePickerList[]   made as needed; the first `panes` on screen
local panes = 0           -- columns on screen
local panelW = 0          -- the lists' panel's width
local results ---@type ObviGuidePickerList   the search's list, in the columns' place
local crumbs ---@type Frame        the path: "Guides" and the folders chosen ("Guides" goes back to the top)
local crumbButtons = {} ---@type ObviGuidePickerCrumb[]
local empty ---@type FontString
local status ---@type FontString   "Indexing quests... 40%"
local tree ---@type ObviGuideTree?
local chosen = {} ---@type string[]   the folder chosen in each column, left to right
local scrolled = {} ---@type table<string, number>   how far each folder's column was scrolled, kept for the session
local timer ---@type FunctionContainer?
local names = {} ---@type table<ObviGuideGuide, ObviGuideNames>   the guides' quest and NPC names, kept for the session
local indexer ---@type thread?   gathering them, while the picker is open

--- Builds the folder tree again: the guides listed for this character (as the menu did, a guide whose "only"
--- doesn't hold is left out). Pending guides are listed as they are; they are read only when opened. A chosen
--- folder that is gone now is let go, with those after it.
local function Rebuild()
	local t = Picker.Tree(ns.guides, function(g) return ns.Conditions.Eval(g.cond) end)
	tree = t
	for i, path in ipairs(chosen) do
		if path ~= Picker.RECENT and not t.folders[path] then
			for j = #chosen, i, -1 do chosen[j] = nil end
			break
		end
	end
end

--- Shows the shade at a list's foot while it can scroll further down (as the quest log does).
---@param list ObviGuidePickerList
local function UpdateShade(list)
	local box = list.box
	local more = box:HasScrollableExtent() and box:GetScrollPercentage() < 0.999
	list.shade:SetAlpha(more and 1 or 0)
end

--- Gives a list its rows. A column showing the same folder as before keeps its place; one showing another folder
--- goes back to where that folder was last scrolled to (or the top).
---@param list ObviGuidePickerList
---@param rows ObviGuidePickerRow[]
---@param path? string
---@param keep? boolean
local function SetRows(list, rows, path, keep)
	local box = list.box
	local same = keep or (path ~= nil and path == list.path)
	list.rows, list.path = rows, path
	local retain = same and _G["ScrollBoxConstants"] and _G["ScrollBoxConstants"].RetainScrollPosition or nil
	box:SetDataProvider(CreateDataProvider(rows), retain)
	if not same and path and scrolled[path] then box:SetScrollPercentage(scrolled[path]) end
	UpdateShade(list)
end

local Choose ---@type fun(level: integer, path?: string)

--- A crumb of the path (made when first needed).
---@param i integer
---@return ObviGuidePickerCrumb
local function Crumb(i)
	local c = crumbButtons[i]
	if c then return c end
	c = CreateFrame("Button", nil, crumbs) --[[@as ObviGuidePickerCrumb]]
	c:SetHeight(18)
	c.label = c:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	c.label:SetAllPoints()
	c.label:SetJustifyH("LEFT")
	c.label:SetWordWrap(false)
	c.sep = crumbs:CreateTexture(nil, "ARTWORK")
	Chevron(c.sep, 10)
	c.sep:SetAlpha(0.7)
	c.sep:SetPoint("CENTER", c, "LEFT", -8, 0)
	c:SetScript("OnClick", function(self) Choose(self.level) end)
	c:SetScript("OnEnter", function(self) self.label:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB()) end)
	c:SetScript("OnLeave", function(self)
		self.label:SetTextColor((self.last and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR):GetRGB())
	end)
	crumbButtons[i] = c
	return c
end

--- The path above the columns: "Guides", then each folder chosen; the ones on the left left out when it's too long.
local function UpdateCrumbs()
	if not tree then return end
	local parts = { "Guides" }
	for i, path in ipairs(chosen) do
		local f = tree.folders[path]
		parts[i + 1] = path == Picker.RECENT and "Recent" or f and f.name or path
	end
	local GAP = 16   -- the chevron between two
	local X0 = 4
	local avail = panelW - 4 - X0
	if avail <= 0 then avail = math.huge end   -- not laid out yet
	local total, widths = 0, {}
	for i, text in ipairs(parts) do
		local c = Crumb(i)
		c.label:SetText(text)
		widths[i] = math.min(c.label:GetStringWidth() + 2, 220)
		c:SetWidth(widths[i])
		total = total + widths[i] + (i > 1 and GAP or 0)
	end
	local first = 1
	while total > avail and first < #parts do
		total = total - widths[first] - GAP
		first = first + 1
	end
	local x = X0
	for i, c in ipairs(crumbButtons) do
		local shown = i >= first and i <= #parts
		c:SetShown(shown)
		c.sep:SetShown(shown and i > first)
		if shown then
			if i > first then x = x + GAP end
			c:ClearAllPoints()
			c:SetPoint("LEFT", crumbs, "LEFT", x, 0)
			x = x + widths[i]
			c.level = i
			c.last = i == #parts
			c.label:SetTextColor((c.last and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR):GetRGB())
		end
	end
end

--- Fills the columns on screen: the last levels of the chosen path, the folder chosen in each lit.
local function ShowColumns()
	if not tree then return end
	local recent = ns.charDB and ns.charDB.recent
	local levels = #chosen + 1
	local first = math.max(1, levels - panes + 1)
	-- each column's place first: when they slide, a folder moves to the next column over
	for i = 1, panes do
		local col = columns[i]
		if col.path then scrolled[col.path] = col.box:GetScrollPercentage() end
	end
	for i = 1, panes do
		local col = columns[i]
		local level = first + i - 1
		local path = level == 1 and "" or chosen[level - 1]
		local rows = path and Picker.Children(tree, path, recent) or {}
		for _, row in ipairs(rows) do
			row.level = level
			row.selected = row.path ~= nil and row.path == chosen[level]
		end
		SetRows(col, rows, path)
	end
	UpdateCrumbs()
end

--- Scrolls each column to its chosen folder, or to the current guide.
local function Reveal()
	local current = ns.Engine.Current()
	local C = _G["ScrollBoxConstants"]
	for c = 1, panes do
		local col = columns[c]
		for i, row in ipairs(col.rows) do
			if row.selected or (current and row.guide == current) then
				if col.box.ScrollToElementDataIndex then col.box:ScrollToElementDataIndex(i, C and C.AlignCenter, 0, true) end
				break
			end
		end
	end
end

--- Chooses a folder in a column (those after it let go), or with no path steps back to that level.
Choose = function(level, path)
	for i = #chosen, level, -1 do chosen[i] = nil end
	if path then chosen[level] = path end
	ShowColumns()
end

--- Shows the columns, or while there is something in the search box, the guides it finds. `keep` keeps the search
--- list's place.
---@param keep? boolean
local function Fill(keep)
	if not (frame and tree) then return end
	local words = Picker.Words(search:GetText())
	local searching = #words > 0
	columnsFrame:SetShown(not searching)
	crumbs:SetShown(not searching)
	results.frame:SetShown(searching)
	local none
	if searching then
		SetRows(results, Picker.Results(tree, words, names), nil, keep)
		none = #results.rows == 0
	else
		ShowColumns()
		none = #tree.list == 0
	end
	empty:SetText(#ns.guides == 0 and "No guides loaded. Add a guide pack." or "No guides match")
	empty:SetShown(none)
end

--- One frame's share of gathering the names (the picker's OnUpdate, so it runs only while the picker is open). When
--- done, a search shows what it finds in all of them.
local function Index()
	if not indexer then return end
	local ok, done = coroutine.resume(indexer)
	if coroutine.status(indexer) ~= "dead" then
		status:SetFormattedText("Indexing quests... %d%%", math.floor((done or 0) * 100))
		status:Show()
		return
	end
	if not ok then ns.Debug("indexing quests: %s", tostring(done)) end
	indexer = nil
	status:Hide()
	if frame then frame:SetScript("OnUpdate", nil) end
	if search:GetText() ~= "" then Fill(true) end
end

--- Gathers the names of the guides that don't have them yet (all of them, the first time).
local function StartIndex()
	if indexer or not frame then return end
	indexer = Picker.Indexer(ns.guides, names, debugprofilestop, BUDGET)
	frame:SetScript("OnUpdate", Index)
end

--- Opens a guide and closes the picker. From its first step, as the old menu did: the engine moves on past the
--- steps already done.
---@param g ObviGuideGuide
local function Load(g)
	if frame then frame:Hide() end
	ns.Engine.Load(g.name or g.title, 1)
end

---@param self ObviGuidePickerButton
local function RowClick(self)
	local row = self.row
	if row.kind == "guide" and row.guide then
		Load(row.guide)
	elseif row.kind == "group" and row.level and row.path then
		Choose(row.level, row.path)
	end
end

--- A row's text colour: the quest log's yellow, white under the mouse or while chosen.
---@param b ObviGuidePickerButton
---@param lit boolean
local function Paint(b, lit)
	local kind = b.row and b.row.kind
	if kind ~= "group" and kind ~= "guide" then return end
	local c = (lit or b.row.selected) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
	b.label:SetTextColor(c:GetRGB())
end

local BRONZE = { 0.32, 0.22, 0.1, 0.9 }   -- a folder bar where the client lacks the quest log's

--- Lays out a folder's bar (or its lit copy): the quest log's zone header, its left end and its middle to the
--- row's end (its right end has the + and -, which a column doesn't fold).
---@param b Button
---@param l Texture
---@param m Texture
local function SetBar(b, l, m)
	if not Art(l, "Options_ListExpand_Left", true, BRONZE) then l:SetSize(4, EXTENT.group) end
	Art(m, "_Options_ListExpand_Middle", false, BRONZE)
	l:SetPoint("TOPLEFT")
	m:SetPoint("BOTTOMLEFT", l, "BOTTOMRIGHT")
	m:SetPoint("TOPRIGHT", b, "TOPRIGHT")
end

--- Sets up a row for what it shows now (the scroll box reuses a few buttons for all rows).
---@param b ObviGuidePickerButton
---@param row ObviGuidePickerRow
local function InitRow(b, row)
	if not b.label then
		b.barL = b:CreateTexture(nil, "BACKGROUND")
		b.barM = b:CreateTexture(nil, "BACKGROUND")
		b.hlL = b:CreateTexture(nil, "HIGHLIGHT")
		b.hlM = b:CreateTexture(nil, "HIGHLIGHT")
		SetBar(b, b.barL, b.barM)
		SetBar(b, b.hlL, b.hlM)
		for _, t in ipairs({ b.hlL, b.hlM }) do t:SetBlendMode("ADD") t:SetAlpha(0.4) end
		-- a section ("In guides"): the bar of the quest log's smaller campaign headers
		b.tab = b:CreateTexture(nil, "BACKGROUND")
		Art(b.tab, "questlog-tab", false, BRONZE)
		b.tab:SetPoint("TOPLEFT", 0, -5)
		b.tab:SetPoint("TOPRIGHT", 0, -5)
		b.tab:SetHeight(22)
		b.glow = b:CreateTexture(nil, "HIGHLIGHT")
		Art(b.glow, "questlog-quest-glow-yellow", false, { 1, 0.82, 0, 0.1 })
		b.glow:SetPoint("TOPLEFT", 0, 2)
		b.glow:SetPoint("BOTTOMRIGHT", 0, -2)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(ICON, ICON)
		b.icon:SetPoint("LEFT", 6, 0)
		Art(b.icon, "questlog-storylineicon")
		-- the quest log's track box, checked
		b.box = b:CreateTexture(nil, "ARTWORK")
		if not Art(b.box, "questlog-icon-ticksquare", true) then b.box:SetSize(14, 14) end
		b.box:SetPoint("RIGHT", -8, 0)
		b.check = b:CreateTexture(nil, "OVERLAY")
		if not Art(b.check, "questlog-icon-checkmark-yellow", true, "Interface\\Buttons\\UI-CheckBox-Check") then
			b.check:SetSize(18, 18)
		end
		b.check:SetPoint("CENTER", b.box, "CENTER", 1, 1)
		b.arrow = b:CreateTexture(nil, "ARTWORK")
		Chevron(b.arrow, 11)
		b.arrow:SetPoint("RIGHT", -8, 0)
		b.count = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		b.count:SetPoint("RIGHT", b.arrow, "LEFT", -6, 0)
		b.label = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		b.label:SetJustifyH("LEFT")
		b.label:SetWordWrap(false)
		b:SetScript("OnClick", RowClick)
		b:SetScript("OnEnter", function(self)
			Paint(self, true)
			-- a name cut short (the columns are narrow): in full
			local label = self.label
			if label["IsTruncated"] and label["IsTruncated"](label) then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(self.row.text, 1, 1, 1)
				if self.row.note then GameTooltip:AddLine(self.row.note, 0.6, 0.6, 0.6, true) end
				GameTooltip:Show()
			end
		end)
		b:SetScript("OnLeave", function(self) Paint(self, false) GameTooltip:Hide() end)
	end
	b.row = row
	local kind = row.kind
	b:SetHeight(EXTENT[kind])
	local isGroup, isGuide = kind == "group", kind == "guide"
	for _, t in ipairs({ b.barL, b.barM, b.hlL, b.hlM, b.arrow }) do t:SetShown(isGroup) end
	-- the chosen folder lit all the time, as Finder marks it
	local layer = row.selected and "ARTWORK" or "HIGHLIGHT"
	b.hlL:SetDrawLayer(layer)
	b.hlM:SetDrawLayer(layer)
	b.tab:SetShown(kind == "header")
	b.glow:SetShown(isGuide)
	b.icon:SetShown(isGuide)
	local current = isGuide and row.guide ~= nil and row.guide == ns.Engine.Current()
	b.box:SetShown(current)
	b.check:SetShown(current)
	b.count:SetText(row.count and tostring(row.count) or "")
	-- the search: the guide's folder, or the quest or NPC it was found by, in grey after the title
	b.label:SetText(row.note and (row.text .. "  |cff808080" .. row.note .. "|r") or row.text)
	b.label:ClearAllPoints()
	b:EnableMouse(isGroup or isGuide)
	if kind == "header" then
		b.label:SetFontObject("Game15Font_Shadow")
		b.label:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
		b.label:SetPoint("LEFT", 10, -1)
		b.label:SetPoint("RIGHT", -10, -1)
	elseif kind == "more" then
		-- "...and 12 more": grey, not clickable
		b.label:SetFontObject("GameFontDisable")
		b.label:SetTextColor(0.5, 0.5, 0.5)
		b.label:SetPoint("LEFT", 8, 0)
		b.label:SetPoint("RIGHT", -8, 0)
	elseif isGroup then
		b.label:SetFontObject("GameFontNormal")
		b.label:SetPoint("LEFT", 10, 0)
		b.label:SetPoint("RIGHT", b.count, "LEFT", -6, 0)
	else
		b.label:SetFontObject("GameFontNormal")
		b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
		b.label:SetPoint("RIGHT", current and -28 or -8, 0)
	end
	Paint(b, b:IsMouseOver())
end

--- Fits a list's background to its height: the art is painted for the quest log's height, so where the list is
--- shorter it is cut off (as the quest log does), where taller the dark fill below it carries on.
---@param list ObviGuidePickerList
---@param height number
local function FitArt(list, height)
	local info = HasAtlas("QuestLog-main-background") and C_Texture.GetAtlasInfo("QuestLog-main-background")
	if not info then return end
	local art = info.height
	if height > 0 and art > height then
		list.art:SetHeight(height)
		list.art:SetTexCoord(0, 1, 0, height / art)
	else
		list.art:SetHeight(art)
		list.art:SetTexCoord(0, 1, 0, 1)
	end
end

--- A scroll box filling `parent`, its scroll bar inside at the right and the quest log's shade over its foot; the
--- quest log's background behind it.
---@param parent Frame
---@return ObviGuidePickerList
local function NewList(parent)
	-- each list its own copy of the art, so it isn't stretched across the whole window
	local art = parent:CreateTexture(nil, "BACKGROUND")
	if Art(art, "QuestLog-main-background") then
		art:SetPoint("TOPLEFT")
		art:SetPoint("TOPRIGHT")
	end
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList") --[[@as Frame]]
	box:SetPoint("TOPLEFT", 2, -2)
	box:SetPoint("BOTTOMRIGHT", -14, 2)
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, -2)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 2)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtentCalculator(function(_, row) return EXTENT[row.kind] or EXTENT.guide end)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	-- the shade over the rows
	local over = CreateFrame("Frame", nil, parent)
	over:SetAllPoints(box)
	over:SetFrameLevel(box:GetFrameLevel() + 10)
	local shade = over:CreateTexture(nil, "OVERLAY")
	if Art(shade, "questlog-frame-gradient-bottom", true) then
		local info = C_Texture.GetAtlasInfo("questlog-frame-gradient-bottom")
		shade:ClearAllPoints()
		shade:SetPoint("BOTTOMLEFT")
		shade:SetPoint("BOTTOMRIGHT")
		if info then shade:SetHeight(info.height) end
	end
	shade:SetAlpha(0)
	local list = { box = box, shade = shade, rows = {}, frame = parent, art = art } ---@type ObviGuidePickerList
	local events = _G["BaseScrollBoxEvents"]
	if events and events.OnScroll then list.box:RegisterCallback(events.OnScroll, function() UpdateShade(list) end, list) end
	return list
end

--- The first guide the search found (Enter opens it).
---@return ObviGuideGuide?
local function FirstGuide()
	for _, row in ipairs(results.rows) do if row.kind == "guide" then return row.guide end end
end

--- A column (made when first needed), with a thin gold line at its right for the next one.
---@param i integer
---@return ObviGuidePickerList
local function Column(i)
	local col = columns[i]
	if col then return col end
	col = NewList(CreateFrame("Frame", nil, columnsFrame))
	col.line = columnsFrame:CreateTexture(nil, "ARTWORK")
	col.line:SetColorTexture(1, 0.82, 0, 0.2)
	col.line:SetWidth(1)
	columns[i] = col
	return col
end

--- Lays the window out for its size: as many columns as fit share the width, the art cut to the height. When the
--- number of columns changes, they show as many levels.
---@param w number   the window's width and height
---@param h number
local function Layout(w, h)
	panelW = w - 24
	local height = h - TOP - 30   -- the lists' (their anchors may not be resolved yet)
	local n, each = Picker.Fit(panelW, MIN_PANE)
	for i = 1, math.max(n, #columns) do
		local col = i <= n and Column(i) or columns[i]
		local shown = i <= n
		col.frame:SetShown(shown)
		col.line:SetShown(i < n)
		if shown then
			local x = (i - 1) * (each + 1)
			col.frame:ClearAllPoints()
			col.frame:SetPoint("TOPLEFT", x, 0)
			col.frame:SetPoint("BOTTOMLEFT", x, 0)
			col.frame:SetWidth(each)
			col.line:ClearAllPoints()
			col.line:SetPoint("TOPLEFT", x + each, -4)
			col.line:SetPoint("BOTTOMLEFT", x + each, 4)
			FitArt(col, height)
		elseif col.path then
			-- off screen: its place kept, and shown afresh when it comes back
			scrolled[col.path] = col.box:GetScrollPercentage()
			col.path = nil
		end
	end
	FitArt(results, height)
	if n ~= panes then
		panes = n
		ShowColumns()
	else
		UpdateCrumbs()
	end
end

--- Keeps the window's size and place for the next time.
---@param f Frame
local function SaveFrame(f)
	if not ns.db then return end
	local point, _, relPoint, x, y = f:GetPoint()
	ns.db.picker = { w = f:GetWidth(), h = f:GetHeight(), point = point, relPoint = relPoint, x = x, y = y }
end

local function Build()
	-- the game's standard panel, without the portrait, like the copy and cleanup windows
	local f = CreateFrame("Frame", "ObviGuidePickerFrame", UIParent, "ButtonFrameTemplate") --[[@as Frame]]
	_G["ButtonFrameTemplate_HidePortrait"](f)
	if f["SetTitle"] then f["SetTitle"](f, "Guides") end
	-- the size and place it had last
	local saved = ns.db and ns.db.picker
	f:SetSize(math.max(MIN_W, math.min(MAX_W, saved and saved.w or WIDTH)), math.max(MIN_H, math.min(MAX_H, saved and saved.h or HEIGHT)))
	if saved and saved.point then
		f:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
	else
		f:SetPoint("CENTER")
	end
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SaveFrame(self) end)
	table.insert(_G["UISpecialFrames"], "ObviGuidePickerFrame")   -- Escape closes it (while the search box isn't typed in)
	-- the quest log's own frame and background take the inset's place
	local inset = f["Inset"] ---@type Frame?
	if inset then inset:Hide() end

	-- the resize grip in the corner, the chat windows' own
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetFrameLevel(f:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		-- pinned by its top left corner, so that one stays put
		local left, top = f:GetLeft(), f:GetTop()
		if left and top then
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		end
		f:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() SaveFrame(f) end)

	-- the lists' panel, as the quest log's: dark background (each list has the art on it), gold frame
	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT", 12, -TOP)
	panel:SetPoint("BOTTOMRIGHT", -12, 30)
	local fill = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
	fill:SetAllPoints()
	fill:SetColorTexture(0.06, 0.05, 0.04, 1)
	local border = CreateFrame("Frame", nil, panel)
	border:SetPoint("TOPLEFT", -3, 7)
	border:SetPoint("BOTTOMRIGHT", 3, -6)
	local edge = border:CreateTexture(nil, "BORDER")
	edge:SetAllPoints()
	Art(edge, "questlog-frame")
	local filigree = border:CreateTexture(nil, "ARTWORK")
	Art(filigree, "questlog-frame-filigree", true)
	filigree:SetPoint("TOP", 0, 1)

	-- the game's search box (the quest log's is the same): magnifier, placeholder and clear button
	search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate") --[[@as EditBox]]
	search:SetHeight(20)
	search:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 6, 35)
	search:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -24, 35)
	local hint = search["Instructions"] ---@type FontString?
	if hint then hint:SetText("Search guides") end
	-- hooked, so the template still shows and hides its clear button
	search:HookScript("OnTextChanged", function(self)
		if timer then timer:Cancel() timer = nil end
		if self:GetText() == "" then Fill() return end   -- cleared: at once, the columns as they were
		timer = C_Timer.NewTimer(DEBOUNCE, function() timer = nil Fill() end)
	end)
	-- Escape clears the search first, and closes on a second press
	search:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then self:SetText("") else f:Hide() end
	end)
	search:SetScript("OnEnterPressed", function(self)
		if timer then timer:Cancel() timer = nil Fill() end   -- typed faster than the list filtered
		local g = self:GetText() ~= "" and FirstGuide()
		if g then Load(g) else self:ClearFocus() end
	end)

	-- the quest log's gear beside it: Obvi Guide's settings
	local gear = CreateFrame("Button", nil, f)
	gear:SetSize(15, 16)
	gear:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, 53)
	local icon = gear:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	Art(icon, "questlog-icon-setting", false, "Interface\\Buttons\\UI-OptionsButton")
	local lit = gear:CreateTexture(nil, "HIGHLIGHT")
	lit:SetAllPoints()
	Art(lit, "questlog-icon-setting", false, "Interface\\Buttons\\UI-OptionsButton")
	lit:SetBlendMode("ADD")
	lit:SetAlpha(0.4)
	gear:SetScript("OnClick", function() f:Hide() ns.Options.Open() end)
	gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Settings")
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- the path under the search box: "Guides" (the top) and each folder
	-- chosen, each clickable
	crumbs = CreateFrame("Frame", nil, f)
	crumbs:SetHeight(22)
	crumbs:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 2, 9)
	crumbs:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -2, 9)

	-- the columns (Layout makes as many as fit), a thin gold line between two
	columnsFrame = CreateFrame("Frame", nil, panel)
	columnsFrame:SetAllPoints()
	Column(1)
	-- the search's list, the panel's width
	local resultsFrame = CreateFrame("Frame", nil, panel)
	resultsFrame:SetAllPoints()
	resultsFrame:Hide()
	results = NewList(resultsFrame)
	border:SetFrameLevel(columns[1].box:GetFrameLevel() + 20)   -- the gold frame over the rows

	empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("TOP", 0, -32)
	empty:Hide()

	-- below the list, while the quest and NPC names are gathered
	status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	status:SetPoint("BOTTOMLEFT", 16, 10)
	status:Hide()

	f:SetScript("OnHide", function() if timer then timer:Cancel() timer = nil end search:ClearFocus() end)
	f:SetScript("OnSizeChanged", function(_, w, h) Layout(w, h) end)
	Layout(f:GetWidth(), f:GetHeight())
	frame = f
end

--- Opens the picker: search cleared and focused, the columns opened down to the current guide's folder.
function Picker.Open()
	if not frame then Build() end
	---@cast frame Frame
	Rebuild()
	---@cast tree ObviGuideTree
	for i = #chosen, 1, -1 do chosen[i] = nil end
	local current = ns.Engine.Current()
	if current then
		for _, path in ipairs(Picker.Ancestors(current.group or "")) do
			if not tree.folders[path] then break end   -- (a guide hidden for this character)
			chosen[#chosen + 1] = path
		end
	end
	search:SetText("")
	frame:Show()
	Fill()
	Reveal()
	search:SetFocus()
	StartIndex()
end

function Picker.Toggle()
	if frame and frame:IsShown() then frame:Hide() else Picker.Open() end
end

-- the guides opened last, for "Recent" (by name where the guide has one, as the engine saves it)
ns:On("OBVIGUIDE_LOADED", function(_, g)
	if not ns.charDB then return end
	ns.charDB.recent = ns.charDB.recent or {}
	Picker.Remember(ns.charDB.recent, g.name or g.title, RECENT)
end)

-- a pack added (or dropped an unreadable) guide while the picker is open
ns:On("OBVIGUIDE_GUIDES_ADDED", function()
	if frame and frame:IsShown() then Rebuild() Fill(true) StartIndex() end
end)
