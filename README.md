# Hearthwild

A cozy third-person multiplayer village game, built in Godot.
**Animal Crossing meets Minecraft, with zombies at night.**

> Cozy during the day → social in the evening → dangerous at night → relief when morning comes.

The full vision (cute animals, wardrobe and outfits, village life, night
survival, playing together) lives in [`docs/VISION.md`](docs/VISION.md).

## What's in the game so far

| Feature | What you get |
|---|---|
| **Meadow world** | A 120 × 120 m valley with rolling hills, a ring of taller hills around the edge, a pond, and a flat clearing where you spawn |
| **Nature** | 90 trees (round and pine), 45 rocks, thousands of grass tufts and wildflowers, in a soft low-poly style |
| **Daytime lighting** | Warm sun with shadows, soft sky, gentle fog for depth, ambient occlusion and glow |
| **Village** | A flat village green at the north-west with a cobble plaza, a well, three cottages you can walk into (door, windows, gabled roof, chimney), lamp posts, benches, a notice board, fences and dirt paths from the spawn and to every door |
| **Your character** | A cute dog with big eyes, floppy ears and a wagging tail, animated as you move (walk, sprint, jump), ready for outfits (a cap and a scarf are in) and for more animals later |
| **Third-person player** | Walk, hold Shift to sprint, hold Space to keep hopping; trees, rocks and walls are solid; fall out of the world and you respawn |
| **Day and night** | A 12-minute day: the sun crosses the sky, sets in orange, the moon and warm lamps take over, then it brightens again at dawn; a clock on screen and a clock post in the plaza |
| **Interaction** | Press E near a cottage door to open or close it, or at the notice board to read it |
| **Camera** | Orbit with the mouse, zoom with the wheel; pulls in so it never clips through walls, and your character fades out if the camera gets too close |

Next up (see the development order in `AGENTS.md`): pick your animal and an outfit-swap screen with a name tag, then fishing, then sleep and zombies.

## Running it

1. Install **Godot 4.7.2** (standard build) from https://godotengine.org/download/archive/4.7.2-stable/
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (or the ▶ Play button).

The main world is `scenes/world/world.tscn`. The terrain and nature also show
up in the editor, not only when playing.

| Key | Action |
|---|---|
| W A S D | Move |
| Shift | Sprint |
| Space | Jump |
| Mouse | Look around |
| Mouse wheel | Zoom camera |
| Esc / left-click | Free / capture the mouse |

## Testing

```bash
tests/run_tests.sh                 # everything (20 steps, about 5 minutes)
tests/run_tests.sh --headless-only # skip the rendered checks
```

- `tests/README.md` is the map of every test file. Headless number tests live in `tests/functional/`,
  rendered screenshot tests in `tests/playtests/`.
- Headless checks run with `--fixed-fps 60`. With **Xvfb** installed (`sudo apt install xvfb`) rendered
  checks run on an invisible virtual display, so no windows pop up (`HW_SHOW_WINDOW=1` shows them).
- Every run saves screenshots as `qa_output/<topic>/<YYYY-MM-DD_HH-MM-SS>/`, with a `manifest.json` per run
  and an index at `qa_output/INDEX.md` that says which images changed and need review. Movement is saved
  as **filmstrips** (one image, thumbnails in time order). Old runs are never deleted.
- The same checks run on every pull request via GitHub Actions (in the OpenGL Compatibility renderer).

## The AI agent team

Changes are built by a lead AI session and checked by specialist agents in `.claude/agents/`. Each agent
has a detailed protocol aimed at near-zero false positives (it must confirm a finding a second way, check
`docs/INTENTIONAL.md`, and list what it dismissed). Only the agents a change needs are run, to keep token
use low (dispatch matrix in `AGENTS.md` 9.6).

| Agent | Job |
|---|---|
| **Warden** | Runs the full test suite in both renderers and reports every result |
| **Scout** | Plays the game trying to break it |
| **Hawkeye** | Reviews the screenshots and movement filmstrips that changed |
| **Sage** | Reviews the code, organization and docs before it merges |
| **Mason** | Measures the world: flat foundations, door sizes, solid walls, paths, "can the player get stuck?" |
| **Animator** | Judges the character's motion: limb directions, walk cycle, skating, snaps, the jump pose |

Every mistake found while building something is written into `AGENTS.md` (section 14) and the relevant
agent's file in the same pull request, so it can't happen twice.

## Project layout

`scenes/world/world.tscn` is the one main world. `scripts/`, `scenes/`, `tests/` (with `functional/`,
`playtests/`, `support/`, `tools/`) and `docs/` each hold one kind of thing; the full tree is in
`AGENTS.md` section 6. `docs/VISION.md` is where the game is headed; `docs/INTENTIONAL.md` lists what is
by design (not a bug).

## Contributing

Read `AGENTS.md` before making changes. Every change goes through a pull
request that must pass the **Tests** check before merging. Fixes for a
failing PR go on the same PR, along with the lesson learned.
