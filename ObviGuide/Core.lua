-- ObviGuide core: the shared namespace, one event hub for game and custom events, saved variables, chat output,
-- and the public API guide packs call (ObviGuide.Add). Every other file hangs its module on `ns`.
local ADDON, ns = ...
---@cast ns ObviGuideNS

---@alias ObviGuideHandler fun(event: string, ...: any)

---@class ObviGuideNS
---@field Conditions ObviGuideConditions
---@field Parsers table<string, ObviGuideParser>   format id ("rxp") -> parser
---@field Engine ObviGuideEngine
---@field Travel ObviGuideTravel
---@field Action ObviGuideAction
---@field Window ObviGuideWindow
---@field MinimapPins ObviGuideMinimapPins
---@field WorldMapPins ObviGuideWorldMapPins
---@field Arrow ObviGuideArrow
---@field guides ObviGuideGuide[]                  every guide added this session, in order
---@field warnings string[]                        what the readers could not translate, for /og debug
---@field db ObviGuideDB                           account-wide saved variables, set at ADDON_LOADED
---@field charDB ObviGuideCharDB                   per-character saved variables, set at ADDON_LOADED
---@field Colors table<string, string>          shared text colours, see below
---@field version string
---@field debug boolean
---@field On fun(self: ObviGuideNS, event: string, fn: ObviGuideHandler)
---@field Fire fun(self: ObviGuideNS, event: string, ...: any)
---@field Print fun(fmt: string, ...: any)
---@field Debug fun(fmt: string, ...: any)
---@field FindGuide fun(title: string): ObviGuideGuide?
---@field Ready fun(g: ObviGuideGuide): ObviGuideGuide?
---@field TargetMacro fun(name: string|string[], enemy?: boolean, keep?: boolean): string
---@field CanPing fun(): boolean
---@field Copy fun(title: string, text: string)   shows text in a window to copy it from
---@field Cleanup fun()   the quest log cleanup window
---@field DestroyCheapest fun()   asks to destroy the cheapest item in the bags (UI\Junk.lua)
---@field Catchup ObviGuideCatchup
---@field GuidePicker ObviGuidePicker
---@field Options ObviGuideOptions
---@field Shopping ObviGuideShopping   Auctionator shopping lists of what a step's Collect lines are short of

---@class ObviGuideDB
---@field window? {point: string, relPoint?: string, x: number, y: number, width: number, height: number}   the first guide window's place
---@field picker? {w: number, h: number, point?: string, relPoint?: string, x?: number, y?: number}   the guide picker's size and place
---@field pickerShowOtherFaction? boolean   the guide picker also lists the guides only for the other faction (its gear menu; nil: left out)
---@field previewSteps? integer   how many upcoming steps the window shows dimmed (default 0)
---@field minimap? boolean        the step's points on the minimap (nil: on)
---@field worldMap? boolean       the step's points on the world map (nil: on)
---@field waypoints? ObviGuideWaypoints   how the way is shown (nil: Auto, Shortest Path Forever when installed, else
---                               the arrow; before Auto, nil was the arrow, so players who left it alone get Auto)
---@field arrow? {point: string, relPoint: string, x: number, y: number}   where the arrow was dragged
---@field flip? boolean           the window's header at the bottom (it grows upwards)
---@field autoAccept? boolean     accept the guide's quests when talking to the NPC (nil: on)
---@field skipMissing? "notworth"|"all"   skip steps whose quest misses a prerequisite: when not worth catching up, or all (nil: show them)
---@field skipLocked? boolean     (before skipMissing) true: skip them all
---@field skipHearth? boolean     leave out the hearth and set-hearth lines; a step with nothing else is skipped (nil: off)
---@field catchupDetails? boolean show the catch-up's XP, time and pace, not only whether it's worth it (nil: off)
---@field autoTurnin? boolean     turn in the guide's quests, no choice of rewards (nil: on)
---@field marker? boolean         target buttons put a raid marker on the target (nil: on)
---@field ping? boolean           target buttons ping the target, where the client has pings (nil: on)

---@class ObviGuideTab
---@field guide? string          the guide in this tab (name, or title); none: an empty tab
---@field step? integer          the step it is on
---@field reached? integer       the furthest step the guide has gone to by itself (going back leaves it there)

