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
---@field MinimapPins AnyGuideMinimapPins
---@field guides AnyGuideGuide[]                  every guide added this session, in order
---@field warnings string[]                        what the readers could not translate, for /ag debug
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
---@field TargetMacro fun(name: string|string[], enemy?: boolean): string
---@field Copy fun(title: string, text: string)   shows text in a window to copy it from
---@field Cleanup fun()   the quest log cleanup window
---@field Options AnyGuideOptions

---@class AnyGuideDB
---@field window? {point: string, relPoint?: string, x: number, y: number, width: number, height: number}
---@field previewSteps? integer   how many upcoming steps the window shows dimmed (default 0)
---@field minimap? boolean        the step's points on the minimap (nil: on)
---@field autoAccept? boolean     accept the current step's quests when talking to the NPC
---@field autoTurnin? boolean     turn in the current step's quests (no choice of rewards)

---@class AnyGuideCharDB
---@field guide? string          the title of the guide this character follows
---@field step? integer          the step it was on
---@field marks? table<string, table<string, boolean>>  [guide title]["step:goal"] = ticked off / reached

---@class AnyGuideParser
---@field Parse fun(text: string, source: string, meta?: table): AnyGuideGuide[], string[]   guides, and warnings for the chat

-- The neutral guide model every parser produces and the engine and window read.
---@class AnyGuideGuide
---@field title string           what the guide list shows
---@field name? string           the format's own id for the guide, which 'next' may refer to (RestedXP's #name)
---@field group string           a folder for the guide list, e.g. "RestedXP Forever Guide (A)"
---@field next? string           the title of the guide that follows
---@field cond? AnyGuideCond     listed only for characters this holds for
---@field format string          the format it came in ("rxp", "zygor")
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
---@field target? AnyGuideTarget  who the action key targets (the step's NPC or what it kills)
---@field path AnyGuidePoint[]   extra map points along the way
---@field markers? AnyGuidePoint[]   where the step's mobs or things are (dots on the maps, not a route)
---@field jumps? AnyGuideJump[]  where to go on when the step is done, instead of the next step (the first that is open)

---@class AnyGuideJump
---@field to integer             the step to go on at
---@field goal? AnyGuideGoal     open only while this goal is shown and, if it can be done, done (Zygor's "|next")
---@field cond? AnyGuideCond     open only while this holds

---@class AnyGuideTarget
---@field name string
---@field id? integer
---@field enemy? boolean         an enemy (skull mark) rather than an NPC

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
---@field done? AnyGuideCond     the line is done while this holds (besides what its kind checks)
---@field orGroup? string        lines with the same group are alternatives: once orCount of them are done, the
---@field orCount? integer       step counts them all as done (default 1)
---@field finishes? boolean      once this line is done, so is the step (Zygor's confirm lines)
---@field quest? integer
---@field objective? integer
---@field id? integer            npc, item or spell id, by kind
---@field count? integer
---@field level? integer
---@field xp? integer
---@field point? AnyGuidePoint   for 'goto'; on other lines their own spot, offered as a waypoint on hover
---@field mobName? string        parser use: the name a 'kill' goal matches against .mob lines
---@field what? string           what the progress counts, when the text doesn't say it ("Abandoned Belongings")
---@field target? AnyGuideTarget  who clicking the line (or its action key) targets
---@field targets? AnyGuideTarget[]  all of them, in order, when the line names several
---                                (target is the first)

---@alias AnyGuideCond table     a compiled condition tree, see Conditions.lua

ns.Parsers = {}
ns.guides = {}
ns.warnings = {}
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
-- Zygor guide text comes without its title and header (those are Lua in Zygor's files), so it takes them as a third
-- argument:  AnyGuide.Add("zygor", [[ ...guide text... ]], { title = "Leveling Guides\\Westfall (13-15)", header = {...} })
-- AnyGuide never reads other addons' files or data: guides come in only through this call.
---@class AnyGuideAPI
AnyGuide = AnyGuide or {}

---@param format string   "rxp" (RestedXP guide syntax) or "zygor" (Zygor guide syntax)
---@param text string     the guide text (one or more guides)
---@param meta? table     what the format needs besides the text (Zygor: the title and header)
---@return integer added  how many guides were added
function AnyGuide.Add(format, text, meta)
	local parser = ns.Parsers[format]
	local source = (debugstack(2, 1, 0) or ""):match("AddOns[\\/]([^\\/]+)") or "?"
	if not parser then ns.Print("unknown guide format '%s' (from %s)", tostring(format), source) return 0 end
	local ok, guides, warnings = pcall(parser.Parse, text, source, meta)
	if not ok then ns.Print("could not read a %s guide from %s: %s", format, source, tostring(guides)) return 0 end
	for _, w in ipairs(warnings or {}) do
		table.insert(ns.warnings, source .. ": " .. w)
		ns.Debug("%s: %s", source, w)
	end
	for _, g in ipairs(guides) do table.insert(ns.guides, g) end
	ns:Fire("ANYGUIDE_GUIDES_ADDED")
	return #guides
end

--- The macro that targets someone by name and puts a raid marker on them (skull for enemies, star for NPCs), like
--- Zygor's target buttons. Only slash commands: SetRaidTarget is Blizzard-only on this client, and a /run line in an
--- addon's macro is tainted (the game blocks it). /tm toggles, so "/tm 0" clears first and "/tm N" then always sets.
--- Several names (a line naming several mobs): the first one found, trying them in the order given.
---@param name string|string[]
---@param enemy? boolean
---@return string
function ns.TargetMacro(name, enemy)
	local mark = enemy and 8 or 1
	if type(name) == "table" and #name > 1 then
		-- each next name only while nothing (living) is targeted yet; a macro can't pick the nearest of two names
		local target = "/cleartarget\n"
		for i, n in ipairs(name) do
			target = target .. (i == 1 and "/targetexact %s\n" or "/targetexact [noexists] %s\n"):format(n)
			if enemy then target = target .. ("/targetexact [dead] %s\n/cleartarget [dead]\n"):format(n) end
		end
		return target .. ("/tm [@target,exists] 0\n/tm [@target,exists] %d"):format(mark)
	end
	if type(name) == "table" then name = name[1] end
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
