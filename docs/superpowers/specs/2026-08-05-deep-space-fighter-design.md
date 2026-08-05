# Deep Space Fighter — Approved Game Design

Date: 2026-08-05  
Status: Approved  
Target: Windows desktop, Godot 4, GDScript

This design supersedes the ASCII Rocket presentation and runtime design. Git history remains intact, but the Tkinter/ASCII application is replaced as the playable product by a true 3D Godot game. There are no ASCII or text-shaped gameplay objects and no visual-theme picker. The single art direction is realistic **Deep Space**.

## Product vision

Deep Space Fighter is a single-player, free-roaming space-flight game built around GTA-style aircraft controls, assisted space physics, aerobatics, exploration, environmental hazards, and escalating combat. The player pilots one deeply upgradeable fighter through a dense, beautiful star system containing planets, moons, rings, asteroid fields, comets, stations, carriers, wrecks, and scenic discoveries.

The game offers three ways to use the same persistent world:

1. **Explorer** emphasizes free flight, vistas, navigation, aerobatic challenges, discoveries, meteor storms, and comet interception without hostile spacecraft.
2. **Patrol** adds drones, light fighters, escort and rescue work, and moderate combat.
3. **Warzone** adds hostile groups, capital-ship encounters, more dangerous contracts, and escalating pursuit.

The initial release is a polished vertical slice: complete and replayable, but deliberately limited to one star system and one player fighter so flight quality, world atmosphere, and the career loop receive sufficient polish.

## Technical architecture

The project uses Godot 4 and GDScript so it can be edited in the standard Godot editor, tested headlessly, and exported as a self-contained Windows desktop application without a .NET runtime.

The principal scenes and systems are:

- `Main`: application startup, save loading, frontend navigation, and scene transitions.
- `StarSystem`: the streamed open world, sector activation, deterministic generation, floating-origin correction, and global environmental state.
- `PlayerFighter`: model, assisted flight physics, health, shields, energy, weapons, upgrades, landing gear, and visible damage.
- `CameraRig`: cockpit, close chase, far chase, rear view, free-look, camera obstruction handling, shake, and smooth transitions.
- `WorldObjects`: planets, moons, rings, nebulae, asteroids, comets, stations, carriers, wrecks, beacons, and discoveries.
- `AI`: reusable steering and state logic for patrol, pursuit, attack, evasion, retreat, and docking.
- `GameModes`: mode-specific encounter, hostility, objective, and reward policies over the shared world.
- `Career`: atomic persistence for credits, upgrades, contracts, discoveries, fighter condition, and last docking location.

Large-distance stability uses a floating origin: when the player crosses a safe threshold, active local objects are shifted together while logical sector coordinates remain stable. Sector streaming maintains a bounded set of nearby simulation objects. Distant bodies use low-detail meshes or impostors; close objects transition to detailed geometry. Deterministic seeds ensure that procedural regions remain consistent after loading a save.

Game logic is separated from presentation wherever practical. Flight, damage, weapons, rewards, world generation, and persistence expose testable GDScript classes, while scenes handle rendering, particles, audio, and animation.

## World design

The initial star system combines authored landmarks with deterministic procedural distribution. It contains five distinct regions:

1. A station and settled orbital zone suitable for training, docking, and early contracts.
2. A dense asteroid belt containing mining wreckage, hazards, and combat cover.
3. A ringed gas giant with moons and dramatic orbital vistas.
4. A colored nebula region with dust, debris, and reduced sensor visibility.
5. A dangerous outer region containing comet routes, meteor storms, derelicts, and Warzone encounters.

Major content includes a luminous primary star, a ringed gas giant, a rocky planet with visible night-side lights, orbital moons, an asteroid belt, procedural comet paths, meteor storms, one major station, one carrier, patrol beacons, wrecks, and hidden scenic locations.

Planets and moons are detailed orbital destinations. Atmospheric entry and surface landing are out of scope. Travel distances are compressed for playable pacing while scale cues, parallax, lighting, object detail, and travel time maintain the feeling of a large system.

The generated world observes explicit density and performance budgets. Important landmarks are handcrafted and stable. Procedural fields add variation around them without obscuring navigation routes, docking approaches, or mission spaces.

## Flight model and controls

