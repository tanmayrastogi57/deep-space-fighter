# Flight art and spatial depth: approved audit scope

The following are the selected requirements from the flight audit. Preserve all three threat presets, the Asteria chapter and existing discovery coordinates. Use local procedural art and check results in the Compatibility renderer.

49. **P1 · R — Cockpit view is obscured by the exterior model.** The captured scene turns almost entirely cyan, with a large curved model surface under the sight. Give cockpit mode its own interior/canopy treatment and hide obstructing exterior surfaces on that camera. Test full mouse sweep and rear glance against dark and bright landmarks.

50. **P1 · R/S — Twin exhausts are visibly asymmetric.** The ship has two engine pods, but the runtime plume list contains only one. One plume changes with throttle while its partner stays at its initial size. Keep explicit references to both, animate along the mesh's actual length axis, and compare silhouettes at idle and full power.

51. **P1 · R/D — The chase view sells tubes, not an airframe.** A dark circular aft face and two solid cyan rods dominate the ship in the launch capture; wing roots and panel shapes disappear into black. Improve the rear silhouette, nozzle depth, engine gradients and restrained rim lighting. Review a grayscale screenshot at ordinary playing size before increasing mesh detail.

52. **P2 · R/D — Planets read as uniformly shaded balls.** Nysa and its moon have nearly featureless surfaces at the distances the player actually sees. Give each a different large-scale pattern: cloud breaks or ocean/land for Nysa, broad craters for its moon. They should be identifiable from the default view without labels.

53. **P2 · R/S — Caligo's ring reads as a thick tube.** It is a torus and looks like a beige doughnut in flight. Use a thin inclined annulus with translucent bands and gaps. From an oblique view the planet should visibly obscure the back half and the ring should still read as a sheet.

54. **P2 · R/D — Helios loses all surface and edge detail.** It appears as a hard, solid white patch beside much dimmer objects. Tune the exposure and add a restrained limb/corona gradient; keep nearby rock silhouettes and the HUD readable when looking toward the star.

55. **P2 · R/S — Asteroid belts lack material identity.** Silhouettes vary, but the rock population uses the same grey material and a similar noise recipe. Use a small, shared set of dark carbon, pale fractured rock and icy bodies, with broad surface detail that survives at speed. Players should recognize separate regions without simply doubling object count.

56. **P2 · S — A comet's tail tumbles with its nucleus.** The tail is a cone parented to a rotating rock, so the long axis rotates with it. Orient the tail independently using the star direction, vary width and opacity, and keep the nucleus readable. Time-lapse one rotation and check the tail doesn't sweep like a propeller.

57. **P1 · S — The best named discoveries have nothing to look at.** The Glass Horizon, Silent Relay and Caligo Overlook are invisible trigger spheres. Give each a low-cost landmark, a distant clue and a reason to slow down: a fractured reflective field, a damaged relay, a framed planet-rise. A pilot should recognize the site before the discovery toast.

58. **P1 · S — Most of the “3D” streamed world is a thin horizontal layer.** Sector keys ignore Y and new rocks stay within ±180 m vertically. Climb far enough and streaming stops adding content around the ship. Stream a sparse 3D neighborhood or design bounded orbital layers with visible routes to each; fly vertically for two minutes to verify.

59. **P2 · S — Stars are local objects you can outfly.** The starfield is a shell about 1.3–2.6 km from the initial origin. On a long trip the backdrop stops behaving like distant stars. Put distant stars in a sky or camera-relative layer and reserve parallax for nearby particles; verify after 10 km of travel.

60. **P2 · D — The launch vista has poor depth cues.** Objects cluster ahead while dark, empty areas have almost no speed reference. Stage three readable distances: close dock lamps passing the wing, a navigable mid-distance belt, and a distant planetary silhouette. The view should feel like forward motion at cruising speed without flooding the screen with debris.
