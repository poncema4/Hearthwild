# tests/ map (read this instead of listing the folder)

Run everything: `tests/run_tests.sh` (add `--headless-only` to skip rendered steps).
CI mode: `GODOT_FLAGS="--rendering-driver opengl3 --rendering-method gl_compatibility --audio-driver Dummy" tests/run_tests.sh`.
Rules and the false-positive checklist: `AGENTS.md` section 8. What is intentional (not a bug): `docs/INTENTIONAL.md`.

| Folder / file | What it is | Needs rendering? |
|---|---|---|
| `run_tests.sh` | The one entry point. Runs every step below, writes `qa_output/INDEX.md`. | no |
| `functional/` | Headless tests that assert numbers. Fast (`--fixed-fps 60`). | no |
| `functional/test_player_movement.gd` | Controls, wall/boundary/tree collision, respawn, camera arm vs trunk. | no |
| `functional/test_terrain.gd` | Collision matches the mesh (ray grid), slope-aware drops, placement, sand only at the pond. | no |
| `functional/test_movement_feel.gd` | Movement feel in numbers (accel, stop, turn, strafe, jump) against bands. | no |
| `functional/test_village.gd` | Village: flat ground, doors walkable, walls/roofs/props solid, nature keeps out, main path walkable, door bigger than the player. | no |
| `functional/test_interaction.gd` | E key, prompt, doors (open, close, blocked), notice board. | no |
| `functional/test_character.gd` | The dog: parts, size, grounding, species variety, outfits, fade. | no |
| `functional/test_soak.gd` | A bot drives the real player along a route (path, plaza, into two cottages through their doors with E) with Shift held, then again with Space held: fails on any stall, blocked path, dead door or fall. | no |
| `functional/test_profile.gd` | Player profile: save/load round trip, damaged and hostile saves, name rules, wardrobe catalog consistency. | no |
| `functional/test_creator.gd` | Character screen: opens on first launch, locks the player, animal and outfit pickers, Start saves and dresses the player, reopen with F2. | no |
| `functional/test_fishing.gd` | Fishing: spots on real terrain, reachable, cast/bite/reel timings, every way it ends, visuals, day/night fish, saved journal. | no |
| `functional/test_smoothness.gd` | Smooth movement: physics at 30 ticks against 60 drawn frames, a 2 s sprint; the camera's and the character model's DRAWN motion must be even from frame to frame (unevenness under 0.3; 2.0 without interpolation); interpolation switched on and the camera rig set up for it. 3 negative controls. | no |
| `functional/test_camera_input.gd` | The Roblox-style mouse and the F3 overlay with real events: right button = look, left click never takes the mouse, Alt = shift lock (reticle, message, character faces the camera while standing/strafing/backing up, camera over the shoulder 0.5 -> 0.95 m), Esc turns it off, locked player ignores Alt, Shift is still run, F3 lists exactly the held keys, the character screen keeps shift lock. 9 negative controls. | no |
| `functional/test_keys.gd` | The REAL keyboard: Input Map has W/A/S/D, Space, Shift, E, F2 each on its own action; real key events walk every direction (distances measured), diagonals, W+S cancel, Shift sprints farther, Space jumps and lands, release stops, no stuck actions. 6 negative controls. | no |
| `functional/test_wardrobe.gd` | The wardrobe and the animals: 25 items in the right slot counts, the original first per slot, all 9 animals x 25 items equip cleanly into their own socket and touch the body (real mesh bounding boxes), stay off the ground, fade with the body, the dress/wings/wizard hat have the right shape, every item survives a saved profile and is rejected on a wrong slot. | no |
| `functional/test_zombie.gd` | The zombie and its spawner in the real world: model and grounding, chase speed and facing, range, melee (8 damage every 1.2 s), a sleeping player left alone (with a positive control), sunlight burn, glow, shade under a real roof, characters and walls casting no shade, dawn/dusk edges, spawner rules (night only, burst, cap, 25-40 m, outside village/water/walls), player knock-out and respawn. 35 negative controls. | no |
| `functional/test_health.gd` | Health: damage / heal / revive maths, clamping, bad numbers (NaN, infinity, negative), `died` exactly once, a repaired maximum; the player's HP bar text, fill and on-screen position. 7 negative controls. | no |
| `functional/test_sleep.gd` | Sleep: a bed in every cottage, 7 PM-6 AM window (both edges), full night sequence, clock forward to 6:30, lock/unlock, pose, wake-up spot. | no |
| `functional/test_lake.gd` | Lake decoration and coverage: reeds on the bank, lily pads on the water, clear of fishing spots and casting lines, deterministic, spots spread all round. | no |
| `functional/test_screen.gd` | The shared screen: the YouTube link parser (17 accepted forms, 28 hostile or malformed links), the place (flat, facing the plaza, solid, 6 benches) and the paste-a-link box (open, bad link, good link, clear, Esc, player locked). | no |
| `functional/test_sitting.gd` | Sitting on benches: every bench has a seat, E sits (pose geometry, no collision), every stand-up key, held keys ignored, E never re-sits, occupied seat, freed bench / respawn / bed release the sitter. | no |
| `functional/test_daynight.gd` | Day/night: clock, noon vs midnight light, sun path, dusk colour, smoothness, signals, lamps, clock hands, HUD clock. | no |
| `functional/test_animation.gd` | Animation geometry: feet and hands, skating, snaps, physics tick. | no |
| `playtests/` | Rendered tests that save screenshots into `qa_output/`. | yes (Xvfb is fine) |
| `playtests/playtest_camera.gd` | Mouse look, pitch clamp, zoom, wall squeeze + player fade (pixel-checked). | yes |
| `playtests/playtest_visual_tour.gd` | 15 scenic screenshots (environment, nature, player), each auto-checked. Also checks the render budget (triangles, objects, draw calls of the busiest frame, per renderer). | yes |
| `playtests/playtest_village.gd` | 7 village screenshots (path, plaza, cottage front and interior, back wall, well, notice board), each auto-checked. | yes |
| `playtests/playtest_character.gd` | 7 screenshots of the dog (all sides, face close-up, walking, jumping, outfit). | yes |
| `playtests/playtest_creator.gd` | The character screen with the dog, cat and bunny, and the result in the world; panel fits the window; mouse captured after Start. | yes |
| `playtests/playtest_fishing.gd` | Fishing: ready, cast, bite, caught, night; bobber and ! on screen. | yes |
| `playtests/playtest_wardrobe.gd` | All 9 animals in a row, the 7 hats, faces and necks, tops and the dress, the backs (wings, cape, pack) and five complete looks (topic `wardrobe`, 6 shots), each checked on screen, not blank and not mid-blink. | yes |
| `playtests/playtest_zombie.gd` | Zombies as the player sees them (topic `zombies`): night approach, close-up of the model, burning at noon, village at night; checks each zombie is on screen, not hidden (the player counts as an occluder) and that the burn glow is in the pixels. | yes |
| `playtests/playtest_health.gd` | Health: the HP bar at full, 50% (text straddles red and dark), 35%, 1 hp and dead (5 shots, topic `health`), with the bar's fill read back from the real pixels. | yes |
| `playtests/playtest_sleep.gd` | Sleep: bed prompt, lying down, waking, morning. | yes |
| `playtests/playtest_lake.gd` | The lake: wide view by day, dusk and night, reeds, lily pads, aerial view. | yes |
| `playtests/playtest_daynight.gd` | 6 times of day in the village plus a whole-day filmstrip. | yes |
| `playtests/playtest_animation.gd` | Filmstrips: walk, sprint, hop (side and front), idle. | yes |
| `playtests/playtest_movement.gd` | Movement filmstrips (contact sheets) for visual review. | yes |
| `tools/make_brief.py` | Prints a short standard brief for one review agent (sage, hawkeye, scout, ghoul, animator, mason, warden): its hard budget, what changed vs master, the lead's evidence file, the findings to re-check (delta), the screenshots, and the traps earlier rounds fell into. | no |
| `tools/mutate.py` | Negative controls in one call: reads a JSON list of deliberate breaks, applies each, runs the test, expects CAUGHT (non-zero exit or a FAIL line), restores the file byte-for-byte. MISSED means a check that cannot fail; BAD means the target text was not found exactly once. | no |
| `tools/check_repo.py` | Free hygiene checks (runner step 1): every test in the runner and this map, step counts, agents documented, .uid files, no loose or debug files, lessons numbered and cited ones exist. | no |
| `tools/review_pack.py` | Prints the REVIEW PACK for agent briefs: diff summary, only the CHANGED screenshots, which agents are needed. | no |
| `support/playtest_kit.gd` | `PlaytestKit`: shared helpers (load world, input, shots, manifests, filmstrips). | no |
| `tools/make_qa_index.py` | Rebuilds `qa_output/INDEX.md` (what to review) from the manifests. | no |

New tests go in `functional/` (numbers) or `playtests/` (pixels), named `test_<thing>.gd` /
`playtest_<thing>.gd`, and get one row here. Never leave a loose file directly in `tests/`.
