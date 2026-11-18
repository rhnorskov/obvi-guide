-- ObviHub: the slash commands of the Obvi addons, all built the same way, and /obvi, which lists the Obvi addons you
-- have ("/obvi guide list" is the same as "/og list").
--
-- The same file ships in every Obvi addon that stands on its own (ObviGuide, ObviTraining, ObviTweaks,
-- ObviCooldownManager); addons that need one of those (ObviGuide_Scribe, ObviGuide_Zygor) use its copy. Whichever copy
-- has the highest VERSION wins, so when changing it: bump VERSION and copy the file to every one of those addons.
--
-- Each addon registers itself with ObviHub.Register{ key, title, command, commands }: commands is a list of
-- { name, run, help, dev = true? }; the command named "" is what the slash command on its own does, and run gets the
-- rest of what was typed. Every Obvi command then answers "help" (a list of its commands), takes "config" for
-- "options", and says so when it doesn't know a command.

local VERSION = 1

local hub = _G["ObviHub"]
if hub and hub.version >= VERSION then return end
hub = hub or { addons = {} }
_G["ObviHub"] = hub
hub.version = VERSION

-- SlashCmdList is a FrameXML global the WoW annotations do not declare, hence the _G lookup.
local slashCmdList = _G["SlashCmdList"] ---@type table<string, fun(msg: string)>

local function Print(fmt, ...) print("|cff4fc3f7Obvi|r: " .. fmt:format(...)) end

--- Splits "Catchup  Blessed Arm" into "catchup", "Blessed Arm".
local function Split(msg)
	local name, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	return name:lower(), rest
end

---@param spec { key: string, title: string, command: string, commands: table[] }
function hub.Register(spec)
	hub.addons[spec.key] = spec
	local id = "OBVI_" .. spec.key:upper()
	_G["SLASH_" .. id .. "1"] = spec.command
	-- (looked up when typed, so a newer copy of this file loaded later is the one that runs)
	slashCmdList[id] = function(msg) _G["ObviHub"].Run(spec.key, msg) end
end

--- Adds a command to an addon registered already (an addon's plugin, like "/og zygor").
function hub.AddCommand(key, command)
	local spec = hub.addons[key]
	if spec then table.insert(spec.commands, command) end
end

function hub.Help(spec)
	Print("%s", spec.title)
	for _, c in ipairs(spec.commands) do
		local typed = c[1] == "" and spec.command or spec.command .. " " .. c[1]
		print(("   |cff%s%s|r  %s"):format(c.dev and "888888" or "ffd200", typed, c[3] or ""))
	end
	print(("   |cffffd200%s help|r  this list"):format(spec.command))
end

function hub.Run(key, msg)
	local spec = hub.addons[key]
	local name, rest = Split(msg)
	if name == "help" or name == "?" then hub.Help(spec) return end
	if name == "config" then name = "options" end
	for _, c in ipairs(spec.commands) do
		if c[1] == name then c[2](rest) return end
	end
	Print("%s has no command '%s' - %s help lists them", spec.title, name, spec.command)
end

local function Sorted()
	local list = {}
	for _, spec in pairs(hub.addons) do table.insert(list, spec) end
	table.sort(list, function(a, b) return a.title < b.title end)
	return list
end

-- /obvi: the Obvi addons you have; "/obvi <addon> ..." (its key, like guide, or its command, like og) runs its command
SLASH_OBVI1 = "/obvi"
slashCmdList.OBVI = function(msg)
	local name, rest = Split(msg)
	for _, spec in pairs(hub.addons) do
		if name ~= "" and (spec.key == name or spec.command == "/" .. name) then _G["ObviHub"].Run(spec.key, rest) return end
	end
	if name ~= "" and name ~= "help" then Print("no Obvi addon '%s'", name) end
	Print("your Obvi addons (add |cffffd200help|r to a command to see what it does):")
	for _, spec in ipairs(Sorted()) do
		print(("   |cffffd200%s|r  %s  |cff888888or /obvi %s|r"):format(spec.command, spec.title, spec.key))
	end
end
