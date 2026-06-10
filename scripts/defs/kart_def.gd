class_name KartDef
extends Resource
## A kart chassis with handling stats. Create one .tres per kart under
## res://assets/karts/. Character speed/accel/handling mods multiply
## these base values.

@export var id: StringName = &""
@export var display_name: String = ""

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
