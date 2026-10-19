-- AnyGuide core: the shared namespace, one event hub for game and custom events, saved variables, chat output,
-- and the public API guide packs call (AnyGuide.Add). Every other file hangs its module on `ns`.
local ADDON, ns = ...
---@cast ns AnyGuideNS

---@alias AnyGuideHandler fun(event: string, ...: any)

---@class AnyGuideNS
---@field Conditions AnyGuideConditions
---@field Parsers table<string, AnyGuideParser>   format id ("rxp") -> parser
---@field Engine AnyGuideEngine
---@field Travel AnyGuideTravel
---@field Action AnyGuideAction
---@field Window AnyGuideWindow
---@field guides AnyGuideGuide[]                  every guide added this session, in order
---@field db AnyGuideDB                           account-wide saved variables, set at ADDON_LOADED
---@field charDB AnyGuideCharDB                   per-character saved variables, set at ADDON_LOADED
---@field Colors table<string, string>          shared text colours, see below
---@field version string
---@field debug boolean
---@field On fun(self: AnyGuideNS, event: string, fn: AnyGuideHandler)
---@field Fire fun(self: AnyGuideNS, event: string, ...: any)
---@field Print fun(fmt: string, ...: any)
---@field Debug fun(fmt: string, ...: any)
---@field FindGuide fun(title: string): AnyGuideGuide?
---@field TargetMacro fun(name: string, enemy?: boolean): string
---@field Copy fun(title: string, text: string)   shows text in a window to copy it from

---@class AnyGuideDB
---@field window? {point: string, relPoint?: string, x: number, y: number, width: number, height: number}
---@field previewSteps? integer   how many upcoming steps the window shows dimmed (default 0)

---@class AnyGuideCharDB
---@field guide? string          the title of the guide this character follows
---@field step? integer          the step it was on
---@field marks? table<string, table<string, boolean>>  [guide title]["step:goal"] = ticked off / reached

---@class AnyGuideParser
---@field Parse fun(text: string, source: string): AnyGuideGuide[], string[]   guides, and warnings for the chat

-- The neutral guide model every parser produces and the engine and window read.
---@class AnyGuideGuide
---@field title string           what the guide list shows
---@field name? string           the format's own id for the guide, which 'next' may refer to (RestedXP's #name)
---@field group string           a folder for the guide list, e.g. "RestedXP Forever Guide (A)"
---@field next? string           the title of the guide that follows
---@field cond? AnyGuideCond     listed only for characters this holds for
---@field format string          the format it came in ("rxp")
---@field source string          which pack added it
---@field steps AnyGuideStep[]

---@class AnyGuideStep
---@field index integer
---@field cond? AnyGuideCond     shown only while this holds
---@field skip? AnyGuideCond     counts as done (skipped) while this holds, e.g. "already out of the cave"
---@field goals AnyGuideGoal[]
---@field side AnyGuideGoal[]    side tasks shown with this step but never holding it up
---@field tips AnyGuideTip[]
---@field label? string
---@field dest? AnyGuidePoint    where the step leads (the waypoint)
---@field target? {name: string, id?: integer, enemy?: boolean}  who the action key targets (the step's NPC or what it kills)
---@field path AnyGuidePoint[]   extra map points along the way

---@class AnyGuideTip
---@field text string
---@field after? AnyGuideGoal    shown right after this goal's line, as the guide has it (nil: before the first)

---@class AnyGuidePoint
---@field map integer            uiMapID
---@field x number               0..1
---@field y number               0..1
---@field radius? number         yards; arriving this close completes a 'goto' goal

---@alias AnyGuideGoalKind "text"|"goto"|"talk"|"hearth"|"accept"|"turnin"|"objective"|"collect"|"kill"|"use"|"cast"|"learn"|"level"|"home"|"fly"|"equip"|"confirm"

---@class AnyGuideGoal
---@field kind AnyGuideGoalKind
---@field text string            what the window shows
---@field cond? AnyGuideCond     the line is shown (and counts) only while this holds
---@field quest? integer
---@field objective? integer
---@field id? integer            npc, item or spell id, by kind
---@field count? integer
---@field level? integer
---@field xp? integer
---@field point? AnyGuidePoint   for 'goto'
---@field mobName? string        parser use: the name a 'kill' goal matches against .mob lines
---@field what? string           what the progress counts, when the text doesn't say it ("Abandoned Belongings")
---@field target? {name: string, id?: integer, enemy?: boolean}  who clicking the line (or its action key) targets

---@alias AnyGuideCond table     a compiled condition tree, see Conditions.lua

ns.Parsers = {}
ns.guides = {}
-- Colours for the things guide text names (RestedXP's colour tags use the same names), taken from the game's own
-- colours so lines look like the rest of the UI. Every format uses these, so all guides look alike.
ns.Colors = {
	FRIENDLY = "ff00ff25", ENEMY = "ffff5040", LOOT = "ff00bbff", WARN = "ffffa500",
	PICK = "ffdb7fff", BUY = "ffffd100",
}
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
ns.debug = false

-- Events: game events and our own ("ANYGUIDE_STEP", ...) go through the same hub.
local handlers = {} ---@type table<string, AnyGuideHandler[]>
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...) ns:Fire(event, ...) end)

