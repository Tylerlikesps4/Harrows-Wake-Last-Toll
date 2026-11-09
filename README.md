# Harrow's Wake: Last Toll

A short PS1-style first-person horror game, made for **Super Free AI Game Jam #2** on itch.io (7-14 Nov 2026). A one-night spin-off of [Harrow's Wake](https://github.com/Tylerlikesps4/Harrows-Wake).

St. Agnes Orphanage, 3:12 AM. The Bellman walks the halls ringing his hand bell. Find the **bell rope**, the **bell clapper** and the **chapel key**, unlock the chapel and ring the great bell before he finds you. You can't fight him. Listen for his bell, keep your distance, and don't run unless you must: running is loud.

Target length: 10-15 minutes.

## Download
Every push to `main` builds a release on the [Releases page](https://github.com/Tylerlikesps4/Harrows-Wake-Last-Toll/releases):
- `LastToll-Web.zip` - the browser (HTML5) build, `index.html` at the zip root. On itch.io, upload it as a file marked "This file will be played in the browser". Built without threads, so it needs no special server headers.
- `LastToll-Windows.zip`, `LastToll-Linux.zip` - desktop builds.
- `LastToll.apk` - Android.

## Controls
| | Keyboard + mouse | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Drag left half |
| Look | Mouse | Right stick | Drag right half |
| Run (loud) | Shift | B / L3 | RUN (toggle) |
| Sneak (quiet) | Ctrl / C | R3 | - |
| Use | E / Space / Enter | A | USE |
| Flashlight | F | LB | LIGHT |
| Pause | Esc / P | Start | II |
| Fullscreen | F11 | | |

## Building
Standard Godot 4.3 (no .NET needed; the whole game is GDScript).
1. Open the folder in Godot 4.3, or import headless: `godot --headless --editor --quit`.
2. Export: presets for Windows, Linux, Android and Web are in `export_presets.cfg` (e.g. `godot --headless --export-release "Web" out/web/index.html`; needs the 4.3 export templates).
3. Tests: `godot --headless -- --smoke` (automated playthrough). Screenshots: `xvfb-run -s "-screen 0 1280x960x24" godot -- --shots --out=/tmp/shots`.

## Layout
- `scripts/main.gd` - level (built from the ASCII map), items, UI, game flow
- `scripts/player.gd` - first-person controller
- `scripts/touch.gd` - phone controls
- `scripts/bellman.gd` - the Bellman's AI (grid pathfinding, hearing, sight, chase, search, his hand bell)
- `scripts/lib.gd`, `shaders/` - PSX material/prop helper and shaders reused from Harrow's Wake
- `tests/` - smoke test and screenshot tour

## Jam rules and what was reused
Everything about this game (design, map, core loop, AI, player controller, UI) was made during the jam window. Pre-made material reused from Harrow's Wake, as the jam allows: the CC0 textures, props and sound effects listed in [CREDITS.md](CREDITS.md), the two PSX shaders and the `lib.gd` prop/material helper. See [DEVLOG.md](DEVLOG.md).

AI use: made with AI assistance (Hark), as the jam allows.

## License
Copyright (C) 2026 Tylerlikesps4.

The game code is free software under the **GNU General Public License v3.0 or later** (full text in [LICENSE](LICENSE)). It comes with no warranty.

Third-party textures, models and sounds in `assets/` keep their own licenses (CC0; see [CREDITS.md](CREDITS.md)). The "Harrow's Wake" name and logo are not covered by the GPL and aren't licensed for reuse.