-- A guide window's saved tabs: the first window's are the character's own (ObviGuideCharDB has them), the others' are
-- in charDB.windows, with where each was put.
---@class ObviGuideWindowSave
---@field tabs? ObviGuideTab[]   the guides open in tabs
---@field tab? integer           the tab shown
---@field guide? string          (before tabs; the first window) the guide this character followed
---@field step? integer          (before tabs; the first window) the step it was on
---@field at? {point: string, relPoint?: string, x: number, y: number, width: number}   where the window is (the first
---                              window's place is account-wide: ObviGuideDB.window)

---@class ObviGuideCharDB : ObviGuideWindowSave
---@field windows? ObviGuideWindowSave[]   the guide windows besides the first, each with its own tabs
---@field focus? integer         the active window (the waypoint and keys follow its step) when not the first: its number
---@field marks? table<string, table<string, boolean>>  [guide title]["step:goal"] = ticked off / reached
---@field flights? table<string, boolean>   flight points seen known (lower-case names; flight maps opened, paths learned)
---@field recent? string[]       the guides opened last, newest first (name, or title), for the guide picker
---@field catchup? ObviGuideCatchupSaved   the open catch-up guide, to make it again after a reload

---@class ObviGuideParser
---@field Parse fun(text: string, source: string, meta?: table): ObviGuideGuide[], string[]   guides, and warnings for the chat
---@field Head? fun(source: string, meta: table): ObviGuideGuide?, string[]   one guide as the list shows it, from meta
---                                    alone (no steps); a format with Head is read only when a guide is first opened
---@field Names? fun(text: string): string[]   the quest and NPC names in a guide's text, cheaply (the guide picker's
---                                    search looks in them for guides not read yet)

-- The neutral guide model every parser produces and the engine and window read.
---@class ObviGuideGuide
---@field title string           what the guide list shows
---@field name? string           the format's own id for the guide, which 'next' may refer to (RestedXP's #name)
---@field group string           a folder for the guide list, e.g. "RestedXP Forever Guide (A)"
---@field next? string           the title of the guide that follows
---@field cond? ObviGuideCond     listed only for characters this holds for
---@field challenge? integer     the challenge (achievement) it leads through: the challenges window offers it
---@field nearest? boolean     its steps can be done in any order: it goes to the nearest first, on the shortest way
---                             from where you are (exploration)
---@field format string          the format it came in ("obviguide", "rxp", or one an addon added)
---@field source string          which pack added it
---@field steps ObviGuideStep[]   (empty while the guide is still pending)
---@field back? {guide: string, step: integer}   a catch-up guide (Catchup.lua): the guide and step it leads back to
---@field pending? ObviGuidePending   its text, not read yet (see ns.Ready)

---@class ObviGuidePending
---@field text string|(fun(): string)
---@field meta table

