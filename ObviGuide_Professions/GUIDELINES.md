# Writing a profession guide

How the profession guides in this pack are built, so each one works the same way. The guide format itself is in
[FORMAT.md](../ObviGuide/docs/FORMAT.md).

## Write the data, not the steps

A profession guide is data: [Engineering.lua](Engineering.lua), [Blacksmithing.lua](Blacksmithing.lua) and
[FirstAid.lua](FirstAid.lua) are written so. [Profession.lua](Profession.lua) makes the steps from it by the rules
below (`pack.Guide`), so they hold for every guide without writing them again. (Mining and Fishing and Cooking are
gathering routes, written as steps.)
The data:

- **route**: the site's ranges, `{ from, to, "Recipe" }`, or `{ from, to, { "Recipe", count } }` where the site's
  count isn't one per point; more recipes after the first for a range that makes several. Per range: `anvil`, `note`,
  `alt` (a choice: one note, and no materials step).
- **recipes**: by name, each one's `spell`, `item`, `learn` (the skill it's learned at) and `reagents` (item id ->
  per craft); `known` (with the profession), `tool` (made once, kept). Taught by plans, a schematic or a manual:
  `teach` (the item, used), with `sold` (where it's bought: one table per seller, so all of a seller's are bought in
  one visit), `quest` (a quest that gives it: id, title, who, level, a quest to take first, what it asks for) or
  `source` (a note: it drops). Taught by someone else: `at`. A trainer rank other than the one above its skill:
  `tier` (First Aid's trainers teach Silk Bandage).
- **trainers** by the highest rank they train (75, 150, 225, 300); **ranks** (cap, skill, level; a rank the trainers
  don't teach: `book` and `sold`, or `at`, with `items` to hand in and a `note`); **tools** to buy at the start; **buy**
  (reagents from vendors: where); **items** (the names of raw materials, tools and plans); `intro` (a note for the
  introduction, for what holds for every recipe).

The visits, materials, kept parts, purchases and totals are worked out from that. Check the result with
`tools/build-guide.lua` (below).

## Sources

- **The route** (ranges, recipes, counts, alternatives): wow-professions.com's WoW Forever guide for the profession,
  credited in the file's header, the first step's note and the [README](README.md).
- **Recipes** (each one's spell, the item it makes, the skill it's learned at, the plans or schematic that teach it):
  WhatsTraining's Forever recipe list, `WhatsTraining/Crafting/Recipes/Camelot/<Profession>.lua`; their reagents from
  Zygor's Forever recipe data, `Data-Forever/Tradeskill_Recipes.lua`. The skill in WhatsTraining's list is the one
  Forever uses, which can differ from Classic's (Imperial Plate) and from the site.
- **Trainers and vendors** (ids, positions): Zygor's Forever data, `Data-Forever/NPCData.lua` (`TrainerEngineering`,
  ...) and its profession guides; QuestieDB.
- Where we differ from the site, say so in the header comment and the [changelog](CHANGELOG.md), in a line each.

## The guide, step by step

The route is a run of skill ranges:

1. **Introduction**, ticked by hand: the counts are for a point per craft, and a yellow recipe needs a few more
   (with the credit note). Pressing a Make line again makes what the points still left need.
2. **Prerequisites**: collect the tools (Blacksmith Hammer, ...) at the nearest seller.
3. **Learn the profession** at the nearest trainer of the lowest rank.
4. **Per range**:
   - **a step for each part** it makes that later ranges use (below): "Make 30 Heavy Blasting Powder";
   - then **the range**, done by the skill alone (`Skill(profession, end)`; passed over once past it): its
     materials, `Collect` lines for the points left (`range`: they go down as you make them), and "Make ... to N",
     naming its recipe and range (`:Crafts(spell, N, from)`), so clicking it or its action key opens the
     profession and makes what the points left need. It makes what the range makes for the points; a range that
     makes only parts levels on its last one ("Make Whirring Bronze Gizmo to 150").

   The materials show what's in your bags but are optional: they don't hold a step.
5. **Trainer visits**, a step of their own just before the range that needs them: what can be learned then that
   the guide needs, and the rank-ups (Journeyman 50, Expert 125, Artisan 200) that can be trained (below).

### Trainer visits: learn everything a visit can

Profession.lua works these out from the recipes' learn levels:

- **A visit comes only where a range needs it**: a recipe you don't know yet, or a cap you haven't got. It's a step
  of its own, just before that range; the range steps never go to a trainer.
- **One visit teaches everything the guide still needs that's learnable at that skill**: e.g. at 30 the bolts and
  the bombs; at 75 Coarse Blasting Powder and Coarse Dynamite (and Journeyman).
- **A rank-up goes with the first visit that can train it.** Optional there when nothing before the next visit goes
  past your cap (it may need a level you haven't got: Expert, 20), required at the visit that needs it.
- **A visit is passed over** once you're past the last range that makes what it teaches.
- **The trainer is the nearest who teaches all of it**: a trainer teaches the recipes and ranks below the highest
  rank they train (the data lists them by it).
- Learn and Train lines can be clicked at the open trainer to train them, and the action key trains the next one,
  so a visit with several is quick.

### Places: the nearest of several

A trainer or vendor step lists every place the site names (the cities, Kharanos, Auberdine, Darkshire, Zephras Isle,
...) and goes to the nearest (`nearest = true`, the `At` helper with a list of `P(map, x, y, npc, also)`). Not "the
one for your race". A place on another continent only counts when nothing is on yours.

Only list a place for what it can do: an Apprentice-only trainer is no place to learn a Journeyman recipe.

### Parts made for later

A part made in one range and used in a later one (bolts, blasting powder, grinding stones) gets a step of its own
before its range: "Make N ...", as many as the later ranges use (worked out from them, never written by hand),
`:CraftsUpTo` (it makes what's still missing), with its materials for the ones still to make (`toMake`). Done once
they're in your bags; passed over once the last range that uses them is done. A tool (the spanner): one, for good.

### Purchases

- A material sold by vendors (Weak Flux) is a materials line like any other, in the range that uses it, with where
  it's sold (`at`): clicking the line shows the way to the nearest seller.
- Plans and schematics: a step at the seller just before the range, `s:Do(g.Buy("Buy the "), item, "."):Done(...)`,
  then learned by using them: a `Use` line with `:Done("knows <spell>")`.

### Choices

Where the site gives a choice (Silver Contacts or Flying Tiger Goggles), the guide follows the main option and the
other is one note: "Or 5 Flying Tiger Goggles, if Silver Bars are dear." No materials step for that range; count the
main option into the totals by hand (`Count`).

### The totals

A side box beside every step, from the first to the last (`g:Side("last", ...)`, the last step labelled `last`),
lists the raw materials the ranges you haven't started need, against what's in your bags. The parts you make are
left out. It's built from the ranges' materials, so it stays right as the route changes.

### To sell

A second side box beside every step lists the guide's items in your bags beyond what the ranges not done yet need
(the one you're in too): what it makes only for the points (bombs, scopes), and spare materials. Not the tools,
plans or schematics. A line (`Sell(item, keep)`) shows only while you have spare, and only if vendors buy it.

## Text

Short. The player finds things out themselves; a note is only for what they can't see or would get wrong:

- **Yes**: "At an anvil." (where the trainer has none), "Journeyman needs level 10.", "Bind on pickup.", a choice in
  one line, which parts to keep for a specialization.
- **No**: why the route goes this way, where ore comes from, lists of anvils or vendors, "yellow from 60",
  "keep these for X" (the step checks it), totals already in the totals box.

Prefer a line the game can check (a `Collect`, a `Learn`, a `:Done`) over a note that asks the player to remember.

## Checking

- `tools/check.ps1`: the type check, no warnings.
- `lua-language-server tools/build-guide.lua . ObviGuide_Professions/Profession.lua ObviGuide_Professions/<Guide>.lua`:
  builds the guide outside the game and lists each step's places, its lines and the totals box with their conditions.
- In game: walk the first few ranges, a trainer visit with several things to learn, and a place choice from two
  starting zones.
