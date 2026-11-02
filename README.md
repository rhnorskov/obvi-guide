# Obvi Guide

A guide viewer for World of Warcraft (retail and WoW Forever), plus the addons around it. Each folder is its own
addon, released as its own CurseForge project:

| Folder | Addon | What it is |
|---|---|---|
| `ObviGuide` | Obvi Guide | The viewer. Reads guides in its own format, RestedXP's and Zygor's. Ships no guides. |
| `ObviScribe` | Obvi Guide: Scribe | Write guides in game: record while playing, edit, test, export. |
| `ObviGuides_Dungeons` | Obvi Guide: Dungeons | Dungeon quest guides. |
| `ObviGuides_Professions` | Obvi Guide: Professions | Profession leveling guides. |

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
