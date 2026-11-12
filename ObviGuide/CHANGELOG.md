# Obvi Guide

## Unreleased

- Going back to a step the guide skipped (you had it already) shows its lines ticked off.
- Clicking a line that uses or equips an item or casts a spell does just that, and says so when you hover it; it no
  longer sets the waypoint too.
- Guide lines can be ticked off by a condition: `s:Do("Buy Recipe: ..."):Done("knows 7751")` stays in the list, ticked, once
  it holds.
- Guide conditions can test a profession's cap: `skillmax Cooking >= 225` (Expert learned).
- Guides can have exploration lines (`s:Explore(challenge, area)`), done once the game counts the area as found in that
  exploration challenge.
- Guides can list the parts of a bigger challenge still to finish (`s:Challenge(challenge, guide)`): each line goes once
  its part is finished, and clicking it opens that part's guide in a tab of its own.
- **Guide buttons in the legacy challenges window** (WoW Forever): a challenge a guide leads through gets a Guide
  button that opens it in a tab of its own. Guides say which challenge with `g.challenge = id`.
- Guides whose steps can be done in any order (`g.nearest = true`) go to the first stop on the shortest way from where
  you are through the steps left, planned again each time a step is done and when the guide is opened.
- A quest you can't take yet, because its chain began in a guide you skipped, is no longer asked for: its accept line
  is greyed out with what it needs under it ("Needs Blessed Arm"), and you go on with the arrow (The Legend of Stalvan
  in Duskwood, after doing dungeons instead). Needs QuestieDB, which knows each quest's pre-quests;
  for WoW Forever's new chains it doesn't know yet, a quest given where one of the same name is turned in follows that
  one, and the Menethil Statuette chain (A Friend of the Family, The Shamed Lieutenant) is known. Click the line
  (**Catch up**) for a catch-up guide to it. When the quest before it is still in your log, it says "Finish ... first"
  (The Night Watch). A turn-in for a quest you don't have shows the same way: "Not in your quest log". **Quests missing
  a prerequisite** in the settings can skip such steps when there's nothing else to do in them: always, or only when
  catching up isn't worth it; a quest still in your log keeps its step either way. Quests of the same name are told
  apart by their part: "The Night Watch (part 2)".
- **Skip hearthstone steps** (in the settings): leaves out the "Hearth to ..." and "Set your Hearthstone to ..." lines,
  and skips a step with nothing else to do. For when you would rather fly or walk, or keep your Hearthstone where it
  is.
- **Quest Catchup** works for any quest, from all the guides: click a greyed "needs ..." line, or type
  `/og catchup` with a quest's id, name or link. It takes the steps from the guides leading to yours first, then from
  any other guide that has them. Before, it found nothing to catch up on: it took every earlier quest for a
  breadcrumb. Next to Catch up it says whether it's worth it: its XP per minute (the quests it does, the quest and the
  rest of its chain; the way there and back counted) against the guide's own: **worth it**, **about even** or **not
  worth it**. Tick **Detailed catch-up numbers** in the settings for the numbers themselves ("5.4 bars, ~40 min, 0.8x
  this guide's XP per minute"). Behind the guide's pace (a quarter of a level or more short of where its level range
  says you should be by now), catching up is worth it: you'll need the XP anyway. Needs QuestieDB, which knows the XP.
- **Guide picker**: the gear beside the search is a menu now. The guides only for the other faction are left out;
  tick **Other faction's guides** there to list them too. **Settings** opens the settings as before.
- **Destroy cheapest item**, for full bags: finds the item in your bags worth the least at a vendor and asks before
  destroying it (Enter says yes). Grey items go first. Tools (Blacksmith Hammer, Mining Pick, fishing poles...), items
  a vendor won't buy and items the guide still needs are left alone. Bind a key
  in Key Bindings > Obvi Guide, or use the window's gear menu or `/og junk`.
- A finished side task now goes away whole: its notes and "kill these" lines no longer stay behind after it's done.
- Side tasks are set a little apart from each other, so you can tell where one ends and the next begins.
- Notes in side tasks look like the step's own notes (muted gold) rather than plain white lines.
- Clicking a line in the step sets the waypoint: to the line's own spot when it has one, else to the step's. A line
  that also targets or uses something still does that. Clicking again, or once you're there, leaves the waypoint as it
  is, so Shortest Path Forever isn't asked to plan the way anew each time.
- Buy and collect lines show how many you have of how many, also when it's just one: "Buy Soothing Spices (0/1)".

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
