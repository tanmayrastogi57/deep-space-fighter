# First flight: selected audit scope

Approved implementation scope: findings 1–12 from the 18 November flight audit.

1. **P1 · R — The mission omits its instruction.** The courier HUD reads “Outer-system courier run • 0/1 • 1110 CR”; the contract already contains “Reach the marked navigation beacon.” Show one verb, one named target and one completion condition. A player should be able to explain the task from the flight screen alone.

2. **P1 · R/S — Nothing guides you to the beacon.** The radar tracks hostiles and docks, not contract markers. The courier gate is about 1.09 km from spawn, beyond the radar's 650 m range even if it were included. Give the active target an on-screen bracket, off-screen arrow and distance; check it ahead, behind, above and beyond radar range.

3. **P1 · R/S — The station looks like the first checkpoint.** A large, unlabelled ring sits straight ahead, while the actual mission gate is off-axis and its torus lies in a different plane. Give stations a named dock icon and gates a directional face or approach lights; from spawn the two should be identifiable without guessing.

4. **P1 · R/S — Launch gives no reading time.** A ship pointed toward the station starts at 32% throttle; I captured 49 m/s while the introductory toast was still visible. Offer a preflight state and deliberate launch. A hands-off first-time pilot should be safe while reading the briefing.

5. **P1 · D — There is no dependable first lesson.** A new career seeds the initial contract from the clock. Teach one short, skippable qualification: throttle, bank toward a marker, cross it, slow down and dock. Keep all three modes; experienced players can bypass it.

6. **P2 · D — Career has no destination beyond the next payout.** Give it a finite first chapter: qualify at Asteria, earn a survey licence and reach Caligo Overlook. Show completed and upcoming milestones in the hangar. Let free roam continue after the chapter.

7. **P1 · S — Free Flight is not a separate sandbox.** The button launches Explorer via the career path, writes the career mode, and prepares or resumes a contract. Give it an explicit no-save sortie or a separately named shared-career option. Exiting a sandbox flight should leave a byte-for-byte unchanged career.

8. **P1 · S — You cannot decline an unwanted or impossible job.** Completion immediately auto-assigns the next contract; there is no abandon or reroll control. Offer two or three achievable jobs at a dock plus an abandon path without losing earned credits. Verify abandoning works with partially completed jobs.

9. **P2 · R/D — There is no place to re-read the plan.** Pause gives Resume, Settings and Return to Hangar. Add a flight log with the current brief, control hints, destination and last radio message. It should still be useful after the launch toast expires.

10. **P2 · S — Radar loses the vertical dimension.** It uses local X/Z and ignores Y for both blip position and range. An object straight above can appear at the center like a nearby contact. Add altitude chevrons, true 3D range and a scale legend; compare contacts directly ahead and directly overhead.

11. **P1 · R/S — Mode cards promise activities the game doesn't implement.** Patrol advertises rescue work, Warzone capital encounters. The contract generator and hostile spawner provide neither a rescue loop nor hostile capital encounters. Correct the cards now; restore each promise only when a playable example ships.

12. **P2 · R/D — A new pilot can't tell which menu button to choose.** Command gives New Career and Free Flight similar weight, with unavailable Continue above them. Make “Start guided career” primary on first run and “Continue: [current task]” primary on return. Explain that Explorer is peaceful and whether the selected option saves.
