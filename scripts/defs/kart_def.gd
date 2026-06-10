class_name KartDef
extends Resource
## A kart chassis: handling stats plus its own sprite sheet (no rider —
## the selected CharacterDef is drawn on top at the seat anchor, so any
## character can ride any kart). Create one .tres per kart under
## res://assets/karts/<name>/ alongside sheet.png and sheet.json.
## Character speed/accel/handling mods multiply the base stats.
## See docs/kart-art-guide.md for export settings and tag naming.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Sprites")
## Aseprite-exported kart sprite sheet PNG (chassis, wheels, and the
## blob shadow — no rider).
@export var sprite_sheet: Texture2D
## The matching Aseprite JSON data file (Array format, tags enabled).
@export var aseprite_json: JSON
## If true, only n/ne/e/se/s angles need to be drawn; w/nw/sw are
## mirrored from the east-side angles automatically.
@export var mirror_sprites: bool = true
## World size of one sprite pixel in meters (Sprite3D.pixel_size).
@export var sprite_pixel_size: float = 0.045
## Vertical offset of the billboard above the kart origin, in meters.
@export var sprite_y_offset: float = 0.0
## Menu icon. Falls back to the first idle_s frame when empty.
@export var icon: Texture2D

@export_group("Seat")
## Where the rider's frame bottom-center sits, per view direction, in
## kart-sheet pixels measured from the kart frame's bottom-center
## (+x right, +y up). w/nw/sw mirror the east-side values with x negated.
@export var seat_n: Vector2 = Vector2(0, 8)
@export var seat_ne: Vector2 = Vector2(-1, 8)
@export var seat_e: Vector2 = Vector2(-2, 8)
@export var seat_se: Vector2 = Vector2(-1, 8)
@export var seat_s: Vector2 = Vector2(0, 8)


## Seat anchor for any of the 8 view directions, west side mirrored.
func seat_px(dir: String) -> Vector2:
	match dir:
		"n": return seat_n
		"ne": return seat_ne
		"e": return seat_e
		"se": return seat_se
		"s": return seat_s
		"sw": return Vector2(-seat_se.x, seat_se.y)
		"w": return Vector2(-seat_e.x, seat_e.y)
		"nw": return Vector2(-seat_ne.x, seat_ne.y)
	return seat_n

@export_group("Speed")
## Top speed in m/s.
@export var top_speed: float = 18.0
## Acceleration in m/s^2.
@export var acceleration: float = 10.0
@export var braking: float = 22.0
@export var reverse_speed: float = 6.0

@export_group("Handling")
## Steering rate in rad/s at full grip.
@export var steer_speed: float = 1.8
## 0..1 fraction of steering lost at top speed.
@export var steer_speed_falloff: float = 0.35
## How quickly lateral slip is corrected back toward heading.
@export var grip: float = 8.0

@export_group("Drift")
## Steering multiplier range while drifting (countersteer..full lock).
@export var drift_steer_min: float = 0.6
@export var drift_steer_max: float = 1.8
## Seconds of drifting needed to charge a mini-turbo.
@export var mini_turbo_threshold: float = 1.0
## Top-speed multiplier while boosting.
@export var boost_strength: float = 1.35
## Mini-turbo boost duration in seconds.
@export var boost_duration: float = 1.2
