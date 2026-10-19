---@meta
-- AnyGuide's guide-writing API: types only, for the editor (LuaLS). The game never loads this file; the real
-- functions live in the addon. Add this folder to your LuaLS workspace library to get autocomplete while writing a
-- guide pack. Builder.lua implements it. See FORMAT.md for how a guide reads.

---@class AnyGuideAPI
AnyGuide = {}

--- Adds a guide. `build` is called right away with the guide to fill in.
---@param build fun(g: AnyGuideGuideBuilder)
function AnyGuide.Guide(build) end

--- A condition, as a short string: words joined with `and`, `or`, `not` and parentheses; `/` is a short `or`.
--- Words: `Alliance`, `Horde`, class names (`Warrior`, `Mage`, ...), race names (`Skyborne`, `Human`, ...),
--- `level < 10`, `level >= 10`, `onquest 123`, `ready 123`, `done 123`, `knows 123` (spell), `items 123 >= 5`,
--- `items 123 < 5`, `area 123` (subzone), `map 123`, `nomap` (somewhere without a map), `aura 123`.
--- Checked when the guide loads; mistakes are reported in chat.
--- Examples: `"Alliance and not Shaman"`, `"Horde/Shaman"`, `"done 92703 or area 16638"`.
---@alias AnyGuideCondition string

--- Something the text names: an NPC, an enemy, an item... The window gives each kind its own look (colour, icon),
--- and lines use it to target, use or cast. Make one with the guide's marker functions (`g.Npc(...)` and so on).
---@class AnyGuideMarker

--- Text: plain strings and markers, in order. `"Talk to ", g.Npc("Aamelia Windfield", 252800), " upstairs."`
---@alias AnyGuideText string|AnyGuideMarker

-- ---------------------------------------------------------------------------------------------------------------
-- The guide

---@class AnyGuideGuideBuilder
---@field title string                 what the guide list shows (required)
---@field group? string                the folder it is listed under
---@field next? string                 the guide that follows when this one ends (its title or id)
---@field id? string                   another name `next` may use for this guide
---@field only? AnyGuideCondition      the guide is listed only for characters that match
local Guide = {}

--- A step: a few lines done together, in one place. `build` fills it in.
---@param build fun(s: AnyGuideStepBuilder)
function Guide:Step(build) end

--- Side tasks: shown under the steps from here up to and including the step labelled `untilStep` ("next": the next
--- step). They never hold a step up, and disappear early once done. RestedXP's `#completewith`, Zygor's sticky steps.
---@param untilStep string
---@param build fun(s: AnyGuideSideBuilder)
function Guide:Side(untilStep, build) end

-- Markers. The name is required; the id is optional but recommended: with it, AnyGuide shows the game's own name in
-- the player's language once the game has it (and targets by it), and the written name until then.

--- A friendly NPC.
---@param name string
---@param id? integer   creature id
---@return AnyGuideMarker
function Guide.Npc(name, id) end

--- An enemy.
---@param name string
---@param id? integer   creature id
---@return AnyGuideMarker
function Guide.Mob(name, id) end

--- An item (shown with its icon).
---@param name string
---@param id? integer   item id
---@return AnyGuideMarker
function Guide.Item(name, id) end

--- A spell or ability (shown with its icon).
---@param name string
---@param id? integer   spell id
---@return AnyGuideMarker
function Guide.Spell(name, id) end

--- Something in the world to click: a chest, a crystal, a stump.
---@param name string
---@return AnyGuideMarker
function Guide.Object(name) end

--- A warning.
---@param ... AnyGuideText
---@return AnyGuideMarker
function Guide.Warn(...) end

--- Something to buy.
---@param ... AnyGuideText
---@return AnyGuideMarker
function Guide.Buy(...) end

-- ---------------------------------------------------------------------------------------------------------------
-- Steps and side tasks: the same lines; a step also has a label and a skip condition

