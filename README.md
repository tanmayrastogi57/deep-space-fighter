# Deep Space Fighter

A realistic 3D free-roaming space fighter game built with Godot 4. Fly one upgradeable fighter through a streamed star system, explore orbital vistas, perform aerobatics, intercept comets, destroy meteors, fight hostile patrols, and land on a station or carrier.

The previous Python/Tkinter ASCII game has been replaced. Gameplay now uses real 3D geometry, PBR-style materials, lighting, particles, spatial scenes, and multiple flight cameras.

## Quick start on Windows

Install the portable Godot 4.7.1 toolchain from the official release host:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup_godot.ps1
```

This is a large one-time download because Godot distributes export templates for all platforms in one archive. The script keeps only the Windows templates.

Run the game:

```powershell
powershell -ExecutionPolicy Bypass -File .\run.ps1
```

Alternatively, import `project.godot` into Godot 4.7.1 or newer and press `F5`.

## Game modes

- **Explorer:** vistas, discoveries, aerobatic gates, meteors, and comet interception without hostile ships.
- **Patrol:** Explorer activities plus drones, light fighters, rescue work, and moderate combat.
- **Warzone:** heavier fighters, larger hostile groups, dangerous contracts, and escalating pursuit.

Each mode uses the same deterministic open world and persistent career. The hangar offers five levels across engine, thrusters, hull, shields, energy, cannon, missiles, and sensors.

## Flight controls

| Action | Default |
| --- | --- |
| Increase / decrease throttle | `Left Shift` / `Left Ctrl` |
| Pitch down / up | `W` / `S` or `Numpad 8` / `Numpad 5` |
| Roll left / right | `A` / `D` or `Numpad 4` / `Numpad 6` |
| Yaw left / right | `Q` / `E` |
| Look around | Mouse |
| Extended free-look | Hold `Alt` |
| Rear view | Hold `C` |
| Cycle cockpit / close / far cameras | `V` |
| Toggle flight assist | `X` |
| Landing gear | `G` |
| Dock / interact | `F` |
| Fire current weapon | `Left Mouse Button` or `Space` |
| Missile target lock | Hold `Right Mouse Button` |
| Switch cannon / homing missiles | Mouse wheel |
| Pause and live settings | `Escape` |
| Diagnostics | `F3` |
| Fullscreen | `F11` |

Keyboard controls can be rebound from Settings. Duplicate bindings are rejected, and `Escape` always remains a pause fallback.

## World and systems

- Authored delta-wing fighter with cockpit, engine pods, hardpoints, emissive thrusters, and functional landing gear
- Cockpit, close chase, far chase, rear-view, mouse orbit, and speed-sensitive field of view
- Assisted aircraft-like space physics with optional inertial drift
- Handcrafted station, carrier, planets, moons, rings, nebula region, belt, wreck sites, and scenic discoveries
- Deterministic sector streaming and floating-origin correction for extended free roam
- Procedural irregular asteroid meshes, moving comets, destructible hazards, debris feedback, and collision damage
- Cannon and homing missiles with target acquisition, lock progress, ammunition, energy, shields, and hull damage
- Patrol, pursuit, attack, evade, and retreat AI states
- Six contract families, credits, repairs, rearming, discoveries, and eight upgrade paths
- Atomic career saves with backup recovery and quarantining of damaged data
- Synthesized engine, cannon, missile, impact, and docking audio without downloaded runtime assets

## Tests

Run the deterministic suite:

```powershell
.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests_godot/test_runner.tscn
```

Run the integrated 3D scene smoke test:

```powershell
.\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests_godot/smoke_test.tscn
```

`build.ps1` runs script validation and both test layers before exporting.

## Build the Windows game

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Output:

```text
dist\Deep Space Fighter\Deep Space Fighter.exe
```

The `.pck` is embedded into the executable. The finished folder can be copied to another Windows machine without Python or Godot installed.

## Save locations

Exported builds use Godot's normal Windows application-data directory:

```text
%APPDATA%\Godot\app_userdata\Deep Space Fighter
```

The portable editor is self-contained under `.tools\godot-4.7.1\editor_data`. Settings and career files are JSON and written atomically.

## Troubleshooting

- **Godot not found:** run `setup_godot.ps1`, or install Godot 4.7.1+ and ensure `godot4` or `godot` is on `PATH`.
- **Windows export template missing:** rerun `setup_godot.ps1`; it extracts the official Windows templates.
- **Low frame rate:** lower the graphics preset, reduce camera effects, and cap the frame rate at 60.
- **Uncomfortable camera motion:** lower Camera Shake or enable reduced effects in Settings.
- **Unexpected controls:** open Settings to inspect or rebind the action. `Escape` remains available after rebinding.
- **Damaged career file:** the game quarantines it and recovers the last valid `.bak` save when available.

The project requires no network access or downloaded art assets at runtime.
