# Writing AnyGuide guides (draft)

AnyGuide guides are written in Lua, with a small set of functions. The full API, with types for your editor, is in
[api.lua](api.lua): add the `docs` folder to your LuaLS workspace library and you get autocomplete, hover docs and
warnings for typos and missing arguments while you write.

RestedXP and Zygor guides are translated into the same calls in game, when a guide pack adds them, so every guide is
shown the same way whatever it was written in.

Status: draft for review. Builder.lua implements it; RestedXP guides still come in through their own reader.

## A guide pack

A guide pack is a small addon with `## Dependencies: AnyGuide`. Its files either call the API below, or hand over
guide text in another format:

```lua
AnyGuide.Add("rxp", [[ ...RestedXP guide text... ]])     -- translated into the calls below
AnyGuide.Add("zygor", [[ ...Zygor guide text... ]])      -- later
```

## A guide

```lua
AnyGuide.Guide(function(g)
	g.title = "9-13 Skyborne"
	g.group = "My guides"
	g.next  = "13-15 Lowlands"
	g.only  = "Alliance"

	g:Step(function(s)
		s.label = "Deliver the News"
		s:Goto(2521, 47.51, 78.44)
		s:Talk(g.Npc("Aamelia Windfield", 252800))
		s:Turnin(92693, "Standing Our Ground")
		s:Accept(92703, "Deliver the News"):Only("Alliance")
		s:Note("Turn it in right away; ", g.Npc("Aamelia Windfield", 252800), " soon walks back.")
	end)

	g:Side("next", function(s)
		s.only = "Alliance"
		s:Kill(g.Mob("Skyhopper", 251314), { quest = 93949, objective = 1 })
	end)
end)
```

- **The guide** has a `title` (required), and optionally a `group` (the folder in the guide list), the `next` guide,
  an `id` other guides' `next` may use, and `only` (who it is listed for).
- **A step** (`g:Step`) is a few lines done together. It may have a `label`, `only` (shown only while it holds;
  otherwise passed over) and `skip` (counts as done while it holds, e.g. "already in Valanaar"). A step is done when
  all of its lines that can be done are done.
- **Side tasks** (`g:Side(untilStep, ...)`) are shown with each step from here up to and including the step labelled
  `untilStep` (`"next"`: the next step). They never hold a step up and disappear early once done.
- **Lines** are added in the order you write them. Each returns the line, so options chain:
  `s:Accept(92703):Only("Alliance")`. A `s:Note(...)` follows the line above it.

## Lines

| Line | Meaning | Done when |
|---|---|---|
| `Goto(map, x, y, radius?)` | The step's destination (coordinates 0-100, as the map shows). | You come within the radius (default 10). |
| `Path(map, x, y)` | A point along the way. | - |
| `Talk(npc)` | Talk to an NPC; the line and an action key target them. | - |
| `Accept(quest, title?)` | Accept a quest. | It is in your log (or done). |
| `Turnin(quest, title?)` | Turn in a quest. | It is turned in. |
| `Quest(quest, objective, text...)` | Complete one quest objective. | That objective is complete. |
| `Kill(mob, {count, quest, objective}?)` | Kill mobs; the line and an action key target them. | The objective (if given) is complete. |
| `Collect(item, {count, quest, objective}?)` | Get items. | You have the count (or the objective is complete). |
| `Use(item)` | Use an item; the line and an action key use it. | - |
| `Equip(item)` | Put an item on; the line and an action key equip it. | It is equipped. |
| `Cast(spell)` | Cast a spell; the line and an action key cast it. | - |
| `Learn(spell)` | Learn a spell (trainer). | You know it. |
| `Hearth(place?)` | Use your Hearthstone; the line and an action key use it. | You cast it. |
| `Home(place)` | Make an inn your home. | Your Hearthstone is set there. |
| `Fly(place)` | Take a flight. | - |
| `Level(level, xp?)` | Reach a level (and XP into it). | You are there. |
| `Do(text...)` | An instruction the player ticks off by clicking it. | Clicked. |
| `Say(text...)` | Plain text: an instruction with nothing to tick off. | - |
| `Note(text...)` | A note, shown right after the line above it. | - |

Every line can be limited with `:Only(condition)`.

## Markers

Inside text, markers say what a word is; the window draws each kind its own way, and lines use them to target, use or
cast: `g.Npc(name, id?)`, `g.Mob(name, id?)`, `g.Item(name, id?)`, `g.Spell(name, id?)`, `g.Object(name)`,
`g.Warn(text...)`, `g.Buy(text...)`.

The name is required; the id is optional but recommended. With an id, AnyGuide uses the game's own name in the
player's language once the game has it (always for spells, a moment after asking for items and creatures), and the
written name until then. Tested in game on 2026-10-19 with all 176 creatures in the Skyborne guide: 116 known right
away, 175 a few seconds after asking; the one left was not a creature. Items in the same guide: 39 of 59 right away,
all 59 after asking. Guides often shorten or pluralise names ("Vuldren" for "Vuldren Alpha"), so the game's name is
also the better one to target by.

## Conditions

Conditions (`only`, `skip`, `:Only(...)`) are short strings: words joined with `and`, `or`, `not` and parentheses;
`/` is a short `or`. They are checked when the guide loads, and mistakes are reported in chat.

| Word | Holds when |
|---|---|
| `Alliance`, `Horde` | Your faction. |
| `Warrior`, `Mage`, ... | Your class. |
| `Skyborne`, `Human`, ... | Your race. |
| `level < 10`, `level >= 10` | Your level. |
| `onquest 123` / `ready 123` / `done 123` | The quest is in your log / ready to turn in / turned in. |
| `knows 123` | You know the spell. |
| `items 123 >= 5`, `items 123 < 5` | How many of the item you have. |
| `area 123` / `map 123` | You are in that subzone / on that map. |
| `nomap` | You are somewhere without a map (a dungeon). |
| `aura 123` | You have that buff or debuff. |

Examples: `"Alliance and not Shaman"`, `"Horde/Shaman"`, `"done 92703 or area 16638"`.

## Decided

- `Say` and `Do` stay separate: plain text versus something to tick off (RestedXP's `>>` and `+` lines).
- Coordinates are 0-100, as the map shows them.
- Names are required in markers; ids are optional.

## Open

- Zygor features with no line type yet (e.g. `|only if`, `|n`, gossip choices) are mapped when the Zygor translator
  is written.
- `/ag export` will print a guide (or the current step) in this form, to copy and edit.
