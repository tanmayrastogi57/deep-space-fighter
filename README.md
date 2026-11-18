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

## Your first flight

Choose **Start Guided Career**, pick any threat preset, and read the briefing. Nothing moves until you press **Launch Sortie**. Increase throttle to 20%, bank toward the **gold diamond** and fly through the Asteria training gate. Slow below 28 m/s, deploy gear and dock at the named **cyan station**. Qualification earns 800 credits and a survey licence. Chart Caligo Overlook for 1,100 more; you can keep flying after the chapter ends. Experienced pilots can skip qualification at preflight without the training payout.

The HUD names the current task. Gold edge arrows show off-screen destinations and their distance; the radar distinguishes higher and lower contacts. **Esc** reopens the briefing, destination, control hints and last radio message. Dock to see available jobs. You can keep or abandon a partial assignment without losing earned credits.

**Free Flight · No Save** is a separate practice sortie in any threat preset. It does not read career upgrades, assign work, or change the career or its backup. **Continue** resumes a saved career assignment.

## Game modes

- **Explorer:** vistas, discoveries, aerobatic gates, meteors, and comet interception without hostile ships.
- **Patrol:** four hostile fighters patrol the system alongside exploration and station work.
- **Warzone:** eight hostiles, including three heavy fighters, and suppression jobs when enough targets are available.

All three threat presets are available for career and practice. The career hangar shows chapter milestones and equipment upgrades.

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
