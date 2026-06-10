# Meme Kart

An N64-style 2.5D kart racer shell for Godot 4.6: 3D tracks, 2D billboard
sprite karts (classic Mario Kart 64 pre-rendered look), drifting with
mini-turbos, AI opponents, items, and full race flow.

Everything visible is **placeholder programmer art**. The whole point of this
shell is the asset interface below: drop in your own Aseprite-drawn
characters, karts, and tracks without touching any engine code.

## Running

Open the project in Godot 4.6+ and press Play. Or from the CLI:

```bash
godot --path .
```

| Action | Keyboard | Gamepad (XInput) |
|---|---|---|
| Accelerate | W / Up | A |
| Brake / Reverse | S / Down | B |
| Steer | A,D / Left,Right | Left stick |
| Hop / Drift | Space | RB or RT |
| Use item | E / Left Ctrl | LB or X |
| Pause | Esc | Start |

Hold drift while turning to charge a mini-turbo; release for a boost.

**Sound** is fully synthesized at startup (`scripts/core/sound_fx.gd`) —
engine hum, drift hop, boost, item roulette, shell, spin-out, countdown,
finish jingle, and a chiptune music loop. No audio files exist; replace any
of it by swapping entries in `SoundFx._build_streams()` or pointing
`TrackDef.music` at a real AudioStream.

## How assets work

At startup the `Registry` autoload scans `res://assets/` recursively and
indexes every `.tres` resource it finds by type:

- `CharacterDef` → a playable/AI character (sprite sheet + stat modifiers)
- `KartDef` → a kart chassis (speed/handling/drift stats)
- `TrackDef` → a race track (scene + lap count)

**Adding content = dropping a folder under `assets/` with a `.tres` in it.**
No registration lists, no code edits. Duplicate ids warn and last-wins.

```
assets/
  characters/<name>/<name>.tres + sheet.png + sheet.json
  karts/<name>.tres
  tracks/<name>/<name>.tres + <name>.tscn
```

The placeholder content (rosso/blu/verde, standard/speedy, test_oval) is
regenerable with:

```bash
godot --headless --path . --script res://scripts/tools/gen_placeholders.gd
godot --headless --path . --script res://scripts/tools/gen_track.gd
```

---

## Adding a character (Aseprite workflow)

> Handing this to an artist? Send them
> [docs/character-art-guide.md](docs/character-art-guide.md) — a
> self-contained guide with canvas setup, tag checklist, and exact export
> settings.

### 1. Draw

One Aseprite file, any canvas size (placeholders use 32×32; 48×48 or 64×64
look great too — all frames must be the same size). The character sits in
their kart, drawn from up to 8 viewing directions:

```
        n  (back view — what you see driving)
     nw    ne
   w          e   (e = kart pointing right on screen)
     sw    se
        s  (front view — facing the camera)
```

**You only need to draw 5 directions** (`n ne e se s`): set
`mirror_sprites = true` on your CharacterDef and the west-side views are
mirrored from the east-side ones automatically (drift left/right are swapped
correctly when mirrored).

### 2. Tag

Animations are Aseprite **tags** named `<anim>_<dir>`:

| anim | meaning | typical frames |
|---|---|---|
| `idle_<dir>` | standing still | 1 |
| `drive_<dir>` | driving (speed-scaled playback) | 2+ |
| `drift_l_<dir>` | drifting left | 1+ |
| `drift_r_<dir>` | drifting right | 1+ |
| `spin` | hit by a shell — **no direction suffix** | 4–8 |

Only `drive_n` is strictly required; anything missing falls back
(mirror → `<anim>_n` → `idle_n` → `drive_n`) so partial sheets still run.
Frame durations set in Aseprite are respected.

### 3. Export

File → Export Sprite Sheet with **exactly** these settings:

- Sheet type: any (Packed is fine — frames are read from the JSON)
- Borders: padding/spacing 0, **Trim: OFF**
- Output: check **Output File** (`sheet.png`) and **JSON Data** (`sheet.json`)
- JSON Data type: **Array** (not Hash)
- Meta: check **Tags**