---@class ObviGuideStep
---@field index integer
---@field cond? ObviGuideCond     shown only while this holds
---@field skip? ObviGuideCond     counts as done (skipped) while this holds, e.g. "already out of the cave"
---@field goals ObviGuideGoal[]
---@field side ObviGuideGoal[]    side tasks shown with this step but never holding it up
---@field tips ObviGuideTip[]
---@field label? string
---@field dest? ObviGuidePoint    where the step leads (the waypoint)
---@field options? ObviGuideOption[]   places to choose from (several trainers): dest is the one chosen
---@field target? ObviGuideTarget  who the action key targets (the step's NPC or what it kills)
---@field path ObviGuidePoint[]   extra map points along the way
---@field markers? ObviGuidePoint[]   where the step's mobs or things are (dots on the maps, not a route)
---@field jumps? ObviGuideJump[]  where to go on when the step is done, instead of the next step (the first that is open)

---@class ObviGuideOption
---@field point ObviGuidePoint
---@field cond? ObviGuideCond     one to choose only while this holds
---@field target? ObviGuideTarget  the NPC there
---@field chosen? boolean        the one the step goes to (Engine.Pick: the nearest)

---@class ObviGuideJump
---@field to integer             the step to go on at
---@field goal? ObviGuideGoal     open only while this goal is shown and, if it can be done, done (Zygor's "|next")
---@field cond? ObviGuideCond     open only while this holds

---@class ObviGuideTarget
---@field name string
---@field id? integer
---@field enemy? boolean         an enemy (skull mark) rather than an NPC

---@class ObviGuideTip
---@field text string
---@field after? ObviGuideGoal    shown right after this goal's line, as the guide has it (nil: before the first)
---@field notSide? boolean     left out where its step is shown as a side box (a reader for a format with side boxes made of steps)

---@class ObviGuidePoint
---@field map integer            uiMapID
---@field x number               0..1
---@field y number               0..1
---@field radius? number         yards; arriving this close completes a 'goto' goal

---@alias ObviGuideGoalKind "text"|"goto"|"talk"|"hearth"|"accept"|"turnin"|"objective"|"collect"|"kill"|"use"|"cast"|"learn"|"level"|"home"|"fly"|"equip"|"confirm"|"skill"|"challenge"|"sell"

---@class ObviGuideGoal
---@field kind ObviGuideGoalKind
---@field text string            what the window shows
---@field cond? ObviGuideCond     the line is shown (and counts) only while this holds
---@field done? ObviGuideCond     the line is done while this holds (besides what its kind checks)
---@field optional? boolean  not needed for its step to be done; shows its own state
---@field option? ObviGuideOption  the place to choose from it belongs to (a talk line): shown only while it's chosen
---@field craft? integer         the recipe (spell) the line makes: clicking it or its action key crafts it
---@field craftCount? integer    how many to make (nil: all you can)
---@field craftSkill? string     its profession (English name), from its step's skill line
---@field craftFrom? integer     the skill its range starts at (with craftTo: only what the points left need is made)
---@field craftTo? integer       the skill its step reaches
---@field craftItem? integer     with craftCount: make up to that many of this item in your bags
---@field orGroup? string        lines with the same group are alternatives: once orCount of them are done, the
---@field orCount? integer       step counts them all as done (default 1)
---@field finishes? boolean      once this line is done, so is the step (Zygor's confirm lines)
---@field with? ObviGuideGoal[]   done once these are (a sticky's "kill wolves" with its "collect 8 meat")
---@field closes? "trainer"|"vendor"   done once its target's trainer or merchant window is closed again
---@field opens? string         clicking the line opens this guide (its id or title) in a tab of its own
---@field quest? integer
---@field objective? integer
---@field id? integer            npc, item or spell id, by kind
---@field count? integer
---@field range? {[1]: string, [2]: integer, [3]: integer}   a collect line's skill range: only what the points left need
---@field keep? integer          a sell line: how many to keep (what the guide still needs); the rest is to sell
---@field toMake? {item: integer, count: integer, each: integer}   a collect line for parts to make: needs the reagents
---  for the ones still to make (count less what's in your bags, so many each)
---@field places? {point: ObviGuidePoint, name?: string}[]   where to get it (a collect line): clicking it shows the way
---  to the nearest
---@field need? integer        done once its quest objective has reached this many (part of the objective)
---@field flight? string       a "get the flight path" line: the flight point's name (done once the game lists it discovered)
---@field gossip? integer      a "Select …" line: the dialogue option's id (the action key picks it while it shows)
---@field level? integer        for 'level' the level; for 'skill' the profession skill to reach
---@field skill? string         for 'skill': the profession, by its English name ("Mining")
---@field cap? integer          for 'skill': done once the profession's cap is this high (a rank trained)
---@field xp? integer
---@field point? ObviGuidePoint   for 'goto'; on other lines their own spot, offered as a waypoint on hover
---@field mobName? string        parser use: the name a 'kill' goal matches against .mob lines
---@field what? string           what the progress counts, when the text doesn't say it ("Abandoned Belongings")
---@field target? ObviGuideTarget  who clicking the line (or its action key) targets
---@field targets? ObviGuideTarget[]  all of them, in order, when the line names several
---@field box? ObviGuideGoal[]   a side task's line: all the lines of its side box (shown or hidden together)
---@field note? boolean         a note shown as a line of its own (it looks like the step's notes)
---                                (target is the first)

---@alias ObviGuideCond table     a compiled condition tree, see Conditions.lua

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

-- Events: game events and our own ("OBVIGUIDE_STEP", ...) go through the same hub.
local handlers = {} ---@type table<string, ObviGuideHandler[]>
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...) ns:Fire(event, ...) end)

function ns:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		if not event:find("^OBVIGUIDE_") then
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
	print("|cff4fc3f7Obvi Guide|r: " .. (select("#", ...) > 0 and fmt:format(...) or fmt))
end

function ns.Debug(fmt, ...)
	if ns.debug then ns.Print("|cff888888" .. fmt .. "|r", ...) end
end

-- Guides added before our saved variables exist (packs load after us, but before ADDON_LOADED fires for them)
-- are parsed right away; nothing in parsing needs the saved variables.
ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	ObviGuideDB = ObviGuideDB or {}
	ObviGuideCharDB = ObviGuideCharDB or {}
	ns.db, ns.charDB = ObviGuideDB, ObviGuideCharDB
end)

-- The public API, for guide packs: a small addon with "## Dependencies: ObviGuide" whose files call
--   ObviGuide.Add("rxp", [[ ...guide text... ]])
-- Another guide syntax comes as a format an addon adds (ObviGuide.AddFormat), building its guides with ObviGuide's
-- helpers (ObviGuide.Toolkit); a format may take more than the text (a third argument, meta).
-- ObviGuide never reads other addons' files or data: guides come in only through these calls.
---@class ObviGuideAPI
ObviGuide = ObviGuide or {}

---@param source string
---@param warnings? string[]
local function Warnings(source, warnings)
	for _, w in ipairs(warnings or {}) do
		table.insert(ns.warnings, source .. ": " .. w)
		ns.Debug("%s: %s", source, w)
	end
end

-- a pack may add thousands of guides in one go: the list is told once, on the next frame
local announced = false
local function Announce()
	if announced then return end
	announced = true
	C_Timer.After(0, function() announced = false ns:Fire("OBVIGUIDE_GUIDES_ADDED") end)
end

--- Adds guides. A format that can list a guide from its meta alone (it has Head) keeps the text and reads it when the
--- guide is first opened; the text may then also be a function that returns it, called at that moment.
---@param format string   "rxp" (RestedXP guide syntax), or a format an addon added (ObviGuide.AddFormat)
---@param text string|(fun(): string)   the guide text (one or more guides)
---@param meta? table     what the format needs besides the text
---@return integer added  how many guides were added
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.Add(format, text, meta)
	local parser = ns.Parsers[format]
	local source = (debugstack(2, 1, 0) or ""):match("AddOns[\\/]([^\\/]+)") or "?"
	if not parser then ns.Print("unknown guide format '%s' (from %s)", tostring(format), source) return 0 end
	if parser.Head and type(meta) == "table" then
		local ok, g, warnings = pcall(parser.Head, source, meta)
		if not ok then ns.Print("could not read a %s guide from %s: %s", format, source, tostring(g)) return 0 end
		Warnings(source, warnings)
		if not g then return 0 end
		g.pending = { text = text, meta = meta }
		table.insert(ns.guides, g)
		Announce()
		return 1
	end
	local ok, guides, warnings = pcall(function()
		return parser.Parse(type(text) == "function" and text() or text --[[@as string]], source, meta)
	end)
	if not ok then ns.Print("could not read a %s guide from %s: %s", format, source, tostring(guides)) return 0 end
	Warnings(source, warnings)
	for _, g in ipairs(guides) do table.insert(ns.guides, g) end
	Announce()
	return #guides
end

--- Adds a guide format: a reader for another guide syntax, so ObviGuide.Add takes guides written in it. An addon that
--- reads some other addon's guides brings its own reader this way; ObviGuide itself reads its own format and
--- RestedXP's.
---@param id string               the name ObviGuide.Add is called with
---@param parser ObviGuideParser
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.AddFormat(id, parser)
	ns.Parsers[id] = parser
end

--- What a format's reader builds guides with: the condition helpers (Conditions.All, Conditions.RACES, ...) and the
--- colours names are written in (Colors).
---@return {Conditions: ObviGuideConditions, Colors: table<string, string>}
---@diagnostic disable-next-line: duplicate-set-field
function ObviGuide.Toolkit()
	return { Conditions = ns.Conditions, Colors = ns.Colors }
end

--- Reads a pending guide's text now (its first use). Returns the guide, or nil when it turns out unreadable: then it
--- is taken off the list.
---@param g ObviGuideGuide
---@return ObviGuideGuide?
function ns.Ready(g)
	local p = g.pending
	if not p then return g end
	g.pending = nil
	local text, meta = p.text, p.meta
	local ok, guides, warnings = pcall(function()
		return ns.Parsers[g.format].Parse(type(text) == "function" and text() or text --[[@as string]], g.source, meta)
	end)
	local full = ok and guides[1]
	if full then
		g.steps = full.steps
		Warnings(g.source, warnings)
		return g
	end
	for i, other in ipairs(ns.guides) do if other == g then table.remove(ns.guides, i) break end end
	ns.Print("could not read the guide '%s' from %s: %s", g.title, g.source,
		ok and tostring(warnings and warnings[1] or "no steps") or tostring(guides))
	Announce()
end

--- Whether this client has pings (the /ping command).
---@return boolean
function ns.CanPing()
	return C_Ping ~= nil and (not C_Ping.IsPingSystemEnabled or C_Ping.IsPingSystemEnabled() == true)
end

--- The macro that targets someone by name and puts a raid marker on them (skull for enemies, star for NPCs), like
--- Zygor's target buttons. Only slash commands: SetRaidTarget is Blizzard-only on this client, and a /run line in an
--- addon's macro is tainted (the game blocks it). /tm toggles, so "/tm 0" clears first and "/tm N" then always sets.
--- Several names (a line naming several mobs): the first one found, trying them in the order given.
--- Where the client has pings, the target is pinged too (contextual: attack on an enemy, assist on an NPC), so a group
--- sees it as well. Each is a setting (marker, ping).
--- keep: the target (one of these names) is tagged by someone else, so the macro doesn't let go of it first: targeting
--- the same name again goes on to the next one, as it does from a corpse.
---@param name string|string[]
---@param enemy? boolean
---@param keep? boolean
---@return string
function ns.TargetMacro(name, enemy, keep)
	local clear = keep and "" or "/cleartarget\n"
	local db = ns.db or {}
	local mark = ""
	if db.marker ~= false then
		mark = mark .. ("\n/tm [@target,exists] 0\n/tm [@target,exists] %d"):format(enemy and 8 or 1)
	end
	if db.ping ~= false and ns.CanPing() then mark = mark .. "\n/ping [@target,exists]" end
	mark = mark:sub(2)
	if type(name) == "table" and #name > 1 then
		-- each next name only while nothing (living) is targeted yet; a macro can't pick the nearest of two names
		local target = clear
		for i, n in ipairs(name) do
			target = target .. (i == 1 and "/targetexact %s\n" or "/targetexact [noexists] %s\n"):format(n)
			if enemy then target = target .. ("/targetexact [dead] %s\n/cleartarget [dead]\n"):format(n) end
		end
		return target .. mark
	end
	if type(name) == "table" then name = name[1] end
	local target = clear .. ("/targetexact %s\n"):format(name)
	if enemy then
		-- /targetexact takes the nearest match, dead or not; while the target is dead, targeting the same name again
		-- cycles on to the next match. Guides often name mobs in the plural ("Bandit Highwaymen"), so when the exact
		-- name finds nothing, a partial match on the name minus its last two letters tries again ("Bandit Highwaym").
		-- A corpse still left at the end is let go.
		local stem = #name > 6 and name:sub(1, -3) or name
		target = target .. ("/targetexact [dead] %s\n/target [noexists] %s\n/target [dead] %s\n/cleartarget [dead]\n")
			:format(name, stem, stem)
	end
	return target .. mark
end

--- The guide with this title or name, read and ready to follow.
---@param title string
---@return ObviGuideGuide?
function ns.FindGuide(title)
	for _, g in ipairs(ns.guides) do if g.title == title or g.name == title then return ns.Ready(g) end end
end