Flight uses assisted six-axis space physics. It feels familiar to a GTA-style aircraft while retaining believable mass, momentum, boost, drift, and directional thrusters. Flight assist applies configurable stabilization and velocity damping; it can be disabled temporarily or persistently for advanced drifting and aerobatics. Spacecraft do not stall, but aggressive maneuvers consume energy and visibly stress thrusters.

Default controls are:

- `Left Shift`: increase throttle
- `Left Ctrl`: decrease throttle
- `W` / `S`: pitch
- `A` / `D`: roll
- `Q` / `E`: yaw
- Mouse movement: look around independently
- `Alt`: hold for unrestricted free-look without changing flight input
- `C`: instant rear view while held
- `V`: cycle cockpit, close chase, and far chase views
- `G`: deploy or retract landing gear
- `F`: interact, dock, or use station services
- `Left Mouse Button` or `Space`: fire the active weapon
- Mouse wheel: switch weapons
- `Right Mouse Button`: acquire or maintain missile target lock
- `Escape`: pause or open settings
- `F11`: toggle fullscreen

All gameplay controls are rebindable. Mouse sensitivity, inversion, field of view, camera spring strength, aim assistance, and flight-assist behavior are configurable.

The landing gear is functional. Gear state affects safe touchdown conditions and is required for landing on carriers and station pads. Successful docking provides repair, rearming, refuelling or energy service, contract access, and upgrades.

## Hazards, weapons, and combat

The initial fighter carries two weapon classes:

- A rapid cannon for direct fire, debris clearing, meteor fragmentation, and close combat.
- Homing missiles requiring a maintained target lock, with limited ammunition and stronger impact damage.

Targeting provides range, lead information, lock progress, and high-contrast cues without overwhelming the view. Shield hits, hull damage, weapon heat, ammunition, and energy are readable in both cockpit and chase views.

Meteors can be dodged or fragmented. Resulting debris inherits momentum and remains dangerous until it disperses. Comets are large interception targets with ice and rock weak points, a visible debris trail, high relative velocity, and valuable contracts. Collision damage accounts for relative velocity, impact angle, shield condition, and object mass.

Patrol mode adds drones and light fighters. Warzone adds larger hostile groups, tougher fighters, capital-ship encounters, and escalation. AI uses bounded state machines for patrol, investigate, pursue, attack, evade, retreat, and dock. Encounter directors enforce distance, count, and performance limits so enemies do not spawn unfairly around the player.

## Career and contracts

A career persists between sessions. The save includes credits, selected mode, accepted contracts, discoveries, upgrade levels, ammunition, fighter condition, control/settings preferences, procedural seed, and last valid docking location.

The initial career uses one fighter with meaningful upgrades in these categories:

- Main engine and boost
- Maneuvering thrusters
- Hull and collision tolerance
- Shields and recharge
- Energy capacity and regeneration
- Cannon damage, cooling, and accuracy
- Missile capacity, lock speed, and tracking
- Sensors and target range
- Utility or cargo capacity for contract objectives

Six reusable contract families provide the initial activity set: navigation or delivery, aerobatic trials, exploration or scanning, comet interception, escort or rescue, and hostile elimination. Difficulty, distance, hazard density, opposition, and rewards scale within defined bounds. Explorer mode never injects hostile objectives.

## Visual direction and models

The only visual identity is **Deep Space**. It favors realistic spacecraft proportions, physically based hard-surface materials, natural celestial lighting, restrained cinematic grading, and highly readable silhouettes. It explicitly avoids cartoon forms, pixel art, neon grids, and ASCII elements.

The fighter is a proper 3D model with a cockpit canopy, panel seams, thruster assemblies, retractable landing gear, weapon hardpoints, navigation lights, engine heat, shield impacts, and progressive damage. It provides several levels of detail. Asteroids and meteors use varied mesh silhouettes, close-range surface detail, craters, physically plausible rotation, and rock/metal material variation. Comets use ice/rock geometry, dust and ion tails, fragment effects, and emissive or scattering treatment near the star.

Planets use layered surface, cloud, atmosphere, night-light, and ring materials as appropriate. Nebulae use layered volumetric-looking cards or bounded effects rather than a flat background alone. Engines, maneuvering thrusters, cannon impacts, missile trails, explosions, dust, fragments, and shield effects use particles and shaders with configurable quality.

Models, procedural materials, shaders, effects, interface assets, and audio are authored within the repository. The initial release does not depend on downloaded art packs.