### 4. Register

Create `assets/characters/<name>/<name>.tres` — easiest in the Godot editor:
right-click the folder → New Resource → CharacterDef, then fill it in:

| field | meaning |
|---|---|
| `id` | unique StringName, e.g. `&"doge"` |
| `display_name` | shown in menus/results |
| `sprite_sheet` | your `sheet.png` |
| `aseprite_json` | your `sheet.json` |
| `mirror_sprites` | `true` if you drew 5 directions |
| `sprite_pixel_size` | world meters per sprite pixel (0.045 for 32px sprites; halve it for 64px) |
| `sprite_y_offset` | extra height above the kart origin |
| `icon` | optional menu portrait (falls back to the `idle_s` frame) |
| `speed_mod` / `accel_mod` / `handling_mod` | 0.7–1.3 multipliers on the kart's stats |
| `weight` | spin-out recovery / bump exchange |

Run the game — the character appears in the menu and the AI roster.

## Adding a kart

Create `assets/karts/<name>.tres` (New Resource → KartDef). All handling
lives here: `top_speed` (m/s), `acceleration`, `braking`, `reverse_speed`,
`steer_speed`, `steer_speed_falloff`, `grip`, `drift_steer_min/max`,
`mini_turbo_threshold` (seconds of drift to charge), `boost_strength`
(top-speed multiplier), `boost_duration`. Character mods multiply on top.

## Adding a track

A track is a `TrackDef` (.tres: `id`, `display_name`, `scene`, `laps`,
optional `preview`/`music`, `kill_y`) pointing at a scene whose root contains
these **exactly-named** children (validated at load with clear errors):

| node | type | contract |
|---|---|---|
| `TrackGeometry` | Node3D | All visuals + collision (StaticBody3D or CSG with `use_collision`), physics layer 1 `world`. Include your own light/WorldEnvironment. |
| `Checkpoints` | Node3D | Ordered `Area3D` children — child order = lap order, **child 0 is the finish line**. Box CollisionShape3D spanning the road, layer 3 `trigger`, mask 2 `kart`. Each checkpoint's own transform is the respawn point/facing for karts that fall off. Use 8+ per lap. |
| `StartGrid` | Node3D | 6+ `Marker3D` children, pole position first, **-Z facing the direction of travel**. |
| `ItemBoxes` | Node3D | `Marker3D` children; an item box spawns at each. Can be empty. |
| `AIPath` | Path3D | A **closed** Curve3D following the road center at surface height, direction = direction of travel. Drives AI steering, wrong-way detection, and position ranking. |

`assets/tracks/test_oval/test_oval.tscn` is a working reference (generated
by `gen_track.gd`, which is also a handy example of building one in code).

Physics layers: 1 `world`, 2 `kart`, 3 `trigger`, 4 `projectile`.

## Code map

```
scripts/
  core/registry.gd        asset scan/lookup (autoload Registry)
  core/game.gd            selections + screen flow (autoload Game)
  defs/                   CharacterDef / KartDef / TrackDef
  sprites/aseprite_sheet.gd   Aseprite JSON parser (tags -> frames)
  sprites/billboard_sprite.gd 8-direction billboard frame picker
  kart/kart_controller.gd arcade physics: speed/steer/drift/boost/spin
  kart/player_input.gd    InputMap -> kart inputs
  kart/ai_driver.gd       curve-following CPU driver
  kart/chase_camera.gd    MK64-style follow cam
  race/race_manager.gd    track contract, spawning, laps, ranking, results
  race/hud.gd             in-race UI (also handles pause)
  items/                  item slot/roulette, item box, shell projectile
  menu/main_menu.gd       character/kart/track select
  tools/                  placeholder generators + dev test scenes
scenes/dev/               sprite_turntable.tscn, drive_test.tscn
```

Items are intentionally hardcoded (`ItemHolder.Item` enum) in this shell;
extending to data-driven `ItemDef` resources mirrors the pattern above.
