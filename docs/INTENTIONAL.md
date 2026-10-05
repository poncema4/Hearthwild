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
| The lake has a walkable bed | Bed down to y = -3.4 at the centre, water surface at y = -0.6, no swimming yet | Swimming is a later step |
| The village has 11 cottages: 3 at the plaza, 5 in a ring 24 m out and 3 in an outer ring 36 m out (bearings 52, 98 and 140 degrees), all with a bed; the flat zone is 42 m | The outer cottages sit only in bearing windows whose straight path to the plaza clears every other cottage and the spawn path; a fourth, at 310 degrees, was dropped because its path ran along the spawn path for 12 m; the ring leaves the north and the spawn path free | Room for more players; the lake stays 11.6 m clear of the flat zone |
| Where paths pass within about 2 m of each other near the plaza the dirt bands blend, and the core bench at (-6, 5) from the plaza stands in the outer 140-degree path's strip (walkable around) | All paths run straight from a door to the plaza centre, so they converge | Simple radial layout; a plaza-edge ending or curved paths can come with a plaza redesign |
| The busiest frame costs about 1.6 M triangles, 2,500 objects and 1,400 draw calls (Forward+; 2,500 on Compatibility); the render budget in the visual tour allows about 35% more | The 8-cottage village raised draw calls by 64% over the first 240 m world (every house is many small meshes) | Cheap on a real GPU; merging house meshes is the first thing to try if a budget is hit again (Pulse agent) |
| All 12 dirt paths run to the well at the plaza centre | Walking a path to its end bumps into the well and you step aside; the door-link test needs each path to end at the village centre | Simple radial layout; a plaza-edge ending can come with a plaza redesign |
| Sitting: the sitter's origin is on the ground at the seat, the hips ride 12 cm higher than standing so the thighs rest on the 0.5 m seat, legs straight out forward (no knees), hands beside the thighs, the tail laid sideways on the seat, a fishing rod put away, the stand-up pose snaps (no mid-air leg swing) | The player has no collision while seated; E, Space or a FRESH move key stands up in front of the bench; one sitter per seat | Placeholder pose (the model has no knee joint); keeps benches cheap and the player unable to get stuck |
| Walking diagonally takes as long to reach full speed as walking straight (sprint 7 m/s: 0.23 s) | Acceleration is a vector toward the target velocity; the old per-axis code was up to 1.4x quicker on diagonals but curved the heading | Straight heading and wall sliding matter more (lesson 54) |
| Walking into a wall at any angle slides along it (`wall_min_slide_angle = 0`) | Godot would stop dead within 15 degrees of head-on | Never stick on a wall (lesson 54) |
| The world is 240 m square (was 120): the village, pond and spawn kept their places and the rim moved out; 280 trees, 130 rocks, 48,000 grass tufts | Multiplayer needs room; the extra ground is open meadow and forest until the village grows (next steps) | Walls stand 2 m inside the terrain edge; measured 1.37 M triangles per frame vs 0.54 M before, same draw calls |
| Terrain is not flat away from the village and spawn | Spawn is flat within ~4.5 m and gentle within 9 m, the village zone is flat within 42 m (the spawn lies inside it), rolling hills beyond, 14 m rim starting at 65% of the way to the edge | Meadow valley design |
| The jump strip's first thumbnail is at take-off, not standing still | The filmstrip samples at exact frame intervals after the key press, so the first thumbnail of `jump_arc` is already rising (y about 0.1) | Deterministic sampling; the last thumbnail is back on the floor |
| A tree can briefly hide the player | The camera sits over the right shoulder behind a solid tree: as the player passes, a canopy can cover them for a frame or two. Not clipping: the whole cone renders and the player is intact behind it | Over-the-shoulder camera + solid trees; occlusion handling is a later feature |
| The village ground is perfectly flat and pale | Flat (y = 0) within 42 m of (-20, 14), blending into the hills over 8 m; plaza within 4.5 m is pale cobble mixed with dirt where the 4 paths converge | Buildings need flat foundations; paths are dirt-coloured ground, not separate meshes |
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
| A day lasts 20 real minutes (about 10 of them night, Minecraft-style) and starts at 10 AM | Sun rises 6 AM, sets 6 PM; the test kit freezes the clock at 10:00 so light never drifts under a test | Day/night (step 7); `DayNight.day_length_seconds` |
| Night is dark blue, not black; dusk is orange; the first/last minutes before sunrise are dim | Moon light 0.28, ambient never below 0.9, the 4 village lamps (OmniLight, no shadows) glow warm after dark | Readable but moody; zombies come at night later |
| Shadows of the moon are soft and weak | Moon shadow opacity 0.5 | Night look |
| Three animals: dog, cat, bunny (placeholder shapes) | The cat's tail curves up, the bunny's ears are tall (the model is up to 2.1 m with ears; the name tag floats above them) | More animals later = new `AnimalSpecies` rows |
| The character screen opens on a first launch and with F2; the name defaults to the Steam name (none yet), else the computer's user name | Name at most 16 characters; saved in `user://profile.json` (never in git) | Steam comes later; `PlayerProfile.steam_name()` is the hook |
| Everyone's name floats over their head, including your own | White text with a dark outline, fades with the body when the camera is close | Name tags (Steam names later) |
| The shared screen only REMEMBERS the chosen YouTube video; nothing plays | `SharedScreen` shows "NOW SHOWING youtu.be/<id>" and emits `url_changed`; links are reduced to the 11-character id and never fetched or opened | Real playback needs multiplayer sync and a video surface (later); never fetching anything keeps a hostile link harmless |
| The big screen stands at offset (6, -24) from the plaza on the open north side, 6 benches in two rows in front, text sized to fit (about 5 x 2.3 m on an 8 x 4.5 m face) | Prompt "Choose what to watch" from anywhere between the screen and the benches | Inside the 42 m flat zone, clear of every cottage and prop |
| The lake is 20 m in radius at (46, -34), far from the village; its shoreline is irregular (about 11.5 to 13.5 m from the centre), with a beach a few metres wide and a bank raised 0.5 m above the water all round | Water is a shader (`assets/shaders/water.gdshader`) driven by a baked depth map of the real ground: shallows turquoise, deep blue, foam at the waterline, sky reflection, dark at night; reeds and 36 lily pads | Spots are measured, not guessed: from the waterline walk out to dry ground (0.35 m above the water), cast far enough to reach 1 m of water (3.2 to 6.5 m); 12 bearings, all feasible today |
| Trees and rocks stay 5 m beyond the lake's radius | Banks are open for fishing and reeds | Fishing needs room |
| The fishing line is a thin straight pale cylinder from the rod tip to the bobber | No sag or physics | Placeholder |
| A cast is cancelled by jumping (4+ frames off the ground), walking more than 1.6 m away, or opening a menu | Messages: "You walked away and pulled in your line." / "You put your rod away." | Fishing rules (step 7b) |
| The HP bar's dark background is translucent (alpha 0.78, like every HUD panel), so a dark object behind it (the notice board's frame from the spawn view) shows through as a darker wedge at the bar's end | Pixel-identical in every health frame; background samples (54,62,75) over sky vs (41,41,47) over the brown frame; the opaque red fill hides it at full health (Hawkeye, step 11) | Consistent with the other HUD panels; a Nit at most |
| Dying is a knock-out, not a game over; sleeping does not heal | At 0 hp the player respawns at the spawn point with full hp, is free to move, and the HUD says "You were knocked out and woke up at the village spawn." (the HP bar flashes through 0 for one frame); a full night's sleep leaves 40 hp at 40 | Safe for a cozy game; real death rules, healing and food come later |
| Zombies have no brain beyond "walk straight at the nearest awake player in 28 m" | No wandering (they stand still with no target), no obstacle avoidance (a tree or wall between them and the player blocks them), no opening doors, no groups | Zombie AI is step 13; do not report these before it |
| Zombie numbers | 20 hp; 2.4 m/s (the player walks 4, sprints 7); hits for 8 every 1.2 s at 1.5 m, first hit on contact; detect range 28 m; sun burn 2 hp/s in 0.25 s ticks; the sun must be above 0.05 elevation (about 6:03 AM and 5:57 PM) and a ray from the head toward it must reach the sky; a hit also needs a clear line to the player (cottage walls stop it) and the player within 1.6 m of the zombie's height, which a normal jump (apex 1.3 m) does not escape, only a ledge or roof does | Tuned so a walking player always outruns one and a sprinting one has time to reach a cottage |
| Only tree TRUNKS, rocks, hills and buildings shade a zombie from the sun; tree leaves have no collider, so a zombie standing under a canopy still burns | Measured by Ghoul (trunk collider only; solid top 1.6 to 2.9 m vs mesh 4.3 to 6.5 m) | Canopy colliders (ray-only) come with the nature art pass; do not report as a bug before then |
| A burning zombie glows salmon-orange (emission x0.55 on all its materials), no flames or smoke | Seen in the noon screenshot | Placeholder art; particles come with the art pass |
| Zombies spawn 25 to 40 m from the player even if that is next to the village; only the spawn POINT must be outside the village (+6 m), the zombie may then walk in | Spawner rules in AGENTS.md section 5 | Keeps spawning simple; cottages and the sun are the defence |
| Beds work from 7 PM to 6 AM only; sleeping always ends at 6:30 AM | By day the bed says "Too early to sleep (after 7 PM)" and E only shows "You're not tired yet"; sleeping at 3 AM wakes at 6:30 the same morning | Keeps the night for zombies and stops skipping the day; multiplayer will need sleep voting because the clock is shared |
| While asleep the player is locked, has no collision and cannot be reached by E or fishing; you wake standing beside the bed, facing away from it (the move happens while the screen is black) | The character slides onto the mattress and lies on its back (the tail dips into the mattress frame, hidden) with a floating Z z z | Placeholder pose; zombies must leave a sleeping player alone (step 9) |
| Pressing E before the bite scares the fish away; after the 1.4 s window it "got away" | Waiting is 2 to 6 s, the cast 0.6 s | Fishing rules |
| Junk (old boot, rusty can) is shown but never kept in the journal | The journal counts only real fish | Fishing rules |
| The character screen has Cancel (Esc) only when reopened with F2, never on the first launch | The first launch must pick a look | Character screen |
| Everyone shares one `PlayerProfile.current()` and a spot has one angler | Fine for one local player | Multiplayer step will make both per-player |
| The bunny's ears reach 2.2 m in a hop and the cat's tail ends about 0.5 m behind the body | Visual only; the collision capsule is unchanged | Placeholder shapes |
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
