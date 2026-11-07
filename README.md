# Obvi Guide

A guide viewer for World of Warcraft (retail and WoW Forever), plus the addons around it. Each folder is its own
addon, released as its own CurseForge project (except the Zygor bridge, which is never released):

| Folder | Addon | What it is |
|---|---|---|
| `ObviGuide` | Obvi Guide | The viewer. Reads guides in its own format and RestedXP's; other formats can be added by addons. Ships no guides. |
| `ObviGuide_Scribe` | Obvi Guide: Scribe | Write guides in game: record while playing, edit, test, export. |
| `ObviGuide_Dungeons` | Obvi Guide: Dungeons | Dungeon quest guides and dungeon keys. |
| `ObviGuide_Professions` | Obvi Guide: Professions | Profession leveling guides. |
| `ObviGuide_Extras` | Obvi Guide: Extras | Guides for other unlocks, such as the Aqual Quintessence and the Cozy Sleeping Bag. |
| `ObviGuide_Zygor` | Obvi Guide: Zygor | Personal: reads the guides of your own installed Zygor addon in game (it brings its own Zygor reader). Not released. |

Writing guides: see [ObviGuide/docs/FORMAT.md](ObviGuide/docs/FORMAT.md).

## Development

Link each addon folder into the game's `Interface\AddOns` (a junction per folder; the game needs each addon directly
in `AddOns`), e.g. from an elevated or developer-mode prompt:

```
mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\ObviGuide" "%CD%\ObviGuide"
```

Type check all addons: `powershell -File tools\check.ps1`.

Releases: push a `v*` tag. Every addon whose TOC has an `X-Curse-Project-ID` is packaged and uploaded
(`.github/workflows/release.yml`, `.github/pkgmeta/`).

## Licence

GPL-3.0, see [LICENSE](LICENSE).