---@class AnyGuideLinesBuilder
---@field only? AnyGuideCondition      shown only while this holds (a step that doesn't apply is passed over)
local Lines = {}

---@class AnyGuideStepBuilder : AnyGuideLinesBuilder
---@field label? string                a name for `g:Side(untilStep)` to refer to
---@field skip? AnyGuideCondition      counts as done while this holds, e.g. "area 16638" (already in Valanaar)

---@class AnyGuideSideBuilder : AnyGuideLinesBuilder

--- A line, returned by every line method so options can be chained: `s:Accept(92703):Only("Alliance")`.
---@class AnyGuideLine
local Line = {}

--- The line is shown (and counts) only while this holds.
---@param condition AnyGuideCondition
---@return AnyGuideLine
function Line:Only(condition) end

--- The step's destination. Done when you come within `radius` yards (default 10).
---@param map integer      uiMapID
---@param x number         0-100, as the map shows it
---@param y number         0-100
---@param radius? integer
---@return AnyGuideLine
function Lines:Goto(map, x, y, radius) end

--- A point along the way to the destination.
---@param map integer
---@param x number
---@param y number
---@return AnyGuideLine
function Lines:Path(map, x, y) end

--- Talk to an NPC. The line and an action key target them.
---@param npc AnyGuideMarker   g.Npc(...)
---@return AnyGuideLine
function Lines:Talk(npc) end

--- Accept a quest. Done once it is in your log (or done).
---@param quest integer
---@param title? string
---@return AnyGuideLine
function Lines:Accept(quest, title) end

--- Turn in a quest. Done once it is turned in.
---@param quest integer
---@param title? string
---@return AnyGuideLine
function Lines:Turnin(quest, title) end

--- Complete one objective of a quest. Done once that objective is.
---@param quest integer
---@param objective integer
---@param ... AnyGuideText   what the line says (default: the objective's own text)
---@return AnyGuideLine
function Lines:Quest(quest, objective, ...) end

---@class AnyGuideCountOptions
---@field count? integer
---@field quest? integer       with `objective`: done once that quest objective is
---@field objective? integer

--- Kill mobs. The line and an action key target them.
---@param mob AnyGuideMarker   g.Mob(...)
---@param options? AnyGuideCountOptions
---@return AnyGuideLine
function Lines:Kill(mob, options) end

--- Get items. Done once you have the count (or the quest objective is done).
---@param item AnyGuideMarker   g.Item(...)
---@param options? AnyGuideCountOptions
---@return AnyGuideLine
function Lines:Collect(item, options) end

--- Use an item. The line and an action key use it.
---@param item AnyGuideMarker
---@return AnyGuideLine
function Lines:Use(item) end

--- Put an item on. The line and an action key equip it. Done once it is equipped.
---@param item AnyGuideMarker
---@return AnyGuideLine
function Lines:Equip(item) end

--- Cast a spell. The line and an action key cast it.
---@param spell AnyGuideMarker   g.Spell(...)
---@return AnyGuideLine
function Lines:Cast(spell) end

--- Learn a spell from a trainer. Done once you know it.
---@param spell AnyGuideMarker
---@return AnyGuideLine
function Lines:Learn(spell) end

--- Use your Hearthstone. The line and an action key use it. Done once you cast it.
---@param place? string
---@return AnyGuideLine
function Lines:Hearth(place) end

--- Make an inn your home. Done once your Hearthstone is set there.
---@param place string
---@return AnyGuideLine
function Lines:Home(place) end

--- Take a flight.
---@param place string
---@return AnyGuideLine
function Lines:Fly(place) end

--- Reach a level (and some XP into it).
---@param level integer
---@param xp? integer
---@return AnyGuideLine
function Lines:Level(level, xp) end

--- An instruction the player ticks off by clicking it.
---@param ... AnyGuideText
---@return AnyGuideLine
function Lines:Do(...) end

--- Plain text: an instruction with nothing to tick off.
---@param ... AnyGuideText
---@return AnyGuideLine
function Lines:Say(...) end

--- A note, shown right after the line above it.
---@param ... AnyGuideText
---@return AnyGuideLine
function Lines:Note(...) end
