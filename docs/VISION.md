# Hearthwild — Vision

The design north star. When a choice is unclear, pick what serves this.
This document grows as the idea develops; add to it, don't silently rewrite it.

## In one line

**Animal Crossing meets Minecraft, with zombies at night.** A cozy,
third-person multiplayer village where friends chill, build, dress up and
look after cute animals by day, and stick together to survive when night falls.

## The feeling

```text
COZY (day)  →  ALIVE (evening)  →  DANGEROUS (night)  →  RELIEF (morning)
```

- **Day is the heart of the game.** Players should want to just *hang out*:
  relax, decorate, fish, farm, wander, play with animals, talk. No pressure.
- **Night is the contrast.** Zombies appear only at night. Tension, cooperation,
  getting home safe. Morning brings relief and the cozy loop starts again.
- The world should feel **lived in**, not like a survival map.

## Look and art direction

- **Cozy and charming first**, believable second: soft warm light, gentle
  colours, rounded friendly shapes, lush grass and trees. Think stylized
  (Animal Crossing / Minecraft-adjacent), not gritty photorealism.
- "More realistic" means **better lighting, depth and atmosphere** (shadows,
  sky, fog, ambient occlusion, natural variation), not realistic textures.
- Nights get darker and moodier, but stay readable and never ugly.

## Pillars (and what belongs to each)

| Pillar | Includes | Status |
|---|---|---|
| Living world | Terrain, nature, day/night cycle, weather later | Environment in progress |
| Village life | Houses, NPCs with schedules, shops, events | Later |
| Cute animals | Dogs, cats, chickens, cows, sheep, horses, birds; pettable, followable, with day/night behaviour | Later |
| Self-expression | **Wardrobe and outfits**, character customization, house decorating | Later |
| Building | Modular walls, floors, roofs, furniture, defences | Later |
| Night survival | Zombies at night only, defending, returning home, sleeping to morning | Later |
| Together | Multiplayer, proximity voice chat, watching TV together | Later |

## Ideas parked for later (don't build yet)

- Wardrobe: a closet in the player's house, outfits saved per player, visible
  to others in multiplayer.
- Animals: tameable pets that follow you and hide at night.
- Watching shows together on an in-game TV.
- Seasonal events.

## Not this game

- Not a hardcore survival sim (no hunger micromanagement stress by default).
- Not first-person.
- Not photorealistic.

## Ideas from the player (Marco, 2026-10-03)

- **Character select (done, step 7a):** when the game starts, pick your animal (dog first, more species later), then dress them up in an
  outfit-swap screen. The player's **name floats over their head** (their Steam username once Steam is connected; until
  then a local profile name). Publishing on Steam is the goal; the Steam connection itself can come later.
- **Fishing (done, step 7b):** fish from the water (the pond now, the ocean when the world has one).
- **Time:** a visible sun and moon that really move, realistic dimming at dusk and brightening at dawn (done: day/night),
  clocks you can read (HUD and plaza clock done; a craftable pocket watch when crafting exists).
- **Sleep and morning (step 8 done, multiplayer later):** beds work at night; the morning only comes when ALL players are
  asleep (sleep voting once there is multiplayer). A day is 20 real minutes (Minecraft-like), about 10 of them night.
- **Mobs and the sun (Minecraft logic; basic zombie done, step 12):** zombies spawn at night; when the sun rises the light slowly burns them (they have
  HP), but a mob standing where the sun cannot reach (shade, caves, indoors) survives the day. The player has HP too.
  Weapons come later.
- **A bigger world for multiplayer:** a much larger world and village with room for many players and other jobs.
- **A shared screen (the place is done, step 10):** a big screen in the village where players paste a YouTube link and
  watch together. The place, seating and the paste box exist and only remember the chosen video id; the playback itself
  needs multiplayer sync (`SharedScreen.url_changed` is the hook). A real player (WebView or video stream) is a later
  decision.
- **A realistic lake:** a bigger shoreline with depth, ripples and reflections for fishing.
- **Sitting (done) and more houses (done):** every bench can be sat on; the village has 11 cottages. Sitting together (several players per bench) and sitting facing the screen come with multiplayer.
- **Better UI/UX:** HUD, prompts and menus polished for real players (hotbar and health bar come with combat).
