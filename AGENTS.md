# AGENTS.md — Hearthwild

Every AI agent and every human working in this repo reads this file **before
making any change**. It is the source of truth for how work is done here.
If something in this file is wrong or out of date, fixing it is part of the
change that made it wrong.

---

## 1. What Hearthwild is

A **third-person multiplayer 3D village/life-sim survival game** in Godot.

> COZY during the day → ALIVE in the evening → DANGEROUS at night → RELIEF at morning.

Players live in a village: build, explore, gather, farm, socialize, care for
animals, decorate their houses, watch TV together. At night zombies come, and
players defend, cooperate, and survive until morning. Long-term target: Steam.

Hearthwild is a **third-person** game. Never turn it into a first-person game.

---

## 2. The one rule

**Build small → test → verify → expand.**

- Implement the **smallest correct next step**, never the whole game.
- Don't create folders, scripts, autoloads, managers, base classes or
  "frameworks" for systems that don't exist yet.
- Don't add placeholder architecture "because we'll need it later".
- A feature is **not done** because code was written. It is done when it has
  been run, tested, and its screenshots inspected (section 8).

---

## 3. Before you change anything

1. Read this file.
2. Run `git status` and `git branch`. Never start work on top of someone
   else's uncommitted changes without saying so.
3. Read `project.godot`, and every scene and script you're going to touch.
4. Run the test suite once (`tests/run_tests.sh`) so you know the starting
   state. If it already fails, report that before changing anything.
5. Verify what actually exists. **Never claim a feature exists, works, or was
   tested unless you checked it in the repo or by running the game.**

---

## 4. Engine and tools

| Thing | Value |
|---|---|
| Engine | **Godot 4.7.2**, standard build (GDScript, not .NET) |
| Renderer | Forward+ (CI uses the OpenGL compatibility renderer, no GPU) |
| Physics | Jolt |
| Machines | Windows PC and Linux laptop |
| Code editor | Cursor |
| Repo | https://github.com/poncema4/Hearthwild (public), default branch `master` |

- Every machine uses **exactly 4.7.2**. Different versions rewrite scene files
  and cause noisy, unrelated diffs.
- Never hard-code OS paths. Use `res://` (project) and `user://` (save data).

### Running things

| What | Command |
|---|---|
| Open the editor | `godot -e --path .` |
| Play the game | `godot --path .` (or F5 in the editor) |
| All checks | `tests/run_tests.sh` |
| Headless checks only | `tests/run_tests.sh --headless-only` |

---

## 5. Current state (keep this section accurate)

| System | Status | Files |
|---|---|---|
| World scene (the one main world) | Done | `scenes/world/world.tscn` |
| Meadow terrain (hills, hill ring, spawn clearing, pond) | Done | `scripts/world/terrain.gd` |
| Nature (trees, rocks, grass, flowers) | Done | `scripts/world/nature_scatter.gd`, `scenes/world/nature/` |
| Village: flat zone + plaza + dirt paths (terrain), 11 cottages, well, lamp posts, benches, notice board, fence | Done | `scripts/world/{village,house,village_props}.gd`, `terrain.gd` (`path_lines`, `in_village`), `world.tscn` (`Village`) |
| Village tests (flat ground, doors walkable, walls/roofs/props solid, nature keeps out, path walkable) + 7 village screenshots | Done | `tests/functional/test_village.gd`, `tests/playtests/playtest_village.gd` |
| Character screen (first launch + F2): pick dog / cat / bunny, dress 5 slots from a 7-item wardrobe, name over the head (Steam name hook), live 3D preview; saved profile (name, animal, outfit, fishing journal) in `user://profile.json` | Done | `scripts/ui/character_creator.gd`, `scripts/player/{player_profile,outfits,animal_species}.gd` |
| Fishing: 12 spots round the lake (measured from the real shore), cast / wait / bite / reel, day and night fish, rare fish and junk, journal, rod and arm pose | Done | `scripts/world/{fishing_spot,fishing_pond,fish_catalog}.gd`, `animal_model.gd` |
| Tests for them: profile, creator, fishing, species animation + creator and fishing playtests (panel fits the window, bobber on screen) | Done | `tests/functional/test_{profile,creator,fishing}.gd`, `tests/playtests/playtest_{creator,fishing}.gd` |
| Bigger world: 240 m square terrain, boundary walls at its edge (group `boundary`), 280 trees / 130 rocks / 48,000 grass; checked by the terrain test (size, walls by ray, trees past 70 m, none outside) | Done | `terrain.gd`, `nature_scatter.gd`, `world.tscn` (Boundary) |
| Bigger village: 8 cottages (3 at the plaza, 5 in a ring 24 m out), a dirt path from every door to the plaza, ring lamp posts and benches placed on free spots, flat zone 30 m; the player accelerates as a vector and always slides along walls | Done | `village.gd`, `terrain.gd`, `world.tscn` (path_lines), `player_controller.gd` |
| More houses and benches you can sit on: an outer ring of 3 cottages (11 in all, flat zone 42 m); every bench (10 in the village, 6 at the screen) has a `Seat`: E sits (legs out forward at seat height, hands in the lap, no collision), a fresh E / Space / move key stands up in front of the bench; one sitter per seat; a vanished bench, a respawn or going to bed releases the sitter | Done | `village.gd`, `terrain.gd`, `world.tscn` (paths), `scripts/interaction/seat.gd`, `village_props.gd`, `animal_model.gd`, `player_controller.gd`, `sleep_system.gd`; tests `test_sitting.gd` + village playtest shots |
| A realistic lake: 20 m radius at (46, −34), water shader with a baked depth map (shallows, foam, reflection, dark at night), reeds and lily pads (`LakeDecor`), trees kept 5 m off the banks, 12 measured fishing spots; the `water` group follows the clock | Done | `terrain.gd`, `assets/shaders/water.gdshader`, `lake_decor.gd`, `fishing_pond.gd`, `day_night.gd`, `nature_scatter.gd`; tests `test_lake.gd`, `playtest_lake.gd` |
| The shared screen: an 8 x 4.5 m screen on two posts with 6 benches on the village's north side (offset (6, −24) from the plaza), facing the plaza; E opens a paste-a-link box, `SharedScreen.parse_youtube_id` reduces any YouTube link to its 11-character id (hostile and malformed links rejected, nothing fetched), the screen shows which video was chosen; `url_changed` is the multiplayer hook (playback comes with multiplayer) | Done | `scripts/world/shared_screen.gd`, `village.gd`; tests `test_screen.gd` + village playtest shots |
| Day/night cycle: 20-minute day (about 10 minutes of night), sun and moon arcs, dusk/dawn colours, dimming ambient, lit lamp posts, HUD clock, plaza clock post with moving hands, `night_started`/`day_started` signals for zombies | Done | `scripts/world/{day_night,world_clock}.gd`, `world.tscn` (DayNight), `village_props.gd` |
| Tests for it: clock, light, sun path, smoothness, signals, lamps, clock hands + 7 screenshots incl. a whole-day filmstrip | Done | `tests/functional/test_daynight.gd`, `tests/playtests/playtest_daynight.gd` |
| Sleep: a bed in every cottage (solid, off the door lane), E at night: the character slides onto the bed and lies down, fade to black, the clock (paused the whole time) runs to 6:30 AM, the character stands beside the bed under the black screen, fade in; lying pose with Zzz; `fell_asleep`/`woke_up` signals | Done | `scripts/world/{bed,sleep_system}.gd`, `house.gd`, `animal_model.gd`, `player_controller.gd`, `world.tscn` (SleepSystem) |
| Tests for it: window edges, full sequence, clock, locks, pose, wake spot + 4 screenshots (half-faded wake frame) | Done | `tests/functional/test_sleep.gd`, `tests/playtests/playtest_sleep.gd` |
| Health: a reusable `Health` node (100 hp default, `damage` / `heal` / `revive` / `set_max`, signals `changed` / `damaged` / `healed` / `died`; bad numbers ignored, `died` once per life) on the player and every zombie, and a red HP bar under the HUD clock ("75 / 100", rounds up so a living player never reads 0). At 0 hp the player is knocked out: back at the spawn point at full hp with a message (`PlayerController._on_died`) | Done | `scripts/player/health.gd`, `scenes/player/player.tscn` (Health), `scripts/ui/interaction_prompt.gd` |
| The real keyboard is tested: W/A/S/D walk, Shift sprints, Space jumps, each bound to its own action (a rebound key now fails a test) | Done | `tests/functional/test_keys.gd` |
| Tests for it: maths, clamping, bad numbers, death once, revive, the HUD bar (text, fill, on screen) + 5 screenshots with pixel-read fill | Done | `tests/functional/test_health.gd`, `tests/playtests/playtest_health.gd` |
| The basic zombie (step 12): a code-built green box person (red glowing eyes, arms out, 20 hp, same capsule as the player) that walks toward the nearest awake player within 28 m at 2.4 m/s (the player walks 4), hits for 8 every 1.2 s at 1.5 m, ignores everyone while the SleepSystem runs, and is burned by the sun (2 hp/s, glows orange) when a ray from its head toward the sun (`DayNight.toward_sun()`) reaches the sky; roofs, hills, tree TRUNKS and rocks shade it (leaves have no collider yet: a zombie under a canopy still burns), characters and the invisible walls do not; the sun must be above 0.05 elevation; a hit also needs a clear line to the player (no hitting through a cottage wall) and the player within 1.6 m of its height. No wandering or obstacle avoidance until step 13 | Done | `scripts/mobs/zombie.gd`, `day_night.gd` (`toward_sun`), `player_controller.gd` (group `player`, `_on_died`) |
| The zombie spawner: none by day; a burst of 3 when the night starts, then one every 15 s up to 6 alive; spawn points 25 to 40 m from a random player, inside the walls (6 m margin), outside the village (6 m margin), on dry land and clear of trees, rocks and buildings (a capsule shape query); the test kit turns it off (`enabled = false`) so night tests get no visitors | Done | `scripts/mobs/zombie_spawner.gd`, `world.tscn` (ZombieSpawner), `tests/support/playtest_kit.gd` |
| Tests for them: 45 checks incl. a positive control for the sleeping rule, a real-roof shade check, every tunable pinned from both sides, wall and ledge checks, and 26 negative controls; 4 screenshots (night approach, close-up, burning, village night) with on-screen / not-hidden / glow-in-the-pixels checks | Done | `tests/functional/test_zombie.gd`, `tests/playtests/playtest_zombie.gd` |
| Day lighting (sun, sky, fog, SSAO, glow) | Done | `scenes/world/world.tscn` (WorldEnvironment, Sun) |
| Boundary walls + fall-out respawn | Done | `world.tscn` (Boundary), `player_controller.gd` |
| Third-person player (walk, hold-Shift sprint, hold-Space repeat jumps, coyote time, floor snap, gravity) | Done | `scenes/player/player.tscn`, `scripts/player/player_controller.gd` |
| Player character: cute bipedal dog from an `AnimalSpecies` (colours, ears, tail, snout), animated in code (idle wag/blink/breathe, walk and sprint cycles with foot lift, jump pose), 5 outfit sockets + placeholder cap and scarf | Done | `scripts/player/{animal_model,animal_species,outfits}.gd` |
| Interaction: E key, prompt/message HUD, hinged doors with collision on the cottages, readable notice board | Done | `scripts/interaction/{interactable,door,interactor}.gd`, `scripts/ui/interaction_prompt.gd` |
| Tests for them: interaction, character, animation (geometry of feet and hands, smoothness, skating) + character and animation screenshot/filmstrip playtests | Done | `tests/functional/test_{interaction,character,animation}.gd`, `tests/playtests/playtest_{character,animation}.gd` |
| Third-person camera (orbit, pitch clamp, zoom, wall collision, player fades when the camera is squeezed in) | Done | `scripts/player/third_person_camera.gd` |
| Visual tour (15 screenshots; with the camera playtest, 20 per run; each auto-checked) | Done | `tests/playtests/playtest_visual_tour.gd` |
| Terrain tests (collision alignment, placement, sand, determinism) | Done | `tests/functional/test_terrain.gd` |
| Movement feel test (accel, stop, turn, strafe, jump bands; spec in 8.5) | Done | `tests/functional/test_movement_feel.gd` |
| Movement filmstrips + screenshot manifests + `qa_output/INDEX.md` (date-only folders, changed-vs-previous) | Done | `tests/playtests/playtest_movement.gd`, `tests/support/playtest_kit.gd`, `tests/tools/make_qa_index.py` |
| Intentional-behaviour list, PR template with lessons gate, findings contract, dispatch matrix | Done | `docs/INTENTIONAL.md`, `.github/pull_request_template.md`, AGENTS.md 9.0 / 9.6 |
| Automated tests + CI | Done | `tests/`, `.github/workflows/tests.yml` |
| Playtest kit (shared helpers for scenario scripts) | Done | `tests/support/playtest_kit.gd` |
| Everything else | Not started | — |

