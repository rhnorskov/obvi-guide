---@meta
-- ObviGuide's guide-writing API: types only, for the editor (LuaLS). The game never loads this file; the real
-- functions live in the addon. Add this folder to your LuaLS workspace library to get autocomplete while writing a
-- guide pack. Builder.lua implements it. See FORMAT.md for how a guide reads.

---@class ObviGuideAPI
ObviGuide = {}

--- Adds a guide. `build` is called right away with the guide to fill in.
---@param build fun(g: ObviGuideGuideBuilder)
function ObviGuide.Guide(build) end

--- Adds guides written in another guide format. A format that can list a guide from its meta alone keeps the text
--- and reads it when the guide is first opened; the text may then also be a function that returns it.
---@param format string   "rxp" (RestedXP guide syntax), or a format an addon added (ObviGuide.AddFormat)
---@param text string|(fun(): string)   the guide text (one or more guides)
---@param meta? table     what the format needs besides the text
---@return integer added  how many guides were added
function ObviGuide.Add(format, text, meta) end

--- Adds a guide format: a reader for another guide syntax, so ObviGuide.Add takes guides written in it. The reader
--- has Parse(text, source, meta) -> guides, warnings; optionally Head(source, meta) -> one guide listed from its meta
--- alone (its text is then read when it is first opened) and Names(text) -> the quest and NPC names in the text (for
--- the guide picker's search). The guides it returns are ObviGuide's own model (Core.lua).
---@param id string       the name ObviGuide.Add is called with
---@param parser table
function ObviGuide.AddFormat(id, parser) end

--- What a format's reader builds guides with: the condition helpers and the colours names are written in.
---@return {Conditions: table, Colors: table<string, string>}
function ObviGuide.Toolkit() end

--- Opens a guide (by title or id) in the window at its first step, without the ticks of an earlier run. A guide
--- added again with the same id from the same addon replaces the old one, so a tool can add, edit and reopen a draft.
---@param title string
function ObviGuide.Load(title) end

--- A guide as Obvi Guide holds it (the model in Core.lua: what the window shows, whatever format it came in).
--- Read it, don't change it.
---@class ObviGuideModel
---@field title string
---@field group string         its folder in the guide list
---@field name? string         its id
---@field next? string
---@field format string        "obviguide", "rxp", or a format an addon added
---@field source string        the addon that added it
---@field steps table[]        empty until read (see ObviGuide.Read)

--- The guides added this session, in order.
---@return ObviGuideModel[]
function ObviGuide.List() end

--- A guide from ObviGuide.List with its steps read (some formats are read only when first opened); nil when it
--- turns out unreadable.
---@param guide ObviGuideModel
---@return ObviGuideModel?
function ObviGuide.Read(guide) end

--- A condition, as a short string: words joined with `and`, `or`, `not` and parentheses; `/` is a short `or`.
--- Words: `Alliance`, `Horde`, class names (`Warrior`, `Mage`, ...), race names (`Skyborne`, `Human`, ...),
--- `level < 10`, `level >= 10`, `onquest 123`, `ready 123`, `done 123`, `knows 123` (spell), `items 123 >= 5`,
--- `items 123 < 5`, `area 123` (subzone), `map 123`, `nomap` (somewhere without a map), `aura 123`,
--- `skill Mining >= 75`, `skill Mining < 75` (a profession's skill by its English name; one you haven't got is 0).
--- Checked when the guide loads; mistakes are reported in chat.
--- Examples: `"Alliance and not Shaman"`, `"Horde/Shaman"`, `"done 92703 or area 16638"`.
---@alias ObviGuideCondition string

--- Something the text names: an NPC, an enemy, an item... The window gives each kind its own look (colour, icon),
--- and lines use it to target, use or cast. Make one with the guide's marker functions (`g.Npc(...)` and so on).
---@class ObviGuideMarker

--- Text: plain strings and markers, in order. `"Talk to ", g.Npc("Aamelia Windfield", 252800), " upstairs."`
---@alias ObviGuideText string|ObviGuideMarker

-- ---------------------------------------------------------------------------------------------------------------
-- The guide

---@class ObviGuideGuideBuilder
---@field title string                 what the guide list shows (required)
---@field group? string                the folder it is listed under
---@field next? string                 the guide that follows when this one ends (its title or id)
---@field id? string                   another name `next` may use for this guide
---@field only? ObviGuideCondition      the guide is listed only for characters that match
---@field challenge? integer           the challenge (achievement) the guide leads through: the game's challenges window
---                                    gets a button on it that opens the guide
local Guide = {}

--- A step: a few lines done together, in one place. `build` fills it in.
---@param build fun(s: ObviGuideStepBuilder)
function Guide:Step(build) end

--- Side tasks: shown under the steps from here up to and including the step labelled `untilStep` ("next": the next
--- step). They never hold a step up, and disappear early once done. RestedXP's `#completewith`, Zygor's sticky steps.
---@param untilStep string
---@param build fun(s: ObviGuideSideBuilder)
function Guide:Side(untilStep, build) end

-- Markers. The name is required; the id is optional but recommended: with it, ObviGuide shows the game's own name in
-- the player's language once the game has it (and targets by it), and the written name until then.

--- A friendly NPC.
---@param name string
---@param id? integer   creature id
---@return ObviGuideMarker
function Guide.Npc(name, id) end

--- An enemy.
---@param name string
---@param id? integer   creature id
---@return ObviGuideMarker
function Guide.Mob(name, id) end

--- An item (shown with its icon).
---@param name string
---@param id? integer   item id
---@return ObviGuideMarker
function Guide.Item(name, id) end

--- A spell or ability (shown with its icon).
---@param name string
---@param id? integer   spell id
---@return ObviGuideMarker
function Guide.Spell(name, id) end

--- Something in the world to click: a chest, a crystal, a stump.
---@param name string
---@return ObviGuideMarker
function Guide.Object(name) end

--- A warning.
---@param ... ObviGuideText
---@return ObviGuideMarker
function Guide.Warn(...) end

--- Something to buy.
---@param ... ObviGuideText
---@return ObviGuideMarker
function Guide.Buy(...) end

-- ---------------------------------------------------------------------------------------------------------------
-- Steps and side tasks: the same lines; a step also has a label and a skip condition

---@class ObviGuideLinesBuilder
---@field only? ObviGuideCondition      shown only while this holds (a step that doesn't apply is passed over)
local Lines = {}

---@class ObviGuideStepBuilder : ObviGuideLinesBuilder
---@field label? string                a name for `g:Side(untilStep)` to refer to
---@field skip? ObviGuideCondition      counts as done while this holds, e.g. "area 16638" (already in Valanaar)

---@class ObviGuideSideBuilder : ObviGuideLinesBuilder

--- A line, returned by every line method so options can be chained: `s:Accept(92703):Only("Alliance")`.
---@class ObviGuideLine
local Line = {}

--- The line is shown (and counts) only while this holds.
---@param condition ObviGuideCondition
---@return ObviGuideLine
function Line:Only(condition) end

--- The step's destination. Done when you come within `radius` yards (default 10).
---@param map integer      uiMapID
---@param x number         0-100, as the map shows it
---@param y number         0-100
---@param radius? integer
---@return ObviGuideLine
function Lines:Goto(map, x, y, radius) end

--- A point along the way to the destination.
---@param map integer
---@param x number
---@param y number
---@return ObviGuideLine
function Lines:Path(map, x, y) end

--- Talk to an NPC. The line and an action key target them.
---@param npc ObviGuideMarker   g.Npc(...)
---@return ObviGuideLine
function Lines:Talk(npc) end

--- Accept a quest. Done once it is in your log (or done).
---@param quest integer
---@param title? string
---@return ObviGuideLine
function Lines:Accept(quest, title) end

--- Turn in a quest. Done once it is turned in.
---@param quest integer
---@param title? string
---@return ObviGuideLine
function Lines:Turnin(quest, title) end

--- Complete one objective of a quest. Done once that objective is.
---@param quest integer
---@param objective integer
---@param ... ObviGuideText   what the line says (default: the objective's own text)
---@return ObviGuideLine
function Lines:Quest(quest, objective, ...) end

---@class ObviGuideCountOptions
---@field count? integer
---@field quest? integer       with `objective`: done once that quest objective is
---@field objective? integer

--- Kill mobs. The line and an action key target them.
---@param mob ObviGuideMarker   g.Mob(...)
---@param options? ObviGuideCountOptions
---@return ObviGuideLine
function Lines:Kill(mob, options) end

--- Get items. Done once you have the count (or the quest objective is done).
---@param item ObviGuideMarker   g.Item(...)
---@param options? ObviGuideCountOptions
---@return ObviGuideLine
function Lines:Collect(item, options) end

--- Use an item. The line and an action key use it.
---@param item ObviGuideMarker
---@return ObviGuideLine
function Lines:Use(item) end

--- Put an item on. The line and an action key equip it. Done once it is equipped.
---@param item ObviGuideMarker
---@return ObviGuideLine
function Lines:Equip(item) end

--- Cast a spell. The line and an action key cast it.
---@param spell ObviGuideMarker   g.Spell(...)
---@return ObviGuideLine
function Lines:Cast(spell) end

--- Learn a spell from a trainer. Done once you know it.
---@param spell ObviGuideMarker
---@return ObviGuideLine
function Lines:Learn(spell) end

--- Use your Hearthstone. The line and an action key use it. Done once you cast it.
---@param place? string
---@return ObviGuideLine
function Lines:Hearth(place) end

--- Make an inn your home. Done once your Hearthstone is set there.
---@param place string
---@return ObviGuideLine
function Lines:Home(place) end

--- Take a flight.
---@param place string
---@return ObviGuideLine
function Lines:Fly(place) end

--- Reach a level (and some XP into it).
---@param level integer
---@param xp? integer
---@return ObviGuideLine
function Lines:Level(level, xp) end

--- Reach a skill level in a profession. Done once your skill is that high.
---@param profession string   its English name: "Mining", "Blacksmithing", "First Aid"...
---@param level integer
---@return ObviGuideLine
function Lines:Skill(profession, level) end

--- Learn a profession, or train a rank of it, at a trainer. Without `cap`: done once you have the profession. With
--- it: done once your skill cap is that high (75 Apprentice, 150 Journeyman, 225 Expert, 300 Artisan; the line is
--- named after the rank).
---@param profession string   its English name
---@param cap? integer
---@return ObviGuideLine
function Lines:Train(profession, cap) end

--- Discover an area: one criterion of an exploration challenge ("Explore Alterac Mountains"). Done once the game
--- counts the area as found; where the game has no achievements, the player ticks it off. The area is found in the
--- challenge's list by one of its ids, or else by its name (which only matches in an English game).
---@param achievement integer           the challenge's (achievement's) id
---@param name string                   the area's name, as the challenge lists it
---@param ids? integer|integer[]        the area's criteria tree id and/or criterion id
---@return ObviGuideLine
function Lines:Explore(achievement, name, ids) end

--- A challenge (achievement) still to finish, as one of the parts of a bigger one: shown only until it is finished,
--- and clicking it opens the guide that leads through it, in a tab of its own. Done once the challenge is finished.
---@param achievement integer   the challenge's (achievement's) id
---@param guide string          the guide's id or title
---@param ... ObviGuideText      the line's text (default: the guide)
---@return ObviGuideLine
function Lines:Challenge(achievement, guide, ...) end

--- An instruction the player ticks off by clicking it.
---@param ... ObviGuideText
---@return ObviGuideLine
function Lines:Do(...) end

--- Plain text: an instruction with nothing to tick off.
---@param ... ObviGuideText
---@return ObviGuideLine
function Lines:Say(...) end

--- A note, shown right after the line above it.
---@param ... ObviGuideText
---@return ObviGuideLine
function Lines:Note(...) end
