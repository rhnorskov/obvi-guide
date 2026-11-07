# Obvi Guide

## Unreleased

- **Guide picker**: the gear beside the search is a menu now. Untick **Other faction's guides** to leave out the guides
  that are only for the other faction; **Settings** opens the settings as before.

## v0.4.0

- **Guide tabs**: several guides open at once, one shown. The title's menu lists them, with close buttons and Add guide.
- **Quest Catchup**: finds the earlier quests you skipped that the rest of the guide needs, and opens their steps as a
  short guide beside it that leads back when done. In the settings menu, or `/og catchup`. Needs QuestieDB.
- **Auto accept and turn in** only take the quests of the current and the next step; other quests are left alone.
- **Guide search** also lists the steps a quest or NPC is in, under its guide: click one to open the guide there.
- **Minimap dots** are coloured by what the step is about: red to kill, green for an NPC, blue to collect, purple to
  click.
- With Shortest Path Forever showing the way, the step's objective shows under its waypoint marker.
- Trainer and vendor lines tick off when you close the window.
- Flight paths you have are recognised more reliably.
- A quest line the game doesn't track (resurrecting Henze Faulk) no longer ticks off as soon as you take the quest.
- Quest chains whose quests share a title tick off properly when the game starts you further along the chain.
- Close buttons work in combat.
- Guide writers: `ObviGuide.AddFormat` and `ObviGuide.Toolkit` let other addons add guide formats.

## v0.3.1

- **Waypoint arrow**: Obvi Guide's own arrow points the way to the current step, with the objective and the distance.
  Settings > Waypoints picks how the way is shown instead: the arrow, Shortest Path Forever, TomTom, the map pin, or
  none.
- **Guide picker**: lists every guide; the ones not for your character are greyed out.
- **Profession steps**: guides can ask for a skill level ("Reach Mining 65") or a rank to train, and show the progress.
- **Flight paths**: "get the flight path" steps also tick off in zones with a map of their own.
- **Retail**: the step divider no longer shows as a bright bar.
- Guide writers: `ObviGuide.Load`, `ObviGuide.List` and `ObviGuide.Read` for tools like Obvi Guide: Scribe.

## v0.1.0

- First release.