**Controls:** WASD move · Shift sprint · Space jump · mouse look · wheel zoom ·
Esc frees the mouse · left-click captures it again.

**One world.** `scenes/world/world.tscn` is the single main world; everything
in the game hangs off it. There is **no separate test scene**: tests run on
the real world, so what Marco sees in the editor is exactly what's tested.

**World landmarks** (fixed by seed; tests depend on them, update tests if you change them):

| Landmark | Where |
|---|---|
| Size | 240 × 240 m, centred on the origin (`Terrain.size`) |
| Spawn | (0, 1, 0), camera facing −Z; flat clearing within ~4.5 m, gentle within 9 m; no trees/rocks within 11 m |
| Pond | the lake: centre (46, −34), radius 20, water surface y = −0.6; shoreline about 11.5 to 13.5 m from the centre |
| Hill ring | starts rising at 65% of the way to the edge, 14 m high at the edge |
| Boundary walls | inner faces at x = ±118 and z = ±118, i.e. 2 m inside the terrain edge (`Boundary` node, group `boundary`) |
| Village | centre (−20, 14); flat (y = 0) within 42 m, blends into the hills over the next 8 m; plaza radius 4.5 m (`Terrain.village_center` / `village_flat_radius` / `plaza_radius`) |
| Cottages | 11 houses, 6 × 5 m, walls 2.8 m, door 1.4 × 2.2 m facing the plaza (`House.*` constants); 3 at offsets (−9,−2), (9,−1), (0,−10) from the village centre, 5 in a ring 24 m out at 30, 75, 120, 160 and 230 degrees and 3 in an outer ring 36 m out at 52, 98 and 140 degrees (`Village.HOUSES`) |
| Paths | `Terrain.path_lines` in `world.tscn`: main path (0,0) → (−6,2) → (−12,6.5) → (−16,9.5) → (−20,14), plus one straight link from each of the 11 doors to the plaza centre (all 12 paths end at the well, so a walker steps aside at the end; accepted). Nature keeps 2.6 m off every path |
| Respawn | falling below y = −25 returns the player to spawn |
| Trees / rocks | 90 trees (round + pine), 45 rocks: `Nature.get_trees()` / `get_rocks()` |

**Hills are the border.** The hill ring is steeper than the 45° the player can
climb in places (about z = 46 on the south side, z = 50 on the north), so the
player stops at the slope; elsewhere they walk up to the invisible walls at
±58. Nobody is trapped (walking back down always works). Trees and rocks are
solid: walking straight at one stops you dead, which is correct.

**Known issues (Low, recorded not fixed):**
- Pressed against the hill rim, the strip of ground right under the camera has
  little grass (a pale flat band at the bottom of `camera/05_against_wall`).
- Shaded hill faces show faint light speckle from distant grass tufts.
- The player's cream "nose" sphere reads like a button from the front (placeholder art).
- The character is a placeholder capsule with no animations.

Terrain and nature are `@tool` scripts: they also run **inside the editor**,
and their generated nodes are never saved into the scene file.

---

## 6. Project structure and naming

Create a folder **only** when the first file that belongs in it is created.

```text
scenes/world/world.tscn   THE main world. Everything connects to it.
scenes/world/<part>/      pieces the world uses (nature/: trees, rocks; village/ ...)
scenes/<area>/            .tscn scenes: player, zombies, npcs, ui ...
scripts/<area>/           .gd scripts, mirroring scenes/<area>/ (mobs/ holds the zombie and its spawner: code-built, no scene file)
assets/<kind>/            models, textures, materials, audio, fonts (real assets only)
systems/<name>/           cross-cutting systems: day_night, saving, networking ...
tests/                    run_tests.sh + README.md (the map). ONLY these subfolders:
  functional/             headless tests that assert numbers: test_<thing>.gd
  playtests/              rendered screenshot tests: playtest_<thing>.gd
  support/                playtest_kit.gd (shared helpers)
  tools/                  scripts the tests use (make_qa_index.py)
docs/                     VISION.md (north star), INTENTIONAL.md (NOT bugs: agents read first)
qa_output/                INDEX.md, run_meta/<stamp>.json, RENAMED.md (local note), and
                          <topic>/<YYYY-MM-DD_HH-MM-SS>/NN_name.png + manifest.json (gitignored, never deleted)
.claude/agents/           AI agent definitions (section 9)
.github/                  workflows/ (CI) and pull_request_template.md
```

