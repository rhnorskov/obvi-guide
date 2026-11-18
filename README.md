# Obvi Guide

A guide viewer for WoW Forever, plus the addons around it. Each folder is its own addon, released as its own CurseForge project (except the Zygor bridge, which is never released):

| Folder | Addon | What it is |
|---|---|---|
| `ObviGuide` | Obvi Guide | The viewer. Reads guides in its own format and RestedXP's; other formats can be added by addons. Ships no guides. |
| `ObviGuide_Scribe` | Obvi Guide: Scribe | Write guides in game: record while playing, edit, test, export. |
| `ObviGuide_Dungeons` | Obvi Guide: Dungeons | Dungeon quest guides and dungeon keys. |
| `ObviGuide_Professions` | Obvi Guide: Professions | Profession leveling guides. |
| `ObviGuide_Extras` | Obvi Guide: Extras | Guides for other unlocks, such as the Aqual Quintessence and the Cozy Sleeping Bag. |
| `ObviGuide_Zygor` | Obvi Guide: Zygor | Personal: reads the guides of your own installed Zygor addon in game (it brings its own Zygor reader), then stops Zygor so it can't clash (`/og zygor` keeps it running). Not released. |

Writing guides: see [ObviGuide/docs/FORMAT.md](ObviGuide/docs/FORMAT.md).

## QuestieDB

Obvi Guide reads quest pre-quests and quest XP from [QuestieDB](https://github.com/Questie/QuestieDB), Questie's
quest database, an addon of its own. Quest Catchup, skipping quests you can't take yet and the XP shown
need it; the rest works without it. How you get it:

- **CurseForge app:** installed with Obvi Guide (it's a required dependency of the CurseForge project).
- **The install script below:** installs and updates it too.
- **By hand:** the `QuestieDB-<version>-Forever.zip` from its [releases](https://github.com/Questie/QuestieDB/releases),
  or [QuestieDB on CurseForge](https://www.curseforge.com/wow/addons/questiedb). Questie users already have it.

Obvi Guide still loads without it. It isn't bundled: it's a 15 MB addon that reads its data from its own folder, and
not all of its data is under a licence that allows passing it on.

## Trying the newest version

To play with the latest changes before they're released, paste this into PowerShell. It downloads this repo from
GitHub and puts Obvi Guide, Dungeons, Professions, Extras and the Zygor bridge in your game's AddOns folder (no git
needed), plus QuestieDB; run it again to update:

```
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/rhnorskov/obvi-guide/main/tools/install.ps1)))
```

It finds the game by itself; add `-Path "<game folder>\_forever_\Interface\AddOns"` if it doesn't. See
[tools/install.ps1](tools/install.ps1) for the other options.

## Development

Link each addon folder into the game's `Interface\AddOns` (a junction per folder; the game needs each addon directly
in `AddOns`), e.g. from an elevated or developer-mode prompt:

```
mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ObviGuide" "%CD%\ObviGuide"
```

Type check all addons: `powershell -File tools\check.ps1`.

Releases: push a `v*` tag. Every addon whose TOC has an `X-Curse-Project-ID` is packaged and uploaded
(`.github/workflows/release.yml`, `.github/pkgmeta/`).

## Licence

GPL-3.0, see [LICENSE](LICENSE).
