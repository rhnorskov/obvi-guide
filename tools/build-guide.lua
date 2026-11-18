-- Builds a guide file with Obvi Guide's Builder outside the game and prints its steps: which places a step chooses
-- from (* the first, - the others), what kinds of lines it has, and the first step's side box with each line's
-- condition. A quick check that a guide builds and is shaped as meant; it doesn't run the engine.
-- lua-language-server is a Lua interpreter too, so no other Lua is needed. From the repo root:
--
--   lua-language-server tools/build-guide.lua . ObviGuide_Professions/Profession.lua ObviGuide_Professions/Engineering.lua
local root = arg[1]

-- the little of the game's API the builder touches
unpack = table.unpack
C_Item = { GetItemIconByID = function() end, GetItemInfo = function() end, GetItemCount = function() return 0 end }
C_Spell = { GetSpellTexture = function() end, GetSpellName = function() end }
C_Map = setmetatable({}, { __index = function() return function() end end })
ObviGuide = {}
debugstack = function() return "AddOns/Guide/x.lua" end
local ns = { guides = {} }
ns.Print = function(fmt, ...) print("PRINT: " .. string.format(fmt, ...)) end
function ns:Fire() end
ns.Colors = setmetatable({}, { __index = function() return "" end })
ns.Conditions = { ClassToken = function() return nil end,
	All = function(a, b) return a and b and { "and", a, b } or a or b end,
	RACES = { human = 1, dwarf = 1, gnome = 1, nightelf = 1, skyborne = 1, orc = 1, troll = 1, undead = 1, tauren = 1 } }
assert(loadfile(root .. "/ObviGuide/Builder.lua"))("ObviGuide", ns)
-- the files, in order, sharing one pack table (a pack's shared code first, as its TOC loads it)
local pack = {}
for k = 2, #arg do assert(loadfile(arg[k]))("Guide", pack) end

local function Plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|c", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
local function Cond(c)
	if type(c) ~= "table" then return tostring(c) end
	local t = {}
	for _, v in ipairs(c) do table.insert(t, Cond(v)) end
	return "(" .. table.concat(t, " ") .. ")"
end

for _, guide in ipairs(ns.guides) do
	print("GUIDE", guide.title, #guide.steps .. " steps")
	for i, s in ipairs(guide.steps) do
		local talks, kinds = {}, {}
		for _, g in ipairs(s.goals) do
			if g.kind == "talk" then
				table.insert(talks, (g.option and (g.option.chosen and "*" or "-") or "") .. Plain(g.text):gsub("^Talk to ", ""))
			else
				table.insert(kinds, g.kind)
			end
		end
		print(i, s.dest and ("map " .. s.dest.map) or "-", table.concat(talks, " | "), table.concat(kinds, ","))
	end
	local first = guide.steps[1]
	print("SIDE on step 1: " .. #first.side .. " lines")
	for _, g in ipairs(first.side) do print("", g.kind, g.count or "", Plain(g.text), Cond(g.cond)) end
end
