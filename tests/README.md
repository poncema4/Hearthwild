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
| `playtests/` | Rendered tests that save screenshots into `qa_output/`. | yes (Xvfb is fine) |
| `playtests/playtest_camera.gd` | Mouse look, pitch clamp, zoom, wall squeeze + player fade (pixel-checked). | yes |
| `playtests/playtest_visual_tour.gd` | 15 scenic screenshots (environment, nature, player), each auto-checked. | yes |
| `playtests/playtest_movement.gd` | Movement filmstrips (contact sheets) for visual review. | yes |
| `support/playtest_kit.gd` | `PlaytestKit`: shared helpers (load world, input, shots, manifests, filmstrips). | no |
| `tools/make_qa_index.py` | Rebuilds `qa_output/INDEX.md` (what to review) from the manifests. | no |

New tests go in `functional/` (numbers) or `playtests/` (pixels), named `test_<thing>.gd` /
`playtest_<thing>.gd`, and get one row here. Never leave a loose file directly in `tests/`.
