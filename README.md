# ASCII Rocket

ASCII Rocket is a polished endless-survival desktop game rendered entirely as
ASCII/Unicode text on a Tkinter Canvas. It includes three selectable themes,
procedural sound, persistent high score, advanced settings, deterministic test
seeds, and no runtime dependencies outside Python's standard library.

## Run from source

Requirements: Windows 11, Python 3.11 or newer, Tk 8.6.

```powershell
python -m ascii_rocket
```

First launch asks you to choose Terminal Noir, Deep-Space HUD, or Neon Arcade.
The game then waits for Space or Enter before launching.

## Controls

| Action | Default |
|---|---|
| Move | W/A/S/D or arrow keys |
| Launch | Space or Enter |
| Pause menu | Escape or P |
| Restart after game over | R |
| Toggle fullscreen | F11 |
| FPS diagnostic | F3 |

Movement and menu bindings can be changed in Settings. Escape always remains a
pause fallback.

## Settings and saved data

Settings and high score are written atomically under:

```text
%APPDATA%\AsciiRocket
```

Logs are written under:

```text
%LOCALAPPDATA%\AsciiRocket\ascii_rocket.log
```

Corrupt settings never prevent startup. The game restores validated defaults
and shows a warning.

## Tests

```powershell
python -m unittest discover -s tests -v
```

Tests cover configuration, themes, input, score timing, collision, seeded
spawning, difficulty progression, controller lifecycle, and Tk rendering.

## Build portable Windows app

```powershell
.\build.ps1
```

The script runs tests, installs PyInstaller as a build-only dependency when
needed, then creates:

```text
dist\ASCII Rocket\ASCII Rocket.exe
```

The one-folder distribution is portable and does not require Python on the
target machine.

## Troubleshooting

- If a preferred font is missing, the game falls back through Consolas,
  Courier New, DejaVu Sans Mono, and TkFixedFont.
- If Windows audio is unavailable, gameplay continues silently.
- Press Escape to reach Exit Fullscreen or Quit from the pause menu.
- Delete `%APPDATA%\AsciiRocket\settings.json` to trigger first-run theme
  selection again.

No controller, network, raster image, leaderboard, power-up, or boss feature is
included in version 1.
