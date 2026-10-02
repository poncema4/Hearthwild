# Intentional behaviour and known issues (NOT bugs)

Every agent reads this **before** reporting anything. If what you saw is listed here, it is not a finding.
If it is genuinely new and intentional, the lead adds it here in the same PR. Keep entries short and
include the numbers, so an agent can tell "intended" from "broken" by measuring.

## By design (do not report)

| Behaviour | Numbers / how to recognise it | Why |
|---|---|---|
| Placeholder art | The dog is built from spheres and capsules (stub arms, no elbows or knees, tube legs), simple low-poly trees and rocks, outfits are a cap and a scarf; art comes later | Art comes later; the game loop is being built first |
| Player body fades near walls/trees | Arm shorter than 1.2 m: starts fading; 0.5 m or less: fully invisible (material alpha 0) | Stops the capsule filling the screen when the camera is squeezed in |
| Hills act as the border | Hill-ring slope reaches ~1.0 (45 degrees) at about z=46 (south) and z=50 (north); the player stops there | Natural border; invisible walls at x/z = +-58 backstop the other sides. Nobody is trapped |
| Trees and rocks are solid | Walking straight at a trunk stops you dead (closest gap = trunk radius + 0.4); at an angle you slide around it | Correct collision |
| Capsule sits above the ground on slopes | Resting y exceeds ground height under its centre by 0.4 * (sqrt(1 + gradient^2) - 1), up to ~0.16 m on the hill ring | A round capsule touches a slope at its side |
| Camera arm is offset to the right | 0.5 m shoulder offset: an obstacle must be on the ARM's line, not the player's, to shrink it | Over-the-shoulder camera |
| Holding Space keeps hopping | Every landing starts the next hop; never faster than the 1.03 s airtime (about 63 frames), no double jump; a single tap is one hop | The player asked for continuous jumps (lesson 41) |
| Falling respawns | Below y = -25 the player returns to the spawn point, standing still | Safety net |
| The pond has a walkable bed | Bed at y = -2.2, water surface at y = -0.6, no swimming yet | Swimming is a later step |
| Terrain is not flat away from spawn | Flat within ~4.5 m of the origin, gentle within 9 m, rolling hills beyond, 14 m rim | Meadow valley design |
| The jump strip's first thumbnail is at take-off, not standing still | The filmstrip samples at exact frame intervals after the key press, so the first thumbnail of `jump_arc` is already rising (y about 0.1) | Deterministic sampling; the last thumbnail is back on the floor |
| A tree can briefly hide the player | The camera sits over the right shoulder behind a solid tree: as the player passes, a canopy can cover them for a frame or two. Not clipping: the whole cone renders and the player is intact behind it | Over-the-shoulder camera + solid trees; occlusion handling is a later feature |
| The village ground is perfectly flat and pale | Flat (y = 0) within 14 m of (-20, 14), blending into the hills over 8 m; plaza within 4.5 m is pale cobble mixed with dirt where the 4 paths converge | Buildings need flat foundations; paths are dirt-coloured ground, not separate meshes |
| No trees, rocks, grass or flowers in the village or on a path | Nothing within 1.5 m of the flat zone or 2.6 m of a path | Keeps buildings and walkways clear |
| Cottages have no furniture and no ceiling light | The room is dim (the roof shades it); floor is a flat wooden slab | Placeholder interiors. The doorway (1.4 x 2.2 m) has a hinged leaf 1.34 x 2.15 m, closed at the start, with a 1 cm gap at each side |
| Indoors, the camera arm shortens and the body may fade | The doorway is only 1.4 m wide, so the arm hits the door frame; same rule as at walls | Standard camera squeeze (see "Player body fades near walls") |
| Faces that point down look dark olive green (lintel and eave undersides) | The sky's ground colour is green (0.30, 0.40, 0.28) and drives ambient light for downward faces | Sky/ambient settings; not a texture bug |
| Shaded wall faces look blue-grey | Walls in shadow are lit only by ambient sky light (blue); sunlit faces are cream/pink | Placeholder materials + sky ambient |
| Lamp posts glow but give no light | Emissive lantern only, no light node | Daytime world; real lamp lights come with day/night (step 7) |
| The dog's arms look like a T from the front mid-jump | Arms are short; they reach 1.5-2.5 rad from hanging, so hands are outside the shoulders and about shoulder height | Cartoon proportions |
| The curled, white-tipped tail looks like a raised hand in a side view | In walk and sprint side views the tail (pivot at the lower back, pale tip) sits behind the body at about hip-to-chest height | Placeholder tail shape; confirm from the front or back strip before calling it an arm |
| The dog wags its tail and blinks constantly | Tail every ~1 s, blink every 3.4 s for 0.12 s, ears sway | Idle life |
| The swinging foot lifts as a plain raise | No knee bend; foot lift 5-10 cm | Placeholder rig |
| Doors are closed at the start and open inward | Press E within 2.6 m and facing the door; 0.45 s swing; it won't close on someone in the doorway | Basic interaction (step 6) |
| The mouse is captured at start | Esc frees it, left-click captures again | Standard third-person control |
| Movement feel numbers | Walk 4 m/s, sprint 7 m/s; 90% speed in ~8 / ~13 frames; stop in ~8 frames; 180 turn ~13 frames; jump apex ~1.3 m, airtime ~1.07 s | Measured by `tests/functional/test_movement_feel.gd` (bands in AGENTS.md 8.5) |

## Environment differences (do not report as game bugs)

| Difference | What you will see |
|---|---|
| CI uses the OpenGL Compatibility renderer | No SSAO or glow, slightly flatter, different brightness. Compare screenshots only within the same renderer |
| Headless runs are real-time without `--fixed-fps 60` | Long scenarios are slow, not hung |
| After a teleport the player is still falling | Wait settle frames; measure horizontal movement separately from the drop |
| A real mouse leaks into captured-mouse tests | Use the virtual display; the camera test frees the mouse |

## Known issues (Low; already recorded, do not re-report unless WORSE)

- Pressed against the hill rim, the ground right under the camera has little grass (pale flat band).
- Faint light speckle from distant grass tufts on shaded hill faces.
- Long soft tree shadows streak across shaded hills (softened twice; acceptable).

## Perspective is not overlap

A rock that appears to touch a tree trunk in a screenshot may be metres behind it. Before reporting an
overlap, check a second angle or the real positions (`get_trees()` / `get_rocks()`; the closest rock to
any tree is 1.98 m, and the placement test forbids anything under 1.8 m).

## How to add an entry

One row: behaviour, the numbers that identify it, and why. Link the lesson in `AGENTS.md` section 14 if one exists.
