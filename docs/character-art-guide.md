# Meme Kart — Character Art Guide (Aseprite)

This is everything you need to draw a playable character. You'll deliver
**two files** from one Aseprite project — a sprite sheet PNG and its JSON
data file — plus a name. No game/engine knowledge required.

## The big picture

The game is a Mario Kart 64-style racer: the world is 3D, but every
character is a flat 2D sprite that always faces the camera. To fake depth,
you draw the character **from several viewing angles**, and the game swaps
frames as the camera moves around them.

**You draw the RIDER only — no kart.** Karts are separate sprite sheets
(see `kart-art-guide.md`), and the game seats your character on whichever
kart the player picks, so any character can ride any kart. Draw the
character in a seated driving pose: hands forward as if on a wheel,
**no legs/lower body** — only what would be visible above the kart's
bodywork. The game places your frame's **bottom-center at the kart's seat
point**, and the kart's cowl will NOT cover any part of your art, so
anything you draw will show.

## 1. Canvas setup

- One Aseprite file for the whole character.
- **Square canvas, same size for every frame.** 32×32, 48×48, or 64×64 all
  work (existing placeholders are 32×32; 48 or 64 gives you more detail).
  Use the same pixel density as the kart sheets so the rider doesn't look
  zoomed in/out against the kart (placeholder karts are 32×32 with the kart
  ~22 px wide; ask if unsure).
- **Transparent background.** No baked-in background color, **no shadow** —
  the blob shadow lives on the kart sheet.
- **Anchor the art to the bottom edge, horizontally centered**: the
  bottom-center pixel of the canvas is the seat contact point. The
  character's seat/hips should touch the bottom row of pixels. Empty space
  below the art makes the rider hover above the kart.
- Perspective: viewed from slightly above (~20° down), classic 3/4
  racing-game look — same as the kart sheets.

## 2. The 8 directions (you only draw 5)

Direction names describe where the character's kart is **pointing on
screen**, compass style:

```
        n   = pointing away from you (BACK view — seen 95% of the time!)
     nw   ne
   w         e   = pointing right (side profile)
     sw   se
        s   = pointing at you (front view, face visible)
```

**You only need to draw the 5 right-side/center views: `n  ne  e  se  s`.**
The game mirrors them automatically for `w`, `nw`, `sw` (and is smart about
swapping left/right drift poses when it mirrors).

> Caveat: mirroring flips asymmetric details — an eyepatch, a side ponytail,
> a shoulder logo. If your design is strongly asymmetric, draw all 8
> directions instead and tell us so we set `mirror_sprites = false`.

Spend your effort proportionally: **`n` (back view) is what the player
stares at the entire race.** `ne`/`se` show up constantly in turns. `e` and
`s` are mostly seen on other racers and in the menu (the front view `s` is
also used as the menu portrait).

## 3. Animations (Aseprite tags)

Every animation is an Aseprite **tag** (Frame → Tags) named exactly
`<animation>_<direction>`, lowercase:

| tag pattern | when it plays | frames | notes |
|---|---|---|---|
| `idle_n` … `idle_s` | standing still | 1+ | a tiny 2-frame breathing wobble is a nice touch |
| `drive_n` … `drive_s` | driving | 2+ | playback speed scales with kart speed; a 2-frame 1px body bounce works great |
| `drift_l_n` … `drift_l_s` | drifting **left** | 1+ | body leaning/twisting left into the drift |
| `drift_r_n` … `drift_r_s` | drifting **right** | 1+ | mirror pose of drift_l |
| `spin` | hit by a shell | 4–8 | **no direction suffix** — draw the rider rotating through a full turn; it plays the same regardless of camera |

So the complete set with mirroring is **21 tags**:
5 directions × (idle, drive, drift_l, drift_r) + 1 spin.

Tips:
- Frame **durations you set in Aseprite are respected** in-game.
- **Bounce sync:** the kart sheets bounce 1px on the 2nd drive frame at
  120 ms/frame. If you give your drive anim the same 1px bounce and
  timing, rider and kart bob together as one piece. Same idea for `spin`
  (kart spins through 8 × 80 ms frames).
- Frame order inside the file doesn't matter — tags define everything. Lay
  out your timeline however you like (e.g. one direction per row of tags).
- Missing things don't crash: any missing tag falls back to a sensible
  substitute (ultimately `drive_n`). A character with *only* `drive_n` is
  valid — useful for a quick first in-game test before drawing the rest!

## 4. Export settings (exact)

File → **Export Sprite Sheet**:

- **Layout** tab — Sheet type: anything (Packed is fine).
- **Sprite** tab — Source: Sprite; Layers: Visible layers.
- **Borders** tab — Border Padding `0`, Spacing `0`, Inner Padding `0`,
  **Trim Sprite: OFF, Trim Cels: OFF** (trimming breaks frame alignment).
- **Output** tab —
  - ✅ **Output File** → `sheet.png`
  - ✅ **JSON Data** → `sheet.json`, type **Array** (not Hash)
  - Meta: ✅ **Tags** (Layers/Slices not needed)

Deliver: `sheet.png` + `sheet.json` + the character's display name.

## 5. Hooking it into the game (whoever has the repo)

1. Make a folder `assets/characters/<id>/` and drop both files in.
2. In the Godot editor: right-click the folder → **Create New → Resource →
   CharacterDef**, save as `<id>.tres`, and fill in:
   - `id` — unique lowercase name, e.g. `doge`
   - `display_name` — what menus show
   - `sprite_sheet` → `sheet.png`, `aseprite_json` → `sheet.json`
   - `mirror_sprites` — `true` if only 5 directions were drawn
   - `sprite_pixel_size` — world meters per pixel; match the kart sheets'
     scale: `0.045` for 32px-density art, `0.03` for 48px, `0.022` for 64px
   - stats: `speed_mod` / `accel_mod` / `handling_mod` (0.7–1.3, 1.0 =
     neutral) and `weight` (heavier = shrugs off bumps, recovers from
     spins faster)
3. Run the game — the character is in the menu and the AI roster, riding
   any kart. No code.

## 6. Checking your work

The repo has a dedicated viewer: run the project with the scene
`scenes/dev/sprite_turntable.tscn` (or from the editor, open it and press
Play Scene). It shows the character seated on a kart with the camera
orbiting — you can watch every direction swap in, confirm the mirror views
look right, check the seat fit on each kart, and check
`idle`/`drive`/`drift_l`/`drift_r`/`spin` poses.

Quick sanity checklist before handing files over:

- [ ] All frames the same size, transparent background, **no shadow, no kart**
- [ ] Seat/hips touch the bottom edge, art horizontally centered
- [ ] 21 tags (or 33 if drawing all 8 directions), lowercase, exact names
- [ ] `spin` tag has no direction suffix
- [ ] Exported with JSON **Array** + **Tags**, Trim **OFF**, padding 0
- [ ] Back view (`n`) is the best-looking frame — it's the star
