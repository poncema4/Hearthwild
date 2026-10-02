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
| Day lighting (sun, sky, fog, SSAO, glow) | Done | `scenes/world/world.tscn` (WorldEnvironment, Sun) |
| Boundary walls + fall-out respawn | Done | `world.tscn` (Boundary), `player_controller.gd` |
| Third-person player (walk, sprint, jump, gravity) | Done | `scenes/player/player.tscn`, `scripts/player/player_controller.gd` |
| Third-person camera (orbit, pitch clamp, zoom, wall collision, player fades when the camera is squeezed in) | Done | `scripts/player/third_person_camera.gd` |
| Visual tour (15 screenshots; with the camera playtest, 20 per run; each auto-checked) | Done | `tests/playtest_visual_tour.gd` |
| Terrain tests (collision alignment, placement, sand, determinism) | Done | `tests/test_terrain.gd` |
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
| Size | 120 × 120 m, centred on the origin (`Terrain.size`) |
| Spawn | (0, 1, 0), camera facing −Z; flat clearing within ~4.5 m, gentle within 9 m; no trees/rocks within 11 m |
| Pond | centre (16, −12), radius 8, water surface y = −0.6 |
| Hill ring | starts rising at 65% of the way to the edge, 14 m high at the edge |
| Boundary walls | inner faces at x = ±58 and z = ±58 (`Boundary` node) |
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
scenes/world/<part>/      pieces the world uses (nature/: trees, rocks ...)
scenes/<area>/      .tscn scenes: player, zombies, npcs, buildings, ui ...
scripts/<area>/     .gd scripts, mirroring scenes/<area>/
assets/<kind>/      models, textures, materials, audio, fonts (real assets only)
systems/<name>/     cross-cutting systems: day_night, saving, networking ...
tests/              automated tests, the runner, and tests/support/ helpers
docs/               design documents (docs/VISION.md: the game's north star)
qa_output/          screenshots: <topic>/<run stamp>/NN_name.png (gitignored, never deleted)
.claude/agents/     AI agent definitions (section 9)
.github/workflows/  CI
```

- Files and folders: `snake_case` — `player_controller.gd`, `day_night_manager.gd`.
- Nodes: `PascalCase` — `CameraRig`, `SpringArm3D`, `TestWall`.
- `class_name` in `PascalCase` for any script other code refers to by type.
- Tests: `test_<thing>.gd` for headless checks, `playtest_<thing>.gd` for
  windowed checks that need rendering or screenshots.
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
4. **player movement test:** `tests/test_player_movement.gd`, headless.
5. **terrain test:** `tests/test_terrain.gd`, headless. A ray grid proves the
   collision matches the visible ground (120 points, worst error 0.000 m);
   players dropped on hills, the rim and the pond bed rest where predicted
   (slope-aware); trees and rocks sit on the ground; no sand away from the pond.
6. **camera playtest:** `tests/playtest_camera.gd`, rendered, screenshots in
   `qa_output/camera/<run stamp>/`.
7. **visual tour:** `tests/playtest_visual_tour.gd`, rendered; 15 screenshots
   into `qa_output/{environment,nature,player}/<run stamp>/`, each checked by
   `kit.check_rendered()` (fails on black, blown-out or flat single-colour images).

**Speed: headless runs use `--fixed-fps 60`.** Without it Godot runs in real
time (60 physics frames = 1 real second), so a long scenario takes minutes.
`--fixed-fps 60` keeps the identical 60 steps per game second but removes the
real-time wait: the movement test goes from 13.7 s to 0.8 s with the same results.

**No pop-up windows.** When Xvfb is installed, rendered steps run on an
invisible virtual display with `HW_NO_REAL_MOUSE=1`, so a real mouse can't
interfere and every check runs. `HW_SHOW_WINDOW=1` shows the window instead.
Without Xvfb, rendered steps open a real window and the captured-mouse check
prints `SKIPPED`.

**Screenshots are never deleted.** Each run writes to a new stamped folder
under each topic, so agents can compare against earlier runs.

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

---

## 9. The agent team

Work is done by one **lead** (the main Claude Code session) plus four
specialist agents in `.claude/agents/`:

| Agent | Role | Model | One line |
|---|---|---|---|
| **Warden** | Test runner | Haiku | Runs the full suite, reports every PASS/FAIL with numbers. Nothing merges without its pass. |
| **Scout** | Playtester | Sonnet | Plays the game trying to break it, in one fast headless run. |
| **Hawkeye** | Visual QA | Sonnet | Opens real screenshots and reports anything that looks wrong. |
| **Sage** | Code reviewer | Sonnet | Reviews the diff before merge: bugs, rule breaks, weak tests, missing docs. |

Names are short; each agent file's `description` line says exactly what it does. Start lean: specialists are added only
when a system is big enough to own (multiplayer, zombie AI, ...).

### 9.1 Lead (main session)

- Plans the change, keeps it small, writes the code, writes the tests.
- Proves new checks can fail (8.3 rule 1).
- Dispatches the specialists after the change is built; the four can run in
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

### 9.4 Hawkeye: visual QA (`hawkeye`)

- **Job:** **look at the images**. Use the run's screenshots in
  `qa_output/<topic>/<run stamp>/` (the lead gives the stamp), compare with
  the previous run's folder when useful, and render more only if needed.
- **Model:** Sonnet (needs to read images).
- **Checks:** clipping, floating or sunken objects, missing or pink textures,
  bad lighting or shadows, camera inside geometry, character not visible,
  UI overlap, anything that looks broken or ugly.
- **Report format, one per problem:**

  ```text
  SCREENSHOT QA
  Image: qa_output/camera/2026-10-01_18-55-58/05_against_wall.png
  Problem: Camera clips through house wall.
  Severity: Low / Medium / High
  Location: Player camera / house scene
  Suggested fix: ...
  ```

- **Must not:** describe an image it didn't open; edit project files; report
  "looks fine" without listing which images it inspected and what each shows.

### 9.5 Sage: code reviewer (`sage`)

- **Job:** review the branch's full diff (committed, uncommitted and
  untracked) before merge, against AGENTS.md sections 7, 8.3 and 14.
- **Model:** Sonnet. **Budget:** about 10 minutes, no Godot launches needed.
- **Must report:** each finding with severity, `file:line`, quoted evidence and
  a concrete failure; a `REVIEWED` / `NOT REVIEWED` list; a verdict.
- **Must not:** edit files; report style preferences as bugs; make vague
  findings without evidence.

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

- **With Xvfb, all four run in parallel**: each rendered run gets its own
  invisible display (`xvfb-run -a`), so they can't steer each other. Give
  Hawkeye the screenshots from the lead's own suite run, so it doesn't have to
  wait for Warden. **Without Xvfb**, only one windowed Godot at a time
  (real windows grab the mouse).
- Pick the cheapest model that can do the job: Haiku for mechanical runs,
  Sonnet for judgement and images. The lead's model is never used for routine runs.
- Small changes (docs, a constant tweak) need only Warden and Sage.

### 9.7 Agents to add as the game grows

Add a specialist **when its system exists and is big enough to own**, never
before. Each new agent gets a short name and a file in `.claude/agents/<name>.md`
written to the same standard: a `description` that starts with its role,
job, model, budget, exact report format, must-nots.

| Agent | Add when | Owns |
|---|---|---|
| **Mason** (`mason`), world builder | Small village (step 5), when there are buildings to place | Terrain, buildings, lighting, scene organisation |
| **Ghoul** (`ghoul`), zombie AI | Basic zombie (step 9) | Spawning, navigation, detection, day/night behaviour |
| **Pulse** (`pulse`), performance tester | Village + zombies exist | Frame time, draw calls, measured numbers per scene |
| **Relay** (`relay`), multiplayer | Multiplayer foundation (step 16) | Networking, sync, authority; tests with 2+ real instances |
| **Atlas** (`atlas`), researcher | Any time a technical choice is unclear | Godot APIs, plugins, licensing. Recommends; never edits |

---

## 10. Git and PR workflow (every change)

Branch protection doesn't require PRs on this repo, but **every change goes
through a PR anyway.** No direct pushes to `master`.

1. Start from an up-to-date `master`: `git switch master && git pull`.
2. Create a branch: `feature/<short-name>`, `fix/<short-name>`, or `chore/<short-name>`.
3. Build the change, write and prove the tests, run `tests/run_tests.sh`, and
   dispatch the specialist agents. Fix everything they find.
4. Review the diff: no unrelated files, nothing from `.gitignore` forced in,
   no secrets.
5. Commit with a descriptive message (`Add third-person player controller`,
   `Fix camera collision`). Never `update`, `stuff`, `final2`.
6. Push and open a PR to `master`. The PR body lists what changed, the files
   changed, what was tested (with real numbers), the result, known issues,
   and the next step.
7. Wait for the **Tests** CI check on the PR.
   - **Passes:** merge into `master`, then delete the branch (remote and local).
   - **Fails:** read the CI log, fix it **on the same branch**, push a new
     commit, and wait again. The same PR updates in place. **Never open a
     new PR for a fix, never force-push, never merge a red PR.** Never "fix" CI
     by weakening or deleting a check; fix the cause.
   - Every failure teaches something: add it to **Lessons learned**
     (section 14) and to the affected agent's file **in the same PR**.

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
5. Small village
6. Basic interaction
7. Day/night system
8. Sleep system
9. Basic zombie
10. Zombie AI
11. Basic combat
12. Building
13. Inventory
14. Animals
15. NPCs
16. Multiplayer foundation
17. Voice chat
18. TV/social systems
19. Steam integration

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
| **Comparing real pixels** (frame vs the same frame with the body hidden) | Tests what the player sees, not an internal value (lesson 22) |
| **Clean-copy CI checks** (copy to /tmp without `.git`/`.godot`) | Settles "will CI do X?" in 30 seconds |