function ns:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		if not event:find("^ANYGUIDE_") then
			-- Forever lacks some retail events; registering an unknown one would throw
			if C_EventUtils.IsEventValid(event) then frame:RegisterEvent(event) else ns.Debug("no event %s on this client", event) end
		end
	end
	table.insert(handlers[event], fn)
end

function ns:Fire(event, ...)
	for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end

function ns.Print(fmt, ...)
	print("|cff4fc3f7AnyGuide|r: " .. (select("#", ...) > 0 and fmt:format(...) or fmt))
end

function ns.Debug(fmt, ...)
	if ns.debug then ns.Print("|cff888888" .. fmt .. "|r", ...) end
end

-- Guides added before our saved variables exist (packs load after us, but before ADDON_LOADED fires for them)
-- are parsed right away; nothing in parsing needs the saved variables.
ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	AnyGuideDB = AnyGuideDB or {}
	AnyGuideCharDB = AnyGuideCharDB or {}
	ns.db, ns.charDB = AnyGuideDB, AnyGuideCharDB
end)

-- The public API, for guide packs: a small addon with "## Dependencies: AnyGuide" whose files call
--   AnyGuide.Add("rxp", [[ ...guide text... ]])
-- AnyGuide never reads other addons' files or data: guides come in only through this call.
---@class AnyGuideAPI
AnyGuide = AnyGuide or {}

---@param format string   "rxp" (RestedXP guide syntax)
---@param text string     the guide text (one or more guides)
---@return integer added  how many guides were added
function AnyGuide.Add(format, text)
	local parser = ns.Parsers[format]
	local source = (debugstack(2, 1, 0) or ""):match("AddOns[\\/]([^\\/]+)") or "?"
	if not parser then ns.Print("unknown guide format '%s' (from %s)", tostring(format), source) return 0 end
	local ok, guides, warnings = pcall(parser.Parse, text, source)
	if not ok then ns.Print("could not read a %s guide from %s: %s", format, source, tostring(guides)) return 0 end
	for _, w in ipairs(warnings or {}) do ns.Debug("%s: %s", source, w) end
	for _, g in ipairs(guides) do table.insert(ns.guides, g) end
	ns:Fire("ANYGUIDE_GUIDES_ADDED")
	return #guides
end

--- The macro that targets someone by name and puts a raid marker on them (skull for enemies, star for NPCs), like
--- Zygor's target buttons. Only slash commands: SetRaidTarget is Blizzard-only on this client, and a /run line in an
--- addon's macro is tainted (the game blocks it). /tm toggles, so "/tm 0" clears first and "/tm N" then always sets.
---@param name string
---@param enemy? boolean
---@return string
function ns.TargetMacro(name, enemy)
	local mark = enemy and 8 or 1
	local target = ("/cleartarget\n/targetexact %s\n"):format(name)
	if enemy then
		-- /targetexact takes the nearest match, dead or not; while the target is dead, targeting the same name again
		-- cycles on to the next match. Guides often name mobs in the plural ("Bandit Highwaymen"), so when the exact
		-- name finds nothing, a partial match on the name minus its last two letters tries again ("Bandit Highwaym").
		-- A corpse still left at the end is let go.
		local stem = #name > 6 and name:sub(1, -3) or name
		target = target .. ("/targetexact [dead] %s\n/target [noexists] %s\n/target [dead] %s\n/cleartarget [dead]\n")
			:format(name, stem, stem)
	end
	return target .. ("/tm [@target,exists] 0\n/tm [@target,exists] %d"):format(mark)
end

---@param title string
---@return AnyGuideGuide?
function ns.FindGuide(title)
	for _, g in ipairs(ns.guides) do if g.title == title or g.name == title then return g end end
end