Graphics presets scale shadow quality, anti-aliasing, particles, object density, render distance, material detail, post-processing, and high-cost environmental effects. Unsupported features fall back safely rather than preventing launch.

## Cameras and interface

The camera rig offers:

- A cockpit view with functional instruments and restrained vibration
- A close chase view for maneuvering and combat
- A far chase view for spatial awareness and scenic flight
- An instant rear view while `C` is held
- Independent mouse free-look

Chase views use spring smoothing, speed-dependent field of view, collision avoidance, adjustable shake, and short cinematic transitions. Switching views never changes the fighter's physical state or control input.

The frontend contains Continue Career, New Career, Free Flight, Settings, Credits, and Quit. Starting or continuing a flight shows Explorer, Patrol, and Warzone cards with clear danger and reward descriptions.

The in-flight HUD displays velocity, throttle, flight-assist state, shields, hull, energy, fuel, active weapon, ammunition, lock state, target distance, objective, and navigation markers. Radar and lead indicators can be toggled. Context prompts appear for interaction, landing, docking, repair, and rearming.

Settings cover display mode, resolution, graphics preset and advanced graphics, frame cap, audio groups, mouse sensitivity, inversion, field of view, camera behavior, flight assistance, and full input rebinding. Accessibility settings include HUD scale, reduced shake, reduced flashes, high-contrast targeting, subtitles, and aim assistance.

## Audio

Audio includes layered engines reacting to throttle and boost, maneuvering thrusters, cockpit ambience, shield impacts, hull collisions, cannon fire, missile launch and lock warnings, explosions, comet rumble, station ambience, and contextual music transitions.

Because the setting is space, exterior effects are presented as stylized cockpit, hull-conduction, or sensor feedback rather than claiming literal sound propagation through vacuum. Godot audio buses provide master, music, engine, weapons, effects, ambience, and interface volume controls. Nearby sources use spatial 3D audio where appropriate.

## Persistence and failure handling

Career saves are versioned. Saving writes to a temporary file and atomically replaces the primary save only after serialization succeeds. The previous valid save is retained as a backup. A malformed save is quarantined and the backup is offered or loaded automatically; save corruption must not prevent the application from starting.

The application logs startup, renderer capability, scene transition, save recovery, and unexpected runtime errors. Missing optional effects, unsupported graphics features, invalid bindings, and out-of-range settings fall back to safe defaults with a visible explanation where user action is useful.

The world generator guarantees safe spawn and docking volumes. Origin shifts are deferred during docking and other precision-critical operations. Streaming cleanup is bounded and avoids deleting mission, target, or docking objects that remain logically active.

## Initial-release boundaries

Included:

- One streamed star system with five regions
- One upgradeable fighter
- Four camera views
- Explorer, Patrol, and Warzone modes
- Cannon and homing missiles
- Drones, patrol fighters, and heavier Warzone fighters
- Meteors, destructible asteroids, comets, debris, and storms
- One station and one carrier with functional landing
- Six reusable contract families
- Aerobatic challenges and scenic discoveries
- Persistent career, services, and upgrades
- Complete menus, settings, accessibility, pause, and diagnostics
- Windows desktop export

Deferred:

- Atmospheric entry and planetary surface maps
- Multiple purchasable ships or modular ship construction
- Multiplayer or networking
- Large narrative campaign and voice acting
- Fully simulated economy or faction diplomacy
- Seamless multiple star systems
- User-generated content and mod tooling

## Verification and acceptance

Headless GDScript tests cover flight forces and stabilization, control mapping, camera-state transitions, weapon switching, target locks, damage, collision calculations, AI transitions, deterministic generation, sector activation, floating-origin coordinates, docking conditions, upgrade calculations, contract rules, save migration, and corrupt-save recovery.

Scripted smoke tests verify that essential scenes load and can transition without errors. Manual acceptance covers all three modes, every camera, mouse free-look, flight-assist aerobatics, weapon use, comet and meteor interactions, repeated docking, station services, upgrade persistence, graphics presets, rebinding, long free-flight sessions, and Windows export.

The vertical slice is accepted when it provides a stable start-to-flight-to-contract-to-docking career loop, maintains responsive controls and stable physics during origin shifts, recovers from invalid settings or saves, and runs at the selected graphics preset without unbounded entity or memory growth.
