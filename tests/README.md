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
| `functional/test_sleep.gd` | Sleep: a bed in every cottage, 7 PM-6 AM window (both edges), full night sequence, clock forward to 6:30, lock/unlock, pose, wake-up spot. | no |
| `functional/test_lake.gd` | Lake decoration and coverage: reeds on the bank, lily pads on the water, clear of fishing spots and casting lines, deterministic, spots spread all round. | no |
| `functional/test_screen.gd` | The shared screen: the YouTube link parser (17 accepted forms, 28 hostile or malformed links), the place (flat, facing the plaza, solid, 6 benches) and the paste-a-link box (open, bad link, good link, clear, Esc, player locked). | no |
| `functional/test_daynight.gd` | Day/night: clock, noon vs midnight light, sun path, dusk colour, smoothness, signals, lamps, clock hands, HUD clock. | no |
| `functional/test_animation.gd` | Animation geometry: feet and hands, skating, snaps, physics tick. | no |
| `playtests/` | Rendered tests that save screenshots into `qa_output/`. | yes (Xvfb is fine) |
| `playtests/playtest_camera.gd` | Mouse look, pitch clamp, zoom, wall squeeze + player fade (pixel-checked). | yes |
| `playtests/playtest_visual_tour.gd` | 15 scenic screenshots (environment, nature, player), each auto-checked. Also checks the render budget (triangles, objects, draw calls of the busiest frame, per renderer). | yes |
| `playtests/playtest_village.gd` | 7 village screenshots (path, plaza, cottage front and interior, back wall, well, notice board), each auto-checked. | yes |
| `playtests/playtest_character.gd` | 7 screenshots of the dog (all sides, face close-up, walking, jumping, outfit). | yes |
| `playtests/playtest_creator.gd` | The character screen with the dog, cat and bunny, and the result in the world; panel fits the window; mouse captured after Start. | yes |
| `playtests/playtest_fishing.gd` | Fishing: ready, cast, bite, caught, night; bobber and ! on screen. | yes |
| `playtests/playtest_sleep.gd` | Sleep: bed prompt, lying down, waking, morning. | yes |
| `playtests/playtest_lake.gd` | The lake: wide view by day, dusk and night, reeds, lily pads, aerial view. | yes |
| `playtests/playtest_daynight.gd` | 6 times of day in the village plus a whole-day filmstrip. | yes |
| `playtests/playtest_animation.gd` | Filmstrips: walk, sprint, hop (side and front), idle. | yes |
| `playtests/playtest_movement.gd` | Movement filmstrips (contact sheets) for visual review. | yes |
| `tools/check_repo.py` | Free hygiene checks (runner step 1): every test in the runner and this map, step counts, agents documented, .uid files, no loose or debug files, lessons numbered and cited ones exist. | no |
| `tools/review_pack.py` | Prints the REVIEW PACK for agent briefs: diff summary, only the CHANGED screenshots, which agents are needed. | no |
| `support/playtest_kit.gd` | `PlaytestKit`: shared helpers (load world, input, shots, manifests, filmstrips). | no |
| `tools/make_qa_index.py` | Rebuilds `qa_output/INDEX.md` (what to review) from the manifests. | no |

New tests go in `functional/` (numbers) or `playtests/` (pixels), named `test_<thing>.gd` /
`playtest_<thing>.gd`, and get one row here. Never leave a loose file directly in `tests/`.
