# Meme Kart — Kart Art Guide (Aseprite)

Karts are drawn exactly like characters (see `character-art-guide.md` for
the full Aseprite workflow — directions, tags, export settings are
identical). This guide only covers what's different. Deliver the same two
files: `sheet.png` + `sheet.json`, plus a name.

## What a kart sheet contains

**The empty kart: chassis, wheels, steering wheel — no rider.** The game
draws the selected character on top, so any character can ride any kart.

- **Blob shadow goes on the KART sheet** (character sheets have none).
  Paint it at the frame bottom, unaffected by any bounce frames.
- **Anchor to the bottom edge**: wheels/shadow touch the bottom row of
  pixels; that line is where the kart meets the road in-game.
- Scale: the kart should read ~1.4 m wide in-game. At 32×32 that's ~22 px
  wide (`sprite_pixel_size 0.045`); 48×48 → `0.03`; 64×64 → `0.022`.
- The rider is drawn **in front of** the kart in every view, never clipped
  by the cowl — keep the seat area visually open (don't paint a high
  windshield or roll bar where the rider's torso goes).

## Same tags as characters

5 mirrored directions (or all 8) × `idle` / `drive` / `drift_l` /
`drift_r`, plus one direction-less `spin` — 21 tags. For `drive`, a
2-frame 1px chassis bounce at 120 ms matches the placeholder characters'
bounce so kart and rider bob together. Drift poses: kart twisted ~30°
toward the drift relative to that view's normal angle.

## The seat anchor

The rider's frame bottom-center is pinned to the kart's **seat anchor** —
a per-direction pixel offset set in the KartDef (not in Aseprite):

- Measured in kart-sheet pixels from the **bottom-center** of the frame,
  `+x` right, `+y` up.
- One value per drawn direction: `seat_n`, `seat_ne`, `seat_e`, `seat_se`,
  `seat_s`. West views reuse the east values with x flipped.
- Rule of thumb: y = just above the chassis top at the seat; x follows the
  seat as the view rotates (e.g. seat sits toward the rear, so in the `e`
  view it shifts a couple px left, back to 0 in `n`/`s`).
- Placeholder values (32px sheets): n `(0,8)`, ne `(-1,8)`, e `(-2,8)`,
  se `(-1,8)`, s `(0,8)`.

## Hooking it into the game

1. Make a folder `assets/karts/<id>/`, drop `sheet.png` + `sheet.json` in.
2. Create a **KartDef** resource as `<id>.tres` in that folder and fill in
   `id`, `display_name`, the two sheet files, `mirror_sprites`,
   `sprite_pixel_size`, the five `seat_*` values, and the handling stats
   (`top_speed`, `acceleration`, `steer_speed`, drift/boost tuning — copy
   `standard.tres` and tweak).
3. Run the game — the kart appears in the menu's KART column and the AI
   roster. No code.

Check the fit with `scenes/dev/sprite_turntable.tscn`: it seats a
character on the kart and orbits the camera; call `set_kart(&"<id>")` /
`set_character(&"<id>")` to try every combination, and nudge the `seat_*`
values in the .tres until the rider sits right from all angles.