**No loose files.** Every file lives in the folder for its purpose; the repo root holds only
`project.godot`, `icon.svg` (+ Godot's generated `icon.svg.import`), `README.md`, `AGENTS.md` and the
git/editor dotfiles. Anyone (human or
agent) should find anything from this tree and `tests/README.md` without listing folders or searching;
that keeps reading cheap. A new test adds one row to `tests/README.md`; a new doc adds one line to this
section. Orphan files (unused scenes, scripts, resources) are findings for Sage.

- Files and folders: `snake_case` — `player_controller.gd`, `day_night_manager.gd`.
- Nodes: `PascalCase` — `CameraRig`, `SpringArm3D`, `TestWall`.
- `class_name` in `PascalCase` for any script other code refers to by type.
- Tests: `tests/functional/test_<thing>.gd` for headless checks that assert numbers,
  `tests/playtests/playtest_<thing>.gd` for rendered checks that save screenshots.
- **Banned names:** `test2.gd`, `final.gd`, `new.gd`, `stuff.gd`, `temp.gd`,
  `zombieFINAL.gd`, anything with `copy`, `old`, `v2`.

---

## 7. Code rules

### GDScript

- Tabs for indentation. Static types everywhere: `var speed: float`, `-> void`.
- `@export` for every tunable number (speeds, distances, timings). No magic numbers.
- `@onready var _x: Type = $Path` for node references. Private members start with `_`.
- A `##` doc comment at the top of every script: what it does, and any node
  layout it expects.
- Input always goes through **named actions** in the Input Map
  (`move_forward`, `jump`, ...). Never check raw keycodes in gameplay code.
- Signals for "something happened"; direct calls for "do this now".
  Prefer composition (child nodes) over deep inheritance.

### Architecture

- **Time is centralized.** When day/night arrives, exactly one manager owns
  the clock. Every other system reads from it or listens to its signals. No
  system keeps its own clock or timer for "time of day".
- **Multiplayer-aware, not multiplayer-built.** Each entity reads its input in
  one place (see `PlayerController._read_move_input()` and `_wants_jump()`),
  so networking can later feed network input there for remote players.
  Game state changes should go through clear functions, not be poked
  directly from many places. **Don't add networking code** before the
  multiplayer-foundation step.
- **Don't rewrite or delete working systems** without stating why in the PR.
- **One concern per change.** Don't modify unrelated files in the same PR.
- Scenes are text (`.tscn`). Keep them tidy: no orphan nodes, no leftover
  debug nodes, meaningful node names.

---

## 8. Testing — the definition of done

Every change runs **all** of this before a PR, and CI runs it again on the PR.

### 8.1 The runner

`tests/run_tests.sh` runs, in order:

1. **import project:** headless import; catches broken resources.
2. **load main scene:** runs the game headless for 60 frames; catches
   script and scene errors.
3. **editor load:** opens the editor headless. `@tool` scripts run only in
   the editor, so errors there are invisible to step 2 (proven: a planted
   editor-only error passes step 2 and fails here).
4. **player movement test:** `tests/functional/test_player_movement.gd`, headless.
5. **terrain test:** `tests/functional/test_terrain.gd`, headless. A ray grid proves the
   collision matches the visible ground (120 points, worst error 0.000 m);
   players dropped on hills, the rim and the pond bed rest where predicted
   (slope-aware); trees and rocks sit on the ground; no sand away from the pond.
6. **movement feel test:** `tests/functional/test_movement_feel.gd`, headless. Measures walk/sprint
   start, stop, 180 turn, strafe reversal and jump in frames and metres against the bands in 8.5.
7. **village test:** `tests/functional/test_village.gd`, headless. Flat ground under every house corner,
   props grounded and solid at knee height, houses 7+ m apart and facing the plaza, door bigger than the
   player's capsule, no tree or rock in the village or on a path, a ray from above hits each roof, the real
   player walks IN through each door and CANNOT walk through a side wall, and the main path is walked
   segment by segment from the spawn to the plaza. 12 negative controls recorded in lessons 36 and 39.
8. **camera playtest:** `tests/playtests/playtest_camera.gd`, rendered, screenshots in
   `qa_output/camera/<date_time>/`.
9. **visual tour:** `tests/playtests/playtest_visual_tour.gd`, rendered; 15 screenshots into
   `qa_output/{environment,nature,player}/<date_time>/`, each checked by `kit.check_rendered()`
   (fails on black, blown-out or flat single-colour images).
10. **movement playtest:** `tests/playtests/playtest_movement.gd`, rendered; 5 filmstrips (contact
   sheets) into `qa_output/movement/<date_time>/` (see 8.4).
11. **village playtest:** `tests/playtests/playtest_village.gd`, rendered; 7 screenshots into
   `qa_output/village/<date_time>/` (path from the spawn, plaza, a cottage front and interior, a back wall,
   well and lamps, notice board), each checked by `kit.check_rendered()`.

**Step 6 added five more steps (16 in all):** interaction test, character test and animation test (headless, run
right after the village test), and the character and animation playtests (rendered, run last). Interaction test:
prompt text, facing and range rules, E opens and closes the door, a door won't close on a player in the doorway,
the notice board message. Character test: parts, size, grounding, big head, fadeable materials, species
variety, outfits sit on sockets and fade. Animation test: see lesson 42.

**Step 7 added two more (20 in all):** daynight test (headless; clock text, noon vs midnight light, sun path east to west,
dusk colour, smoothness over the whole day, clock speed and wrap, pause, `night_started`/`day_started` exactly once, lamps,
plaza clock hands, HUD clock) and the daynight playtest (rendered; 6 times of day plus a whole-day filmstrip). **Every step has
a timeout** (`STEP_TIMEOUT`, default 600 s): a hung Godot fails the step. The test kit freezes the clock at 10:00 on load.

**Steps 7a/7b added five more (25 in all):** profile test, creator test, fishing test (headless) and the creator and
fishing playtests (rendered). The creator playtest also checks that the whole panel fits the window and that the mouse is
captured after Start; the fishing playtest checks the bobber, line and ! project onto the screen. `test_animation` now also
runs the cat and the bunny through the walk and jump geometry.

**Step 8 added two more (27 in all):** sleep test (headless; window edges both sides, the full night, clock, locks, pose, wake spot)
and the sleep playtest (rendered; bed prompt, lying, half-faded wake, morning).

**Step 12 added two more (36 in all):** zombie test (headless, right after the health test; the whole zombie and spawner contract above, run in the real world with the real roofs, bed and sleep sequence; 26 negative controls via `mutate.py`) and the zombie playtest (rendered; 4 screenshots, topic `zombies`).

**Step 11 added three more (34 in all):** keys test (headless, right after the movement test; injects REAL `InputEventKey`s for W/A/S/D, Shift and Space and measures the distance walked, the sprint ratio and the jump, and checks the Input Map binds each key to its own action; 6 negative controls), plus: health test (headless; the component's maths, clamping, bad numbers, `died` once,
revive, and the player's HP bar text, fill and screen position; 7 negative controls were watched failing) and the health
playtest (rendered; 5 screenshots of the bar at full / 50% / 35% / 1 hp / dead, with the fill read back from the real pixels; 3 controls).

After the steps the runner writes `qa_output/run_meta/<date_time>.json` (branch, commit, renderer,
result) and regenerates `qa_output/INDEX.md`.

**Speed: headless runs use `--fixed-fps 60`.** Without it Godot runs in real
time (60 physics frames = 1 real second), so a long scenario takes minutes.
`--fixed-fps 60` keeps the identical 60 steps per game second but removes the
real-time wait: the movement test goes from 13.7 s to 0.8 s with the same results.

**No pop-up windows.** When Xvfb is installed, rendered steps run on an
invisible virtual display with `HW_NO_REAL_MOUSE=1`, so a real mouse can't
interfere and every check runs. `HW_SHOW_WINDOW=1` shows the window instead.
Without Xvfb, rendered steps open a real window and the captured-mouse check
prints `SKIPPED`.

**Screenshots are never deleted.** See 8.4 for how they are named and indexed.

The runner fails if **any** step exits non-zero **or** prints `SCRIPT ERROR`,
`ERROR:`, `Parse Error` or `Failed to load`. Godot often exits 0 even after a
script error, which is why the log scan exists. **Never remove it.**

### 8.2 Writing a test

- A test is a `SceneTree` script. It loads the **real** scene, drives it with
  the **real** input actions (`Input.action_press`) or real input events
  (`Input.parse_input_event`), waits real physics frames, and asserts on the
  result. It prints `PASS <name>  (<measured values>)` or `FAIL ...`,
  ends with `RESULT:`, and exits with the number of failures.
- Always print the **measured values**, not just pass/fail, so a reader can
  judge whether the check meant anything.
- Every new feature adds checks. Every bug fix adds a check that would have
  caught the bug.

### 8.3 Rules against false positives (read these twice)

1. **Prove a check can fail.** For every new check, break the thing it guards
   (disable the collision, remove the action, comment out the line), run the
   test, and **watch it FAIL**. Then restore. A check you haven't seen fail
   is unproven. Real example from this repo: "wall blocks movement" passed
   at z=4.37, which is just how far the player got in 4 seconds. It would
   have passed with no wall. Fixed by asserting the player stops *at the wall
   face* (5.2 < z < 5.5) and walking long enough that a missing wall carries
   the player far past it (proven: z=12.37 without the wall).
2. **Assert the reason, not just the exit code.** A crash and a detected
   failure both exit non-zero. A traceback is not a pass and not a "test
   flake"; read it.
3. **Bounds on both sides.** "z < 5.8" passes for any value below it, including
   "never moved". Assert a range that only the correct behaviour lands in.
4. **Isolate from the real world.** Windowed tests capture the mouse; real
   mouse movement during the run injects input. Release the mouse
   (`MOUSE_MODE_VISIBLE`) as soon as the mouse checks finish, and don't
   touch the mouse while a playtest runs. Real example: real mouse jitter
   turned the camera mid-test, so the player walked *around* the wall.
5. **Read the artifact, not the description.** "Screenshot saved" is a claim.
   Open the PNG and look at it. "Test passed" is a claim. Read the PASS lines
   and their numbers.
6. **State exclusions by name.** If a check is skipped (for example
   `--headless-only`), the output must say `SKIPPED`, and the report must
   list it. A silent gap and a skipped check look identical in a green result.
7. **One instance means look for all.** If a bug shows up in one place, check
   every other place of the same kind before calling it fixed.
8. **Never claim** something was tested, a screenshot was inspected,
   multiplayer works, or performance is fine unless that actually happened
   in this change.

### 8.4 Screenshots and the QA index

- **Folders are named ONLY by the date and time of the run:** `qa_output/<topic>/<YYYY-MM-DD_HH-MM-SS>/`.
  Never a label like `final2` or `polish` (lesson 16). Files are `<NN>_<name>.png`. Topics: `camera`,
  `environment`, `nature`, `player`, `movement`, `village` (add new ones as systems appear: `zombies`, ...).
- **Every run folder has a `manifest.json`:** per image, `what` it shows, `expect` what a correct frame
  looks like, and `changed_vs_previous` (fraction of pixels that differ from the same image in the previous
  run; `null` = new image). Filmstrips also carry `samples`, one per thumbnail: `index`/`row`/`col` (which
  thumbnail), `t` (game seconds: the frames the game really ran, counted by the harness, which freezes the game while capturing), `pos`, `speed` (the player's
  ACTUAL horizontal velocity in m/s), `on_floor`, `cam_dist` (camera arm length) and `body_yaw_deg`. The
  first thumbnail is taken before any input (standing still, t = 0).
- **Change detection:** `changed_vs_previous` compares a 160x90 luminance thumbnail with the same-named
  image from the newest earlier run **with the same renderer** (the manifest records it); "unchanged"
  means under 0.2% of pixels differ, not byte-identical (use `md5sum` for that). A fresh folder or CI
  artifact has no history, so everything there is "new". `RUN_STAMP` is validated as `YYYY-MM-DD_HH-MM-SS`.
- **Filmstrip capture is deterministic:** the game is frozen while each frame is grabbed, so thumbnails
  are exactly `every` game frames apart on every machine and `t` counts only frames the game really ran.
- **The index never hides a failure:** the newest run comes from `run_meta` (it exists even if a step
  crashed), a missing topic shows as **MISSING**, a failed run gets a **WARNING**, and an unreadable
  manifest fails the runner step "qa index".
- **`qa_output/INDEX.md` is the table of contents** (regenerated by `tests/tools/make_qa_index.py`): the
  newest run, with each image marked **REVIEW** (new or changed) or unchanged, and a table of all runs with
  branch, commit and result. Reviewers read the index, then only the REVIEW images (token saving).
- Add a screenshot: `await kit.shot(topic, name, what, expect)` (or `kit.filmstrip(...)`), and add its
  description. Never delete or overwrite old runs. The folder is gitignored.
- A **filmstrip** is ONE image: thumbnails read left to right, top to bottom = time. It lets Hawkeye judge
  movement (smoothness, turning, jumping, camera follow) from a picture plus the manifest numbers.

### 8.5 Movement feel spec (the bands `test_movement_feel.gd` enforces)

| Move | Measured now | Band | Meaning of a failure |
|---|---|---|---|
| Walk start to 90% speed | 8 frames (0.13 s) | 2-24 frames | under 2: instant snap; over 24: sluggish |
| Sprint start to 90% speed | 13 frames (0.22 s) | 3-30 frames | same |
| Walking stop (frames) / slide | 8 frames / 0.23 m | 3-20 frames / under 0.6 m | under 3: an instant halt; over 20: icy |
| 180 degree turn (body within 10 deg) | 13 frames (0.22 s) | 6-30 frames | spinning too fast or lagging |
| Strafe reversal | 9 frames | 3-30 frames | same |
| Jump apex / airtime | 1.32 m / 1.07 s | 1.0-1.5 m / 0.7-1.2 s | floaty or heavy jump |
| Holding Space (takeoffs counted over 300 frames) | 5 (frames 0, 63, 126, 189, 252) | 4 to 5, gaps of at least 55 frames | no repeat (1 takeoff) or a double jump (gaps under 55); a single tap must stay exactly 1 hop |

When you tune the feel on purpose, change the band **in the same PR**, say why, and update
`docs/INTENTIONAL.md`. The test exists so feel changes are deliberate, not accidental.

---

## 9. The agent team

Work is done by one **lead** (the main Claude Code session) plus specialist
agents in `.claude/agents/`:

| Agent | Role | Model | One line |
|---|---|---|---|
| **Warden** | Test runner | Haiku | Runs the full suite, reports every PASS/FAIL with numbers. Nothing merges without its pass. |
| **Scout** | Playtester | Sonnet | Plays the game trying to break it, in one fast headless run. |
| **Hawkeye** | Visual QA | Sonnet | Opens real screenshots and reports anything that looks wrong. |
| **Sage** | Code reviewer | Sonnet | Reviews the diff before merge: bugs, rule breaks, weak tests, missing docs. |

Names are short; each agent file's `description` line says exactly what it does. Start lean: specialists are added only
when a system is big enough to own (multiplayer, zombie AI, ...).

### 9.0 The findings contract (every agent follows this)

The goal is near-zero false positives at low token cost. These rules are in every agent file too.

1. **Read order (cheap first):** `docs/INTENTIONAL.md` (what is NOT a bug) -> your agent file -> the lead's
   brief -> only the files you need. Don't read the whole repo.
2. **A finding needs all of:** evidence (a quoted line, a measured number, or an image path + region),
   a way to reproduce it (command, script or crop), a severity from the rubric, a confidence, and a line
   saying why it is not intentional (you checked `INTENTIONAL.md` and section 14).
3. **Triage before reporting (the false-positive protocol):** (a) reproduce it a second, independent way
   (re-run, crop the image, different input); (b) rule out your own setup (settling after a teleport,
   slope offset, the camera's shoulder offset, a real mouse, renderer differences); (c) check
   `INTENTIONAL.md` and the lessons; (d) check it isn't already a known issue. Fail any step: it goes in
   **DISMISSED**, not FINDINGS.
4. **Severity rubric:** **High** = crash, script error, broken core loop, data loss, security, or the game
   unplayable. **Medium** = wrong behaviour or look a player will notice; a test that can't fail on a core
   system. **Low** = polish, cosmetic, placeholder. **Nit** = taste. Add the tag **HARNESS** when the
   defect is in the test tooling or its data (a wrong label, a bad manifest), not in the game.
5. **Report sections, always:** CONFIRMED FINDINGS, DISMISSED (what looked wrong and why it isn't),
   UNCONFIRMED (under 60% confidence: not findings, the lead decides), what you EXERCISED/REVIEWED,
   what you did NOT test, budget used, VERDICT. An empty DISMISSED section on a big review is a smell.
6. **Never:** claim something you didn't see or run; use "probably"/"seems" without a confidence level;
   edit the repo (agents are read-only; `/tmp` is yours); pad the report.
7. **Budgets are hard.** At the budget, stop and send a partial report with NOT TESTED. A late complete
   report is worse than an on-time partial one. A missing report is **not** a pass.
8. **When you were wrong or the lead overrules you:** the lead records it in section 14 and your agent
   file in the same PR, so you don't repeat it.

### 9.1 Lead (main session)

- Plans the change, keeps it small, writes the code, writes the tests.
- Proves new checks can fail (8.3 rule 1).
- Dispatches the specialists after the change is built; the specialists can run in
  parallel because they don't edit the project.
- Reconciles their reports. A specialist's report is evidence, not a verdict:
  if a report says PASS but quotes no measured values, treat it as unproven.
- Owns the git workflow (section 10).

### 9.2 Warden: test runner (`warden`)

- **Job:** run `tests/run_tests.sh`, report exact results.
- **Model:** Haiku, because it's mechanical.
- **Must report:** every step's name and result; every `PASS`/`FAIL` line with
  its measured values; any `SKIPPED` step; the final exit code.
- **Must not:** edit any file; re-run until green and report only the green
  run (report **every** run); summarize a failure as "flaky" without
  evidence; call a run passing if any step printed an error.

### 9.3 Scout: playtester (`scout`)

- **Job:** play the game like a player trying to break it. Writes **one**
  throwaway scenario script outside the repo using `tests/support/playtest_kit.gd`,
  runs every scenario in a **single** headless Godot launch, and follows a fixed
  checklist plus 2–4 scenarios aimed at the new feature.
- **Model:** Sonnet.
- **Budget:** at most 3 Godot launches and about 5 minutes. On-time partial
  beats late complete.
- **Must report:** each finding with measured numbers and a repro, an
  `EXERCISED` list, a `NOT TESTED` list, and launches used.
- **Must not:** edit project files (propose fixes, don't make them); report a
  problem it didn't reproduce; report "everything works" without listing
  exactly what was exercised.
- **Cheap routes:** use `PlaytestKit.drive_to` / `stop_driving` (the soak bot's engine) instead of writing walking loops; see the Scout file.

### 9.4 Hawkeye: visual QA (`hawkeye`)

- **Job:** review the screenshots and movement filmstrips that CHANGED since the previous run (read
  `qa_output/INDEX.md`; skip unchanged images), confirm every suspected artefact with a **pixel crop**
  (PIL) before reporting it, and judge movement from filmstrips plus their `samples` numbers.
- **Model:** Sonnet (needs to read images). **Budget:** under ~12 image reads for a normal change; no Godot.
- **Must report:** CONFIRMED FINDINGS (image, region, crop evidence, previous run had it?, severity,
  confidence, why not intentional), DISMISSED, UNCONFIRMED, REVIEWED (one line per image), NOT REVIEWED.
- **Must not:** report from a glance without a crop; describe an image it didn't open; edit files; trust a
  described baseline without `md5sum`; report anything listed in `docs/INTENTIONAL.md`.

### 9.5 Sage: code reviewer (`sage`)

- **Job:** review the branch's diff (committed, uncommitted, untracked) before merge against AGENTS.md
  sections 7, 8.3 and 14: bugs, rule breaks, tests that can't fail, **organization** (no loose files, right
  folders, names), the **lessons gate** (section 10), and docs shipped with code.
- **Model:** Sonnet. **Budget:** about 10 minutes, no Godot launches needed (one headless run to confirm a
  suspicion is fine).
- **Must report:** each finding with severity, `file:line`, quoted evidence, concrete failure and
  confidence; DISMISSED; UNCONFIRMED; REVIEWED / NOT REVIEWED; a verdict.
- **Must not:** edit files; report style preferences as bugs; make findings without evidence; report
  intentional behaviour.

### 9.5a Mason: world and layout reviewer (`mason`)

- **Job:** measure whether the world is built correctly and can't trap the player: flat footprints, door
  scale vs the capsule, solid walls/roofs/props, clear doorways, pockets a player could enter but not leave,
  roof/ledge reach vs the 1.3 m jump, nature kept out of the village, connected paths. Evidence is always a
  ray cast or a short headless probe, never "looks close".
- **Model:** Sonnet. **Budget:** about 10 minutes: the village test once plus at most 2 probe scripts in /tmp.
- **Run when:** a change touches terrain, village, buildings, props, paths or nature placement (a Hawkeye
  look plus a Mason measurement is the pair for any layout change).
- **Must report:** the 9.0 contract plus REVIEWED / NOT REVIEWED (what it measured), and a SHIP / FIX FIRST
  verdict. **Must not:** edit files, judge art or colour (Hawkeye), or re-report what `test_village.gd`
  already proves unless it shows the check cannot fail.
- **Not yet calibrated** (section 9.8): its first calibration plants a missing wall collider, a 0.6 m door
  and a prop jammed against a wall (a pocket), plus controls.

### 9.5b Animator: animation reviewer (`animator`)

- **Job:** judge whether the character moves believably: limb directions (measured as foot and hand positions, never
  from an angle sign), walk cycle, foot skating, symmetry, jump pose seen from the FRONT, snaps between frames,
  readability of the filmstrips, deterministic timing (physics tick). See the file for the table of numbers.
- **Model:** Sonnet. **Budget:** about 10 minutes on a /tmp copy. **Run when:** a change touches the model,
  its animation, movement feel or outfits (Hawkeye for stills, Animator for motion).
- **Must report:** the 9.0 contract plus MEASUREMENTS and a SHIP / FIX FIRST verdict. **Must not:** edit files, judge
  colours or composition (Hawkeye), or report placeholder simplicity (no elbows) as a defect.
- **Not yet calibrated** (9.8): its first calibration plants backward knees, crossed arms and skating legs.

### 9.5c Ghoul: zombie AI reviewer (`ghoul`)

- **Job:** judge whether the zombies behave as designed (Minecraft logic) and cannot be fooled or made unfair: chase range and speed vs the
  player's walk, melee timing, a sleeping player left alone for the whole sleep, the sun ray (blockers, characters, boundary walls, dawn and dusk
  edges), spawn rules (distance, village, water, edges, cap), a clean knock-out state, and NaN / division-by-zero traps. Evidence is always a
  headless probe, never "looks right".
- **Model:** Sonnet. **Budget (lesson 60):** 5 minutes and at most 10 tool calls, one batched probe script plus ONE `mutate.py` call, in a /tmp copy.
- **Run when:** a change touches `scripts/mobs/`, `DayNight.toward_sun` / `sun_elevation`, the SleepSystem, or the player's Health / knock-out.
- **Must report:** the 9.0 contract plus REVIEWED / NOT REVIEWED and a SHIP / FIX FIRST verdict. **Must not:** edit files, judge art
  (Hawkeye), report missing obstacle avoidance or wandering (step 13), or re-report what `test_zombie.gd` proves unless it shows a check cannot fail.
- **Not yet calibrated** (9.8): its first calibration plants a zombie that burns in a cottage, one that chases a sleeper, and a spawner
  that ignores the cap, with unmodified controls.

### 9.6 Dispatching agents efficiently (lead's rules)

Agents start with **zero context**. A vague brief makes them explore, which is
slow and expensive. Every dispatch includes:

1. **What changed:** the exact files and a one-line summary of the feature.
2. **What to focus on:** the 2–4 risky behaviours of this change.
3. **Constraints:** headless or windowed, output folder, what not to touch.
4. **Budget:** launches and minutes (Scout: 3 launches / 5 min;
   Warden: 1 suite run; Hawkeye: inspect the given images, render at
   most once).
5. **"Read your agent file first"**, which holds the format and rules, so
   the brief doesn't repeat them.

Scheduling:

- **With Xvfb, all of them run in parallel**: each rendered run gets its own
  invisible display (`xvfb-run -a`), so they can't steer each other. Give
  Hawkeye the screenshots from the lead's own suite run, so it doesn't have to
  wait for Warden. **Without Xvfb**, only one windowed Godot at a time
  (real windows grab the mouse).
- Pick the cheapest model that can do the job: Haiku for mechanical runs,
  Sonnet for judgement and images. The lead's model is never used for routine runs.
- **Dispatch matrix: send only the agents the change needs.**

  | Change | Warden | Scout | Hawkeye | Sage |
  |---|---|---|---|---|
  | Docs, comments, constants | yes | no | no | no (lead checks) |
  | Visual only (colours, lighting, models, layout) | yes | no | yes (changed images) | no |
  | Controls, physics, gameplay logic | yes | yes (targeted) | if visible | yes |
  | A new system (village, zombie ...) | yes | yes | yes | yes + that system's specialist (zombies: Ghoul) |
  | Terrain, buildings, props, paths, nature placement | yes | no (the village test walks it) | yes (changed images) | yes + Mason |
  | Character model, animation, outfits, movement feel | yes | yes (targeted) | yes (changed images) | yes + Animator |
  | Agents, docs, test tooling | yes | no | no | yes |
  | Pre-release or risky | all | all | FULL REVIEW | all |

- **Cheapest first (cost rules; lesson 44).** Order every change through these tiers and stop paying once a tier answers:
  0. **Free, every run:** `tests/run_tests.sh` (18 steps, starting with `tests/tools/check_repo.py`, which catches doc drift,
     missing README rows, stale step counts, loose files, missing .uid files and lessons cited but not written) and the
     **soak test** (a bot drives the real player along a route with Shift and Space held and fails on any stall, blocked
     path, dead door or fall). Agents never re-check what these prove.
  1. **Lead looks** at the changed screenshots first (about 5k tokens each, no agent needed for obvious faults).
  2. **Brief from the pack:** `python3 tests/tools/review_pack.py` prints the diff summary, ONLY the changed images and
     the agents this change needs. Paste it into the brief; agents read the pack, not the repo.
  3. **Agents, only the ones the pack names**, in parallel, each on a /tmp copy, one round. **Warden is skipped** when the
     lead ran both renderers green (CI on the PR is the independent run; a Warden round is ~70k tokens for nothing new).
     After a fix, re-run only the agent whose finding it was.
  Typical docs-only PR: 0 agents. Typical code PR: Sage + the one specialist (Mason, Animator or Hawkeye).
- **Delta re-review (lesson 60).** After fixes, re-run only the agent whose finding it was, with a brief of this shape: one line per
  finding + the ONE command that verifies it + the lead's own evidence already collected (paste the mutation output). No rendered
  runs unless the finding is visual, no re-auditing docs the lead already checked with `check_repo.py`, budget 5 minutes, hard stop.
  Expected times: Hawkeye ~40 s, Scout ~90 s, Sage first review ~90 s, Sage delta under 5 minutes. If a round runs past twice its
  expected time, message it to stop and report, then shrink the next brief.
- **Before dispatching Sage, run the lessons gate yourself** (the PR template checklist: lessons in section 14 AND
  in the agent files, INTENTIONAL.md, README, state table). Sage will find it, and a round costs ~100k tokens (lesson 30).
- **Sage also runs on any PR that touches `AGENTS.md` section 14 or `.claude/agents/`** (it enforces the
  lessons gate), whatever the change type.
- **Token costs (measured on PR #2):** Warden ~55-65k, Scout ~90-130k, Hawkeye ~105k for 20 images
  (~3-5k per image read), Sage ~130k. So: Hawkeye changed-only (5-10 images, ~30-50k); don't dispatch what
  a test already covers; one round per PR where possible; after a fix re-run **only the agent whose
  finding it was**, plus Warden; give a diff stat in the brief so agents don't explore.

### 9.7 Agents to add as the game grows

Add a specialist **when its system exists and is big enough to own**, never
before. Each new agent gets a short name and a file in `.claude/agents/<name>.md`
written to the same standard: a `description` that starts with its role,
job, model, budget, exact report format, must-nots.

| Agent | Add when | Owns |
|---|---|---|
| **Mason** (`mason`), world and layout reviewer | **Added with the village (step 5)**, see 9.5a | Terrain, buildings, props, paths, can-the-player-get-stuck |
| **Ghoul** (`ghoul`), zombie AI | **Added with the basic zombie (step 12)**, see 9.5c | Spawning, detection, melee, sunlight and shade, knock-out; navigation arrives with step 13 |
| **Pulse** (`pulse`), performance tester | Village + zombies exist | Frame time, draw calls, measured numbers per scene |
| **Relay** (`relay`), multiplayer | Multiplayer foundation (step 16) | Networking, sync, authority; tests with 2+ real instances |
| **Atlas** (`atlas`), researcher | Any time a technical choice is unclear | Godot APIs, plugins, licensing. Recommends; never edits |

### 9.8 Calibrating the agents (planted defects)

To measure an agent's false-positive and miss rate instead of guessing: make a temp copy with **known
defects planted** plus unmodified **controls** (Hawkeye: images with a magenta patch, a crushed-dark
region, a camera-inside-geometry crop; Scout: a disabled collision; Sage: a diff with a planted bug and a
test that cannot fail), run the agent with its normal brief, and score **recall** (planted found) and
**false positives** (findings on the controls). Target: **0 false positives on controls, at least 90%
recall**. When an agent misses or over-reports, fix its file and re-run. Record each calibration here:

| Date | Agent | Planted | Found | Controls | False positives | Notes |
|---|---|---|---|---|---|---|
| 2026-10-02 | Hawkeye | 4 (magenta patch, near-black rectangle, washed-out frame, flat-green "camera inside terrain") | 4 | 4 (rock close-up, pond shore, player front, tree close-up: all contain intentional quirks) | **0** | Recall 100%. Correctly DISMISSED the capsule, cream nose, rock-near-tree perspective and tree shadows with the INTENTIONAL.md reason. Whole-frame defects were confirmed with statistics (mean colour, saturation) instead of a crop. 81k tokens for 8 images (mostly reading its docs). **Limit:** the defects were large and obvious; the next calibration must plant SUBTLE ones (a 20x20 px seam, an 8% brightness shift) to measure the real edge. |
| 2026-10-02 | Mason | not yet calibrated (first real run on the village: found 1 Low, the dirt links stopped 1.5 m short of the doorsteps, plus 0 false positives on 6 dismissed items) | n/a | n/a | n/a | **Plan:** plant a missing wall collider, a 0.6 m door and a prop jammed 0.5 m from a wall (a pocket), with unmodified controls; target 0 false positives, 90% recall |

---

## 10. Git and PR workflow (every change)

Branch protection doesn't require PRs on this repo, but **every change goes
through a PR anyway.** No direct pushes to `master`.

1. Start from an up-to-date `master`: `git switch master && git pull`.
2. Create a branch: `feature/<short-name>`, `fix/<short-name>`, or `chore/<short-name>`.
3. Build the change, write and prove the tests, run `tests/run_tests.sh` **in
   both renderers** (normal, and CI mode:
   `GODOT_FLAGS="--rendering-driver opengl3 --rendering-method gl_compatibility --audio-driver Dummy" QA_OUTPUT=/tmp/hw_ci tests/run_tests.sh`),
   and dispatch **only the agents the change needs** (matrix in 9.6). Fix everything they find, or
   record it in `docs/INTENTIONAL.md` / section 5 known issues.
4. Review the diff: no unrelated files, nothing from `.gitignore` forced in,
   no secrets.
5. Commit with a descriptive message (`Add third-person player controller`,
   `Fix camera collision`). Never `update`, `stuff`, `final2`.
6. Push and open a PR to `master` using the template in
   `.github/pull_request_template.md` (what changed, bugs found and fixed, what was
   tested with real numbers, the **lessons gate**, known issues, next step).
7. Wait for the **Tests** CI check on the PR.
   - **Passes:** merge into `master`, then delete the branch (remote and local).
   - **Fails:** read the CI log, fix it **on the same branch**, push a new
     commit, and wait again. The same PR updates in place. **Never open a
     new PR for a fix, never force-push, never merge a red PR.** Never "fix" CI
     by weakening or deleting a check; fix the cause.
   - Every failure teaches something: add it to **Lessons learned**
     (section 14) and to the affected agent's file **in the same PR**.

**The lessons gate (Marco's standing rule; Sage enforces it).** Before a PR merges, if **anything** went
wrong while building it (a CI failure, a failing check, an agent finding, a false positive, a mistake of the
lead's), then in **this same PR**: (1) the lesson is a row in section 14.1 (what happened, cause, rule);
(2) the agent file(s) that should have known are updated so it can't happen again (`.claude/agents/<name>.md`);
(3) `docs/INTENTIONAL.md` is updated if a new behaviour turned out to be intended; (4) good patterns go in
14.2. If nothing went wrong, the PR says "no failures". Goal: each mistake happens once, and the agents'
false-positive rate trends to zero.

CI differs from a dev machine: **no GPU** (OpenGL compatibility renderer),
**no sound card** (`--audio-driver Dummy`), **no real mouse** (`HW_NO_REAL_MOUSE=1`),
and a virtual display (Xvfb). Any new windowed test must work under all
four. These are passed through `GODOT_FLAGS` in `.github/workflows/tests.yml`.
8. After merging: `git switch master && git pull`.

Git identity: personal account **`poncema4`** only. Pushes go through the
`github-personal` SSH alias.

---

## 11. What never goes in git

`.gitignore` covers these; never force-add them (`git add -f`):

- **Secrets:** `.env` files, keys, tokens, signing certificates, keystores.
- **`export_presets.cfg`:** Godot can store keystore passwords in it in plain text.
- **Steamworks** credentials and SDK/content-builder config.
- **Build output:** `.pck`, `.exe`, `.x86_64`, `.apk` and so on. Builds ship
  through Steam or itch, never git.
- **Caches and local state:** `.godot/`, `qa_output/`, `.cursor/`, `.vscode/`,
  `.claude/settings.local.json`.

If you ever see a secret staged or committed, stop and tell Marco. A secret
pushed to this **public** repo must be treated as leaked and rotated, even
after it's deleted.

---

## 12. Reporting a change

```text
WHAT CHANGED
FILES CHANGED
WHAT WAS TESTED   (real numbers, and which checks were proven to fail)
RESULT
KNOWN ISSUES      (including anything not tested, by name)
NEXT RECOMMENDED STEP
```

---

## 13. Development order

1. Architecture + AGENTS.md ✅
2. Third-person player ✅
3. Third-person camera ✅
4. Small 3D environment ✅ (meadow, nature, lighting)
5. Small village ✅ (flat zone, plaza, 3 cottages, props, dirt paths; grown to 11 cottages in step 9)
6. Basic interaction ✅ (E key, doors, notice board) + the dog character
7. Day/night system ✅ (sun, moon, dusk, lamps, clocks; tests freeze the clock at 10:00)
7a. Character select (pick your animal), outfit swap screen, name tag over the head ✅ (Steam name later: `PlayerProfile.steam_name()`)
7b. Fishing ✅ (the lake; the ocean when the world has one)
8. Sleep system ✅ (beds work 7 PM to 6 AM; you wake at 6:30; the clock is shared, so multiplayer will need sleep voting)
8b. Longer Minecraft-style day (20 minutes, about 10 of night) ✅
9. Bigger world ✅, bigger village ✅ and a realistic lake ✅ (shader water, reeds, lily pads, 12 fishing spots)
10. The shared screen place ✅ (big screen + benches + paste-a-link box; playback comes with multiplayer)
11. Health component (player + mobs) and the HP bar ✅ (`Health` node + HUD bar; nothing damages the player until the zombie)
12. Basic zombie: spawns at night, chases, leaves a sleeping player alone, burns in sunlight, survives in shade ✅ (`scripts/mobs/`; the player is knocked out at 0 hp; Ghoul agent added)
13. Zombie AI
14. Basic combat (weapons)
15. UI/UX polish pass (HUD, prompts, menus) - small passes alongside every step too
16. Building
17. Inventory
18. Animals
19. NPCs
20. Multiplayer foundation (sleep voting, shared clock)
21. Voice chat
22. TV/social systems (the playback for the shared screen)
23. Steam integration

The order can change for a real architectural reason. Never skip testing to
reach later features faster.

**Not now:** advanced zombies, voice chat, full multiplayer, Steam, complex
NPCs, a large world, complex crafting, a big inventory, multiple zombie types.

---

## 14. Lessons learned (append, never delete)

Every mistake, false positive and CI failure gets an entry in 14.1: what
happened, the cause, and the rule that prevents it. Things that worked well go
in 14.2, so agents repeat them. Agents read both before working.

### 14.1 Mistakes and their rules

| # | What happened | Cause | Rule now |
|---|---|---|---|
| 1 | "Wall blocks movement" passed at z=4.37 with **no wall** | One-sided bound (`z < 5.8`) that "never moved far" also satisfies | Two-sided bounds; prove every check fails when its feature is broken (8.3 rules 1 and 3) |
| 2 | The camera turned by itself mid-test; the player walked around the wall | Real mouse movement leaks into a captured-mouse test | Free the mouse right after loading; test look math via `apply_look()`; captured routing only with `HW_NO_REAL_MOUSE=1` (8.3 rule 4) |
| 3 | Look sensitivity was 0.9× at 1280×720 | `InputEventMouseMotion.relative` is scaled by the window's stretch factor | Use `screen_relative` for mouse look; the CI check fails if it's scaled |
| 4 | Scout took ~6.5 minutes and didn't finish the checklist | Open-ended brief, one Godot launch per scenario, setup rebuilt each time | `PlaytestKit`, one script per run, 3-launch / 5-minute budget, specific briefs (9.6) |
| 5 | PR #1's first CI run failed with every check passing | No sound card on the runner: ALSA printed `ERROR: ... ERR_CANT_OPEN`, which the log scan correctly flagged | CI runs Godot with `--audio-driver Dummy`; new windowed tests must run without audio hardware |
| 6 | Marco's editor showed 135 errors; the main scene pointed at a deleted file | A scene was moved while the editor was open: the editor followed it by UID and rewrote `run/main_scene` in `project.godot`; the moved file was then deleted | Don't move or rename scenes while the editor is open (ask Marco to close it, or tell him to reload). After any move, check `git diff project.godot` |
| 7 | 45 `Failed to correctly scale body` errors from Jolt | Rocks had non-uniform scale on the physics body; Jolt can't stretch sphere colliders | Uniform scale on physics bodies only. Squash and stretch the **mesh** child for variety |
| 8 | "Tree stops the player" failed (gap 3.21) though the tree worked | Against a round trunk the player correctly slides around it while W is held, so the **final** position measured nothing | Against round or angled obstacles, track the **closest** distance every frame, with two-sided bounds |
| 9 | Mouse and wheel checks got nothing on the virtual display | `Input.parse_input_event` delivers on the next **idle** frame; with slow software rendering, several physics frames pass inside one idle frame | After injecting input, wait `kit.frames()` (idle frames), never `physics_frames()` |
| 10 | The whole meadow rendered pale mint, washed out | Vertex colours are read as linear unless told otherwise | Any material using `vertex_color_use_as_albedo` also sets `vertex_color_is_srgb = true` |
| 11 | Grass blades rendered as dark spikes | Two-sided (`CULL_DISABLED`) geometry gets its normal flipped on the back face, so the back is unlit; SSAO also darkens dense thin geometry | Foliage: build front and back as separate one-sided triangles with upward normals; keep SSAO moderate (intensity ≈ 1.0) |
| 12 | Grey patches across the meadow | The "pond shore" colour rule (`h < water level`) applied to every dip in the whole map | Scope every feature rule to its feature's area (distance to the pond), not a global threshold |
| 13 | A planted editor-only error passed the game-load check | `@tool` code runs only in the editor | The runner opens the editor headless (`editor load` step) |
| 14 | At the wall, the player's capsule filled a third of the screen. All tests passed; only Hawkeye's screenshot review caught it | The test measured where the camera was, not what the player would see | When a camera can be squeezed, assert on what's visible (here: body transparency), and always review the screenshot. Fixed with a fade, proven by a negative control |
| 15 | "Close-up" screenshots of trees weren't close; the capsule hid the subject | The shots were framed by distance only, and the render check can't tell what the subject is | Subject shots hide the player body and are framed a few metres away. Look at them: automation proves an image rendered, not that it shows the right thing |
| 16 | I briefed Hawkeye that an old run was a pre-fix baseline; it was byte-identical to the new one | I had moved post-fix images into a folder named `first-meadow` and never checked | Verify claims before putting them in a brief (`md5sum` old vs new). Name run folders for what they are; Hawkeye also checks baselines itself |
| 17 | Scout and Sage never reported: the Claude Code session restarted and killed background agents | Background agents don't survive a restart | A missing report is **not** a pass. Re-dispatch lost agents. Before restarting or ending a session, wait for agents or note them as lost |
| 18 | Scout reported 2 "findings" and 2 "inconclusive" items that were not bugs | Its scenarios were wrong: a 0.1 m tolerance ignored that a capsule on a slope sits up to 0.16 m higher; "moved 0.377" was 3D distance including the settling fall; the tree sat off the camera arm line (the arm is offset 0.5 m to the shoulder); "stuck" at (43, 43) was a tree trunk and at the south hill the slope was exactly the 45° limit | **Triage every playtest finding before acting.** Reproduce with a small script and look for the scenario's own mistake. Slope-aware expectations; measure horizontal movement after settling; put obstacles on the arm line. Real behaviours become permanent tests (`test_terrain.gd`, movement test) |
| 19 | Scout's one launch took ~3 minutes | Headless Godot runs in real time (60 physics frames = 1 s) | `--fixed-fps 60` on every headless run: same simulation, 17× faster |
| 20 | Scout sent an "incomplete" report, then a "correction" | It piped Godot through `tail` (no output until the process exits) and reported before the run ended | Write Godot's output to a file, wait for the process to finish, then report. Never report a run that hasn't finished |
| 21 | Sage guessed (60% confidence) that CI's editor-load step wouldn't catch errors on a fresh checkout | Untested suspicion | CI-only behaviour is tested on a clean copy in /tmp (no `.git`, no `.godot`), not guessed. Checked: it does catch a planted error |
| 22 | Two tests couldn't catch a misaligned terrain collision, and the fade test measured a value the camera had just set (Sage) | The spawn is flat, and the fade check read a property instead of the screen | Test at non-flat points with a ray grid and slope-aware player drops; compare real pixels. Proven by negative controls: transposed heightmap → 1.527 m error, fade off → 31.9% of pixels differ |
| 23 | PR #2's first CI run failed: the camera fade did nothing in CI, though it worked and passed locally | CI uses the OpenGL **Compatibility** renderer, which ignores `GeometryInstance3D.transparency`. The property-based check passed everywhere (the property was set); only the pixel comparison (added after Sage called the first check circular) saw the capsule still on screen | Fade with **material alpha**, which every renderer supports. Run the suite in **both** renderers before every PR: `GODOT_FLAGS="--rendering-driver opengl3 --rendering-method gl_compatibility --audio-driver Dummy" tests/run_tests.sh`. Prefer features the Compatibility renderer supports, or assert on pixels |
| 24 | The new movement filmstrips came out black and the runner failed | `Image.blit_rect` needs identical pixel formats; frames are RGB8, I created the sheet as RGBA8. Caught by `check_rendered` and the log scan (the checks working as designed) | Build composite images in the source images' own format (`thumbs[0].get_format()`). New image-producing code gets a negative control, or at least a run, before anything else |
| 25 | Filmstrips weren't comparable: a sheet started with the body still turned from the previous sheet | `teleport()` resets position and velocity, not the Body node's rotation | Every sheet/scenario resets ALL state it depends on (body yaw, camera yaw/pitch, arm length), not just position |
| 26 | The filmstrip `t` labels didn't match the movement (Hawkeye): a walk strip labelled 1 s covered ~1.6 s | `t` was the loop's nominal interval, but capturing a frame costs extra physics frames, so real spacing was larger | Time labels count the frames the game REALLY ran (the harness freezes the game while capturing and counts them itself), never the loop's nominal interval, a wall clock, or `Engine.get_physics_frames()` (it keeps ticking while paused). Manifests carry actual values, reviewers check pos-delta / dt against speed, and the harness self-checks both directions (lessons 32, 33) |
| 27 | The "holding jump gives one hop" check could not fail: it passed with bunny-hopping enabled (Sage proved it with a run) | It asserted only the END state (on the floor after 260 frames); any hopper is back on the ground by then | Assert events over time: count takeoffs (floor to air transitions) and require exactly 1. Negative control: 4 takeoffs when broken |
| 28 | The "walking stops" band had no lower bound, though the spec promised "not abrupt" | A band without both bounds can't catch the failure on the missing side | Every band has both bounds, and each bound must match what the spec says it guards. A promise in AGENTS.md 8.5 with no check enforcing it is a finding |
| 29 | The QA index could hide a crashed step behind an older green run; it compared across renderers; "unchanged" was described as pixel-identical; CI dropped manifests and the index; a broken index was swallowed by `|| true` | Latest run came only from manifests (written at the end of a successful step); no renderer in the manifest; wording overstated; narrow artifact glob | Latest run from `run_meta`; MISSING / WARNING / "problems" sections; same-renderer comparison; honest wording (under 0.2% changed); CI uploads `qa_output/**`; index failure fails the runner |
| 30 | This PR broke its own lessons gate: lessons 24 and 25 were in AGENTS.md but in no agent file (Sage caught it) | I added the lessons last and didn't re-check the gate before dispatching | Run the gate checklist (PR template) BEFORE dispatching Sage. Lessons 24-29 are now in the agent files that should know them |
| 31 | A truncated old screenshot would fail every later run (Sage's 30%-confidence suspicion; confirmed by a 3-minute test) | `Image.load_from_file` on a corrupt PNG prints `ERROR:` lines, and the runner's log scan correctly counts them as a failed step | Check a PNG ends with its `IEND` chunk before loading it; skip incomplete files. **Cheap tests settle UNCONFIRMED findings**: plant the corrupt file, run once |
| 32 | The "jump_arc" filmstrip never contained a jump (Sage, reproduced 3 times); nothing flagged it | `kit.tap` held a key for ONE physics frame, but `physics_frame` fires BEFORE nodes process that frame, so the press was released before the player saw `just_pressed`. It only showed in the real-time windowed run | `tap` holds 2 frames. A strip/sheet/scenario must assert it contains the thing it claims to show (here: max y > 1.0 and a sample airborne). Negative control: tap of 1 frame fails with "max y 0.00" |
| 33 | `t` was still one frame per interval too high, and the self-check could not see it (Sage measured it) | After the last `await physics_frame` the game is frozen before that frame runs, so N awaits ran N-1 frames; the check only bounded speed from ABOVE, and an overstated `t` only lowers implied speed | Await `every + 1` frames and count `every`. A consistency check needs BOTH directions: where speed is steady, distance/dt must match the reported speed within 5% (steady = same speed and heading; `t` stored to 0.1 ms; controls: 1.5x clock -> 34% mismatch, old off-by-one -> 11.8%) |
| 34 | A corrupt OLD manifest failed every later rendered step (found by testing the runner's failure path) | The kit read the previous manifest with `JSON.parse_string`, which PRINTS an `ERROR:` line; the log scan counts that as a failure. Same class as lesson 31 (corrupt old PNG) | Code that reads old artefacts uses parsers that return errors instead of printing them (`JSON.new().parse()`), and tolerates corrupt, partial and legacy files. Test the failure path itself, not only the happy path |
| 35 | The overview screenshot failed `check_rendered` (contrast 0.030 against a limit of 0.03) after the village paths appeared, though the picture was fine | The old overview was flat meadow, always borderline (a Python recompute of every old run showed it sat just above the line); any change could tip it | Don't lower a threshold that exists to catch flat renders. Reframe the shot to something that carries real variety (the overview now looks at the village). When a borderline check flips, recompute the same statistic on the old images to see whether it was ever safe |
| 36 | All 4 "path segment" checks failed though the path was walkable (the player ended 3-5 m PAST each end point) | The test held forward for a fixed time, so it overshot; a trace of positions showed 4.00 m/s all the way | Walk in short bursts until within range, with a frame cap (a blockage shows up as running out of frames, which the negative control proved: a fence wall across the path fails segment 1 after 174 of 172 frames). Trace positions before touching the world. All 6 village controls fail as intended: door 0.5 m (4 fails), no house collision (6), flat zone 6 m (4), props without collision (1 fail, plus Jolt leak errors the log scan also counts), nature ignoring the village (1), fence wall on the path (2) |
| 37 | The "no sand away from the pond" check flagged village cobble and path dirt as sand | Both are pale warm colours, nearer SAND than GRASS in colour distance | State exclusions by name and keep them narrow: the village zone and 2 m either side of a path (`test_terrain.gd`). Anything else sandy still fails |
| 38 | The first "doorway" screenshot showed the player in the door from OUTSIDE, not the room (my own review before dispatch caught it) | The camera sits behind the player, so a player in the doorway is seen from outside | For an interior shot put the player INSIDE and the camera 1-3 m outside the door (`house1_interior`). Look at every new shot before dispatching Hawkeye: a wrong framing wastes a ~100k-token round |
| 39 | Sage proved by mutation that three advertised checks could not fail: an INVERTED roof passed (the roof check only said `y > wall height`), one wall losing its collider passed (only the left wall was ever walked at; my "no collision" control removed ALL collision at once), and moving a house without its dirt link passed (nothing tied them) | My controls broke whole features, so they only proved the check could fail in the case I imagined; bounds were one-sided; a doc claimed "the test checks it" with no test | Controls must be as fine-grained as the thing that can regress: one wall, one prop kind, one house. Geometry gets two-sided bounds AND a shape check (ridge higher than both sides by 0.6 m). Every cross-file coupling (house position, door link) gets its own assertion. Never write "the test checks it" without naming the check. 12 controls now: door 0.5 m, door height 1.5 m, all collision off, back wall alone, right wall alone, inverted roof, flat zone 6 m, props without collision, nature ignoring the village, fence wall on the path, house moved without its link, two lamps missing. All fail as intended |
| 40 | Hawkeye found a z-fighting door jamb (trim inner face on the same plane as the wall end face; stripes in the Compatibility renderer), a V notch at the roof ridge, and Sage found a roof floating 0.18 m above the walls and a left window whose glass faced INTO the house | Coplanar faces; slabs meeting at their centre lines; the roof slope was measured from the eave tip instead of the wall top; the window normal used one yaw for both sides | Visual-only trim never shares a plane with another face: inset 2 cm. Compute slopes from the line through the support point (wall top), not the overhang tip. Mirrored parts (left/right) are built from the sign, then BOTH sides are looked at. Static frames only hint at z-fighting: compare the Compatibility renderer, where it is worse |
| 41 | The player said sprint "randomly stops" and Space needed tapping. A trace over 8 headings found most stops were real solids, but two things were genuinely jerky: slopes near the 45 degree limit stopped the character dead, and a 7 m/s run over bumps left the ground for a frame (so a jump pressed then was eaten) | Plain `move_and_slide` defaults (no floor snap, speed lost on slopes), a jump only on the exact on-floor frame, and `is_action_just_pressed` for jump | Floor snap 0.5 m, constant speed on slopes, 0.12 s coyote time, jump read with `is_action_pressed` (held Space repeats on every landing; never faster than the airtime, no double jump). Held-sprint continuity is tested over 4 s with and without jumping. `wall_min_slide_angle` was added by guess, had no effect (its control could not fail) and was removed: do not add a setting without a control that proves it matters |
| 42 | The jump pose kicked the legs BACKWARD and folded the arms ACROSS the body, and my first test (`leg_angles().x < -0.3`) enshrined the bug as correct | A hanging limb swings FORWARD with a POSITIVE rotation.x, and an arm on the +X side goes OUTWARD with a POSITIVE rotation.z; I had both signs reversed, and an angle test agrees with whatever sign the code uses | Animation is tested by GEOMETRY: where the feet and hands are, in model space (feet ahead of the hips and arms out in the air, the arm opposite the forward foot forward, planted foot barely sliding, no joint change over 0.35 rad or limb move over 0.2 m per frame). The conventions are written at the top of `animal_model.gd`. Look at a front view for arms (a side view hides them). 13 controls prove it |
| 43 | The walk filmstrip showed eight nearly identical thumbnails | The animation ran in `_process`; under a slow renderer several physics frames pass per rendered frame, so the animation froze or ran at the wrong speed while the movement (and the filmstrip clock) ran on the physics tick. It would also make animation speed depend on the player's frame rate | Gameplay-driven animation runs in `_physics_process`, in lockstep with the movement it shows; `test_animation.gd` asserts `is_physics_processing()`. When a filmstrip looks frozen, check the tick it runs on before blaming the pose |
| 44 | Reviews were expensive and repetitive: Sage spent most of its ~120k tokens finding drift a script can find (a test missing from the README, a stale "11 steps", a lesson cited but not written), Warden re-ran what the lead had just run, and "random stops" reached the player because only a human had ever played a full route | Hygiene and route-walking were left to paid agents | `tests/tools/check_repo.py` is the runner's first step (8 controls prove it, one caught a bug in itself: a substring match that could never fail); `test_soak.gd` is a bot that plays a route with held keys and fails on any stall (2 controls); `review_pack.py` briefs agents with only the diff, the changed images and the agents needed; Warden is skipped when the lead's own both-renderer run is green. Sage is told never to report what the repo check covers |
| 45 | Sage proved by mutation that the coyote-time check passed with coyote shortened to one frame (floor snap pulled the lifted player back down and faked the pass), that the cone, range, close-box and board position checks only tested the dead-centre case, that fade-on-equip was only tested in one order, and that a deferred collision write could leave a snapped door walk-through. Animator found a sprint-reversal moonwalk. Hawkeye found a 2 px gap beside the door leaf | Controls broke one thing at a time but my CHECKS still only visited the happy case; a second setting (floor snap) masked the first; a signed quantity was tested by magnitude | For every rule with a number (range, angle, window, box size) test BOTH sides of its edge, with probe points tight against the REAL edge (measure where it is first: night really starts near 5:45 PM, so probes at 5 PM and 7 PM let a threshold of 0.1 or 0.9 pass); when two settings overlap, defeat the other in the test (lift the player above the snap length); test order-dependent features in both orders; test signed quantities with their sign. 12 more controls prove it. Sage's fixes cost the same round as the finding: expect the second tier of weakness after the first |
| 46 | A parse error in one script made a Godot run hang for 6 minutes and orphaned a process; a regex rename in the soak test rewrote words inside strings ("never kit.fell through"); a lamp light reused a variable name (`glow`) and broke every test that loaded the village; a signal test counted an event its own setup fired | No per-step timeout; a mechanical text rewrite without reading the diff; no unique-name check before pasting code; counters connected before the state was settled | Every runner step has a timeout (a hang = a failed step). Review the diff after any scripted rename. Run a quick `godot --headless --import` (it prints parse errors) right after editing a script. Settle state BEFORE connecting counters in a signal test. Kill stray Godots by PID, never `pkill -f` with a pattern that matches your own shell |
| 47 | The first fishing screenshots showed no bobber, line or ! although the tests proved they existed and were `visible`; the first character screen had a Start button below the bottom of the window | `visible` is not "can be seen": the bobber was 13 cm across, 7 m from the camera and behind the character; the panel was taller than 720 px and no headless test has a window | Anything the player must SEE gets an on-screen check in the windowed playtest: project its position with `unproject_position` (inside the viewport, in front of the camera) and make it big enough; a panel's rect must be enclosed by the window rect. Then LOOK at the image. Bobber 0.24 m, line 2.8 cm, "!" 0.8 m up |
| 48 | A method named `set_name` silently clashed with `Node.set_name` and failed to parse; a cast distance guessed at 5 m would have landed on dry ground (the pond's "radius 8" is the bowl the hills flatten into, the visible waterline is 4.2 m) | Guessing a number the world answers; reusing a name from the engine's API | Probe the real world before placing things (a 20-line script that prints waterline, tree clearance and slope per angle placed 4 spots correctly the first time). Do not name methods like `Node`'s (`set_name`, `get_name`, `free`); `enter_name` instead |
| 49 | Reviewers found bugs that only appear when something CHANGES while in a state: changing animal mid-cast rebuilt the model and orphaned the fishing rod (an engine error, then arms out holding nothing); the tail whipped whenever the walk blend changed (the wag frequency was blended inside `sin(time * freq)`, so the phase jumped, worse as the game ran longer); a rod made while the body was faded stayed opaque; a profile with a `null` in it crashed the loader and silently reset the player; a fishing test on seeds 1-10 never saw a short wait because consecutive seeds give similar first rolls | Every test started from a clean state and moved forward; nothing rebuilt, faded, interrupted or corrupted a thing already in progress | Test TRANSITIONS: rebuild/switch/fade/cancel while in each state (cast, fishing pose, faded, outfit worn), and damage every field of saved data with null, a list and text. Accumulate phases, never multiply time by a changing frequency. Use widely spread seeds (`i * 7919 + 13`). Measure timers over many samples and assert both ends of the range |
| 50 | The sleep test failed twice on its first run, both my mistakes: a lying-pose height limit I guessed (1.0 m) before measuring, and an expected phase list that forgot the final AWAKE | The AABB of a whole model included a tail that hides inside the mattress, so the number meant nothing; I picked the threshold from a feeling | Print the real numbers first (a probe), then write the limit from what matters (height above the feet; nothing below the floor as a separate check). A failing first run is a prompt to look, not to loosen |
| 51 | A negative control escaped: pausing the world clock during sleep changed nothing visible, because the system overwrote the hour every frame anyway. A screenshot meant to show a half-faded screen also came out fully faded, because I waited a fixed number of frames | Behaviour that is a contract but not an outcome is invisible to outcome checks; frame counts in a script drift from game time | Assert the contract directly (the clock is paused while asleep) and make the test start from the state a real player has (a RUNNING clock; the kit pauses it, which made the check unfalsifiable). Mutate by DELETING lines as well as flipping values, and sample from BEFORE the action (a teleport in the first frames escaped). Time a screenshot by polling the state it must show (overlay alpha 0.3 to 0.7), and check that state in the test |
| 52 | Running both renderers at the same time made the creator test fail in one of them ("no saved profile" expected, one existed) | Every test process used the same fixed temp file under `user://`, so one run's save was the other's "existing profile"; it passed alone | Anything a test writes to a shared place (user://, /tmp, a port) gets a per-process name (`OS.get_process_id()`) and is removed in `finish()`. If a failure vanishes when run alone, suspect shared state first |
| 53 | Doubling the world broke two OLD tests that hard-coded the wall position (x = 58); my targeted terrain tests passed and only the full suite found them | A literal that mirrors another file's number is a hidden dependency; I ran only the tests I expected to be affected | Derive such numbers from the source of truth (`terrain.half_size() - 2`), and run the FULL suite before declaring a world-scale change done. The new render-budget check in the visual tour guards the other side of growing the world (cost per frame) |
| 54 | Adding a ring of rotated cottages exposed three old assumptions at once: (1) the player's acceleration was per axis, so a diagonal heading CURVED while speeding up (8 degrees off) and the player slid sideways along any wall that was not axis-aligned, through an open door in one case; (2) the near-head-on wall slide had only worked BECAUSE of that curve (Godot sticks within 15 degrees of a wall normal, `wall_min_slide_angle`; lesson 41 said the setting had no effect, but its control was run under the code that hid it); (3) the sprint test assumed the lane south of the spawn was empty, and a cottage now stood in it | Every earlier house was axis-aligned (yaw 0, 90, -90), so no test ever walked a diagonal; fixed numbers (a heading, a wall x) quietly encode the old layout | Accelerate as a vector; set `wall_min_slide_angle = 0` explicitly and keep the village slide test as its control; tests find their open lane at runtime and fail loudly if none exists; the day/night test counts the village's real lamps (it said "4"); the doc facts about the world are now checked against the code by `check_repo.py`; the render budget was raised on purpose (INTENTIONAL.md). Layout tests must include rotated, non-axis-aligned buildings. My own new heading check first read the SIGNED angle and could not fail: its control against the old code caught that, so every new check still needs its control (lessons 1, 27) |
| 55 | While building the lake: (1) the first spot plan used radii measured for the old pond and would have put anglers in the water; (2) the decoration test read MultiMesh positions back and got zeros in headless mode (every check failed or passed for the wrong reason); (3) the test used the decoration's own clearance constants, so a mutation of the constant moved the limit with it; (4) a "dry" bank only 0.3 m high left half the shore with no valid spot; (5) one control escaped because two guards protected the same thing | Numbers measured for one object were reused for another; the dummy renderer does not store MultiMesh data; a test that imports the code's constant cannot catch the constant being wrong | Measure from the real terrain at runtime (`waterline_at`, `plan_spot`); keep your own copy of positions as the source of truth; tests use independent literals for limits; run the geometry through a probe before choosing thresholds; when two guards cover one property, prove the check with a mutation that defeats both; a visual defect a reviewer finds (Hawkeye: the dusk water looked like lava) becomes a measured check in the playtest (orange-tinted pixel fraction, proven against the old shader) so it cannot return silently |
| 56 | The shared screen passed every test while its text ran off both edges of the screen (found only by LOOKING at the screenshot), and the first "fits" check measured a stale label (identical sizes for two different texts); the first interact point sat behind a player standing in front of the screen; the window-fit and mouse checks cannot run headless (the window is 64 x 64, mouse mode is not applied) | A `Label3D` rebuilds its mesh on the next frame; tests ran headless where UI facts do not exist; I picked one stand point | Measure what you draw (the label's bounds against the face, in both states, requiring the two measurements to differ), test an interaction from several stand points, and keep window/mouse checks in the rendered playtest |
| 57 | While adding bench seating: (1) the E that stood the player up was ALSO read by the Interactor in the same physics frame and sat them straight back down (an input event is visible to every node in its frame); (2) the first stand-up check compared the player with the seat's own `stand_point()`, so moving that point behind the bench still passed (lesson 55 again); (3) the screen test's last stand point became a bench seat's territory once benches could be used | Command handoffs between two nodes need a rule about which frame owns a key press; a test that imports the code's constant cannot catch the constant being wrong; adding an interactable changes what "nearest" means for old tests | A frame stamp on every seat change (`_seat_frame`) makes the press that changed state invisible to the other handler, and only a FRESH press stands up (a held key does not); stand-up position is asserted against the bench's own front, not the seat's constant; stand points in older tests were moved to stay clear of new interactables Review then found a held Space hopping off the bench (blocked until released), thighs sunk 12 cm into the seat (hips ride 12 cm higher), a tail poking through the backrest (laid sideways), a rod in a sitter's hand, and a stand-up pose blending out in mid-air (snapped); a rod check that looked for mesh names that do not exist could not fail (an escaped control caught it: ask the model with `rod_visible()`); and the terrain test's "hill ring" drop point, a literal from the 120 m world, ended up under a cottage roof (now derived from the terrain) |
| 58 | While building the HP bar: (1) a throwaway screenshot script called `kit.shot(...)` WITHOUT `await`, so the shots raced the damage calls and the image named "full" showed 35 hp (caught by looking at the PNGs, not by a check); (2) every movement test pressed named actions (`Input.action_press`), so nothing proved that the W/A/S/D/Space/Shift KEYS are bound; Marco asked whether they still work and no test could say | (1) `shot` is a coroutine: without `await` it returns before the frame is captured; (2) an action press skips the Input Map, which is exactly where a rebound or deleted key lives | (1) Always `await kit.shot(...)`, and read the first PNG against its name before trusting a set; use the permanent playtest (what/expect text, pixel checks), never a throwaway. (2) `test_keys.gd` injects real `InputEventKey`s and measures the result; any change to `project.godot` input or `player_controller.gd` input reading runs it. New features must not break WASD / Space / Shift |
| 59 | Sage's step 11 review (FIX FIRST, 4 Low): (1) the step count was bumped in `warden.md` but its step NAME list and report template still named the old steps (`check_repo.py` compared only the number); (2) `Health` repaired a maximum below 1 but not NaN (`maxf(NaN, 1.0)` is NaN); (3) `max_health` changed after `_ready` left `current` above it and the HP bar stale (no setter, no signal); (4) the "nearly dead" playtest asserted only absences, so a bar drawn empty at 1 hp passed; Hawkeye also noted no frame showed the text straddling red and dark | (1) a count is not a list; (2) a clamp is not a finite-check; (3) a plain `@export` has no change hook; (4) absence checks cannot prove presence | (1) `check_repo.py` now fails if any runner step is missing from `warden.md`; (2) non-finite maximum repaired to 100, `set_max()` is the only way to change it after `_ready`; (3) `set_max()` clamps `current` and emits `changed`, tested incl. the HUD; (4) positive sliver pixel check (mutation: bar empty at 1 hp now fails) and a 50% shot added (its first version sampled a pixel under the centred text and failed: sample points must avoid the text, roughly the middle third); Sage's, Hawkeye's and Scout's agent files carry the new checks (Scout: three of its own FAILs were thresholds that ignored walk speed and the acceleration ramp) |
| 60 | Step 11 round 2: Hawkeye took 37 s and Scout 92 s, but Sage's DELTA re-review ran 928 s (17 tool calls, 87k tokens) and had to be told to stop. The lead's brief asked it to re-verify four fixes AND run a rendered playtest, several mutations, two old controls and a doc audit | A re-review brief was written like a first review: no evidence handed over, no per-finding command, a 15-minute budget | Delta re-review rule (9.6): list each finding with ONE command that verifies it, hand over the lead's own evidence (mutation outputs, test lines) instead of asking for them again, no rendered run unless the finding is visual, budget 5 minutes, and say 'stop at the budget and report what you have'. Mutations go through ONE call of `tests/tools/mutate.py` (JSON list, byte-exact restore, CAUGHT/MISSED/BAD), never hand-run one by one; `sage.md` now caps a first review at 10 tool calls and a delta at 8. Measured times to expect: Hawkeye 40 s, Scout 90 s, Sage first review 90 s, Sage delta under 5 minutes |
| 61 | Building the zombie (step 12): (1) a stationary zombie (`walk_speed` 0) made the leg swing 0/0 = NaN and the engine printed hundreds of `ERROR: Condition "!v.is_finite()"` lines, found only in the RENDERED playtest because no headless test used one; (2) the playtest's "not hidden" check excluded the player, so a zombie behind the dog's head passed (found by LOOKING at the picture); (3) the first night zombie was dark blue on dark green, nearly invisible; (4) negative controls found three gaps in my own test: a leftover spawner countdown (15 s from an earlier night) hid a missing day gate, the sunrise elevation rule was unobservable because I never tested 6:06 AM, and a crashed coroutine (`spawned[0]` on an empty list) hung instead of failing; (5) a lambda counted `died` into a local int that stayed 0; (6) giving the player a knock-out handler broke the older `test_health` (it expected a dead player), caught only because I ran ALL headless tests after touching shared code | (1) division by a tunable that can be 0; (2) an occluder list that leaves out the biggest occluder; (3) colours picked without a dark-scene look; (4) a test that never sets the state it relies on; (5) GDScript lambdas copy captured primitives; (6) a changed premise in shared code | (1) `leg_swing()` divides by `maxf(walk_speed, 0.01)` and has a test; every tunable divisor is guarded, and a stationary variant is tested; (2) occlusion checks count the player; every new picture is looked at before any agent; (3) mob colours are checked in the night shot, eyes glow; (4) set every piece of state a check depends on (`spawner._timer = 0`), test the threshold edge (6:06 AM), never index a list that may be empty (a crashed coroutine hangs until the step timeout); (5) count in lambdas through a member variable; (6) after touching shared code run every headless test, not only the new one |
| 62 | Step 12 review round (Ghoul, Sage, Hawkeye, Scout): (1) a zombie could hit a player THROUGH a cottage wall (the attack checked only distance), found by Ghoul's probe, not by my tests, and it defeated the point of cottages; (2) about 1% of spawn points were inside a tree or rock; (3) Sage proved with one `mutate.py` call that 6 of 7 mutations survived my zombie test: the melee interval was only bounded loosely (2 or 3 hits in 3 s), the spawn margins were compared against the spawner's OWN settings (circular), the repeating spawn interval and both sides of the detect range and the height gate were never pinned; (4) my header and docs said trees shade, but only trunks have colliders (Ghoul measured it); (5) night readability and pale eyes (Hawkeye) | (1) attacks were written like a radius check; (2) the picker knew water, village and walls but not objects; (3) tests read their expected values from the object under test, and a timer has two code paths (the first interval after night starts, then the repeating one); (4) docs written from intent, not from the colliders; (5) colours chosen in daylight | (1) every attack and every sight line needs a clear-line ray (`has_line_of_sight`), tested through a real wall with a control; (2) spawn points are checked with a shape query, tested with an independent capsule and a solid block across the ring; (3) tests compare against LITERALS (6 m), pin each tunable from both sides (24 m comes, 33 m does not; 1.3 m hits, 2.0 m does not; 1.2 s apart in frames; the delta round still found one forgotten tunable, `attack_range`: list EVERY @export of the class and give each its own pair), and pin each code path of a timer separately; (4) docs name the geometry that really blocks a ray; (5) mob colours are judged in the night shot, with a measured luminance lead over the ground and red eyes read from the pixels. Scout/Sage/Ghoul agent files carry all of it |

### 14.2 What worked (keep doing)

| What | Why it works |
|---|---|
| **Negative controls on every new check** (disable the collision, remove the wall, plant a typo, feed a black image) | Caught 3 checks that couldn't fail; proves each check guards something |
| **Printing measured values** on every PASS/FAIL line | Debugging the tree check took one run, because the numbers showed the slide |
| **A debug run with per-step positions** before changing a failing test | Showed the feature was right and the test was wrong (lesson 8), instead of "fixing" working code |
| **One shared `PlaytestKit`, many scenarios in one launch** | Scenario runs went from minutes to about 3 seconds |
| **Virtual display (Xvfb) for rendered tests** | No pop-ups, no real-mouse interference, and the captured-mouse check runs locally too |
| **Looking at screenshots before calling a visual change done** | Found the washed-out colours, grey patches and dark grass: all three passed every automated check |
| **Fixing CI on the same PR** and recording the lesson in the same PR | History stays readable; the next agent inherits the fix |
| **Hawkeye reviewing every screenshot, in parallel with Warden** | Found the framing and lighting issues no automated check could (lessons 14, 15); ~90 seconds |
| **Agents that check the lead's claims** (Hawkeye ran `md5sum` on the "baseline") | Caught a wrong claim in my own brief (lesson 16) |
| **Fixing every finding, or recording it as a known issue** | Nothing from a review is silently dropped |
| **Triage, then test**: Scout's false alarms each became a permanent test | The scenario mistakes turned into checks that can't be repeated (lesson 18) |
| **A ray grid against the physics world** | One check proves the collision matches the mesh at 120 points, with no sliding or settling to confuse it |
| **Comparing real pixels** (frame vs the same frame with the body hidden) | Tests what the player sees, not an internal value (lesson 22). It also caught the Compatibility-renderer bug that every property check missed (lesson 23) |
| **Reproducing a CI failure locally with CI's own flags** | Found the cause in one run, before changing anything |
| **`docs/INTENTIONAL.md` read first by every agent** | Turns "is this a bug?" into a lookup with numbers; Hawkeye dismissed every intentional quirk correctly in calibration |
| **Manifest + INDEX with changed-vs-previous** | Reviewers open only new/changed images; unchanged ones cost zero tokens |
| **Calibrating agents with planted defects** (section 9.8) | Measures recall and false positives instead of hoping: Hawkeye 4/4, 0 false alarms |
| **A one-page `tests/README.md` map and no loose files** | Humans and agents find things without listing folders, which saves tokens |
| **Numbers beside the pictures** (manifest samples) | Hawkeye caught a wrong time axis the images alone could never show (lesson 26) |
| **Asking an agent for protocol feedback on its first use of a new format** | Hawkeye's 9 suggestions made the filmstrip format clearer for every future review |
| **A reviewer proving a suspicion with a run** (Sage broke the feature in a /tmp copy and watched the check pass) | A proven finding can't be argued away, and it found the one check that couldn't fail |
| **Pausing the game while capturing frames** | Filmstrips become deterministic: the same thumbnails and `t` on every machine, so "changed vs previous" is meaningful |
| **Clean-copy CI checks** (copy to /tmp without `.git`/`.godot`) | Settles "will CI do X?" in 30 seconds |
| **Scripted negative controls with a byte-exact restore** (copy the file aside, patch it, run, copy it back, assert the content is identical) | Six controls ran in one command and could not leave a break behind; no stash, reset or checkout needed |
| **Tracing positions per step before touching the world** (lesson 36) | The path was fine and the test was wrong; found in one 10-second run |
| **Reading the screenshots myself before dispatching Hawkeye** | Caught a wrong framing (lesson 38) and an odd olive strip (lintel underside lit by the sky's green ground colour) that is now in INTENTIONAL.md |
| **Geometry tests for animation** (positions of feet and hands, per-frame deltas) plus a FRONT view for arms | Caught the backward knees, crossed arms, a skating stride, a 0.68 rad snap and the foot-lift gap in one session (lesson 42) |
| **Tracing before fixing** ("sprint randomly stops": an 8-direction probe) | Separated real obstacles from the two genuinely jerky causes instead of changing speeds blindly (lesson 41) |
| **Looking at enlarged crops of every thumbnail** | Thumbnails are 320 px; crops at 4x showed the frozen strip (lesson 43) and the arm directions |
| **A script for every repeatable review finding** (`check_repo.py`) | Drift found once is found forever for free; it even found a stale "17" in its own PR |
| **A bot that plays a route with held keys** (`test_soak.gd`, 1.7 s) | Catches "it randomly stops" and dead doors with no agent and no human |
| **A generated review pack** | Agents start with the diff and the changed images instead of exploring |
| **Contact sheets and whole-day filmstrips as the first look** | One image of six times of day or a 24-hour cycle shows lighting problems and smoothness at a glance, before any agent is paid |
| **Probe scripts that print the real world's numbers** (waterline, clearance, slope per angle) before placing anything | Four fishing spots worked first time and the cast distance was measured, not guessed (lesson 48) |
| **Looking at every new screenshot before dispatching agents** | Found the back-view preview, the clipped name tag, the cut-off Start button and the invisible bobber in two renders, for free |
| **Injecting real key events** (`InputEventKey` through `Input.parse_input_event`) and measuring the walk, sprint and jump | Proves the keys, the Input Map and the controller together; a rebound W or a swapped A/D fails at once (6 controls, lesson 58) |
| **A reviewer's FIX FIRST turned into a tool change** (step 11: `check_repo.py` now checks step names, not only the count) | The same mistake is caught for free forever, instead of waiting for the next Sage round (lesson 59) |
| **Running every headless test after touching shared code** (DayNight, player, world scene, kit; 19 tests, about 2 minutes) | Caught the old `test_health` whose premise (a dead player stays dead) the new knock-out changed, before CI did (lesson 61) |
| **A reviewer's probe in the weak spot of the design** (Ghoul put a zombie against a cottage wall) | Found the one gameplay bug five test sections and 14 controls had missed; ask specialists to probe interactions between systems, not to re-check what the test proves (lesson 62) |
| **A critical read of the contact sheet BEFORE trusting green checks** | Found the nearly invisible night zombie and the zombie hidden behind the dog, which every pixel check had passed (lesson 61) |
| **`tests/tools/mutate.py`: all negative controls in one call** (JSON list, CAUGHT / MISSED / BAD, byte-exact restore, 3 outcomes proven on itself in 2 s) | Turned 6 to 17 hand-run tool calls per round into 1, for the lead and for Sage (lesson 60) |
