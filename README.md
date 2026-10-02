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
| **Third-person player** | Walk, sprint, jump; trees, rocks and walls are solid; fall out of the world and you respawn |
| **Camera** | Orbit with the mouse, zoom with the wheel; pulls in so it never clips through walls, and your character fades out if the camera gets too close |

Next up (see the development order in `AGENTS.md`): a small village.

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
tests/run_tests.sh                 # everything
tests/run_tests.sh --headless-only # skip the rendered checks
```

- Headless checks run with `--fixed-fps 60`, so the whole suite takes about a minute.
- With **Xvfb** installed (`sudo apt install xvfb`), rendered checks run on an
  invisible virtual display: no windows pop up. `HW_SHOW_WINDOW=1` shows them.
- Every run saves screenshots, organised by topic and run time:
  `qa_output/<camera|environment|nature|player>/<date_time>/`. Old runs are kept.
- The same checks run on every pull request via GitHub Actions.

## The AI agent team

Changes are built by a lead AI session and checked by four agents in
`.claude/agents/`:

| Agent | Job |
|---|---|
| **Warden** | Runs the full test suite and reports every result |
| **Scout** | Plays the game trying to break it |
| **Hawkeye** | Inspects every screenshot for visual problems |
| **Sage** | Reviews the code before it merges |

## Contributing

Read `AGENTS.md` before making changes. Every change goes through a pull
request that must pass the **Tests** check before merging. Fixes for a
failing PR go on the same PR, along with the lesson learned.
