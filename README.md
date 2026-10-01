# Hearthwild

A third-person multiplayer 3D village/life-sim survival game, built in Godot.

> Cozy during the day → social in the evening → dangerous at night → relief when morning comes.

## Status

Early prototype: a small test world with a third-person character you can
walk, sprint and jump around with an orbiting camera. See `AGENTS.md` for
the current state and the development order.

## Running it

1. Install **Godot 4.7.2** (standard build) from https://godotengine.org/download/archive/4.7.2-stable/
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (or the ▶ Play button).

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
tests/run_tests.sh                 # everything (opens a game window briefly)
tests/run_tests.sh --headless-only # no window
```

The same checks run on every pull request via GitHub Actions.

## Contributing

Read `AGENTS.md` before making changes. Every change goes through a pull
request that must pass the **Tests** check before merging.
