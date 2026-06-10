class_name KartController
extends CharacterBody3D
## Arcade MK64-style kart physics. Kinematic: speed is a signed scalar
## along the body's -Z heading; steering rotates the body; drifting adds
## lateral slip and charges a mini-turbo. A driver node (player_input.gd
## or ai_driver.gd) writes the input_* fields each physics tick.

signal spun_out
signal boost_started

const SCENE := "res://scenes/kart/kart.tscn"
const GRAVITY := 25.0
const HOP_IMPULSE := 4.0
const DRIFT_SLIP := 0.30   # rad the travel direction lags behind heading while drifting
const SPIN_DURATION := 1.2

# Driver inputs, written externally each physics tick.
var input_steer: float = 0.0        # -1 (left) .. 1 (right)
var input_throttle: float = 0.0    # 0..1
var input_brake: float = 0.0       # 0..1
var input_drift_held: bool = false
var input_drift_pressed: bool = false
var input_item_pressed: bool = false

## Disabled during countdown / after finish (AI keeps driving after finish).
var control_enabled: bool = false

var character: CharacterDef
var kart_def: KartDef

# Derived stats (KartDef x CharacterDef mods).
var top_speed: float
var acceleration: float
var braking: float
var reverse_speed: float
var steer_speed: float
var steer_falloff: float
var weight: float = 1.0

# Runtime state.
var speed: float = 0.0
var drift_dir: int = 0             # 0 = not drifting, -1 = left, 1 = right
var drift_charge: float = 0.0
var boost_timer: float = 0.0
var boost_top_mult: float = 1.0
var spin_timer: float = 0.0

@onready var visual: KartVisual = $Visual

var _engine_audio: AudioStreamPlayer3D


static func spawn(p_character: CharacterDef, p_kart: KartDef) -> KartController:
	var node: KartController = (load(SCENE) as PackedScene).instantiate()
	node.character = p_character
	node.kart_def = p_kart
	return node


func _ready() -> void:
	if character == null or kart_def == null:
		push_error("KartController: spawn() me with a character and kart def")
		return
	top_speed = kart_def.top_speed * character.speed_mod
	acceleration = kart_def.acceleration * character.accel_mod
	braking = kart_def.braking
	reverse_speed = kart_def.reverse_speed
	steer_speed = kart_def.steer_speed * character.handling_mod
	steer_falloff = kart_def.steer_speed_falloff
	weight = character.weight
	visual.setup(character, kart_def)

	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.stream = SoundFx.engine_loop
	_engine_audio.unit_size = 5.0
	_engine_audio.volume_db = -28.0
	# Slight pitch personality + random phase so six karts don't comb.
	_engine_audio.pitch_scale = randf_range(0.96, 1.04)
	add_child(_engine_audio)
	_engine_audio.play(randf() * 0.4)


func _physics_process(delta: float) -> void:
	var steer := input_steer
	var throttle := input_throttle
	var brake := input_brake
	if not control_enabled or spin_timer > 0.0:
		steer = 0.0
		throttle = 0.0
		brake = 0.0

	if spin_timer > 0.0:
		spin_timer -= delta
		speed = move_toward(speed, 0.0, braking * 1.5 * delta)

	_update_drift(steer, delta)
	_update_boost(delta)

	# Steering. Authority scales with speed (no turning in place) and
	# reverses in reverse. Falloff reduces steering near top speed.
	var authority := clampf(speed / 5.0, -1.0, 1.0)
	var eff := steer_speed * (1.0 - steer_falloff * clampf(absf(speed) / top_speed, 0.0, 1.0))
	if drift_dir != 0:
		# Map steer so even countersteering keeps turning into the drift.
		var t := (steer * drift_dir + 1.0) * 0.5
		eff *= lerpf(kart_def.drift_steer_min, kart_def.drift_steer_max, t)
		rotate_y(-eff * drift_dir * absf(authority) * delta)
	else:
		rotate_y(-eff * steer * authority * delta)

	# Longitudinal speed.
	var cur_top := top_speed * boost_top_mult
	if boost_timer > 0.0:
		speed = move_toward(speed, cur_top, acceleration * 3.0 * delta)
	elif throttle > 0.0:
		if speed > cur_top:
			speed = move_toward(speed, cur_top, acceleration * 0.5 * delta)
		else:
			speed = move_toward(speed, cur_top * throttle, acceleration * delta)
	elif brake > 0.0:
		speed = move_toward(speed, -reverse_speed * brake, braking * delta)
	else:
		speed = move_toward(speed, 0.0, acceleration * 0.6 * delta)

	# Travel direction lags the heading while drifting.
	var travel := -global_transform.basis.z
	if drift_dir != 0:
		travel = travel.rotated(Vector3.UP, DRIFT_SLIP * drift_dir)
	var vy := velocity.y - GRAVITY * delta
	velocity = travel * speed
	velocity.y = vy
	if is_on_floor() and vy < 0.0:
		velocity.y = -0.1

	move_and_slide()

	# Wall impacts kill speed instead of letting the body grind along.
	var real := get_real_velocity()
	real.y = 0.0
	var actual := real.length() * signf(speed)
	if absf(actual) < absf(speed) - 1.0:
		speed = lerpf(speed, actual, 0.6)

	_update_sprite()
	_update_engine_audio()


func _update_engine_audio() -> void:
	if _engine_audio == null:
		return
	var rev := clampf(absf(speed) / top_speed, 0.0, 1.3)
	_engine_audio.pitch_scale = 0.8 + rev * 1.1
	_engine_audio.volume_db = lerpf(-28.0, -14.0, minf(rev, 1.0))


func _update_drift(steer: float, delta: float) -> void:
	var can_drift := control_enabled and spin_timer <= 0.0
	if input_drift_pressed and can_drift and drift_dir == 0 \
			and is_on_floor() and absf(steer) > 0.1 \
			and speed > top_speed * 0.4:
		drift_dir = 1 if steer > 0.0 else -1
		drift_charge = 0.0
		velocity.y = HOP_IMPULSE
		SoundFx.play_3d("hop", global_position)
	input_drift_pressed = false

	if drift_dir != 0:
		drift_charge += delta
		if not input_drift_held or speed < top_speed * 0.25 or not can_drift:
			if drift_charge >= kart_def.mini_turbo_threshold and can_drift:
				apply_boost(kart_def.boost_strength, kart_def.boost_duration)
			drift_dir = 0
			drift_charge = 0.0


func _update_boost(delta: float) -> void:
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_top_mult = 1.0


func _update_sprite() -> void:
	if spin_timer > 0.0:
		visual.anim = "spin"
	elif drift_dir != 0:
		visual.anim = "drift_l" if drift_dir < 0 else "drift_r"
	elif absf(speed) > 0.5:
		visual.anim = "drive"
		visual.speed_scale = clampf(absf(speed) / top_speed * 1.5, 0.5, 1.8)
	else:
		visual.anim = "idle"
		visual.speed_scale = 1.0


## Mushrooms and mini-turbos.
func apply_boost(strength: float, duration: float) -> void:
	boost_top_mult = strength
	boost_timer = duration
	SoundFx.play_3d("boost", global_position)
	boost_started.emit()


## Shell hits etc. Heavier characters recover slightly faster.
func spin_out() -> void:
	if spin_timer > 0.0:
		return
	spin_timer = SPIN_DURATION / clampf(weight, 0.75, 1.5)
	drift_dir = 0
	drift_charge = 0.0
	boost_timer = 0.0
	boost_top_mult = 1.0
	SoundFx.play_3d("spin", global_position)
	spun_out.emit()


func respawn_at(xform: Transform3D) -> void:
	global_transform = xform
	velocity = Vector3.ZERO
	speed = 0.0
	drift_dir = 0
	drift_charge = 0.0
	spin_timer = 0.0


func speed_kmh() -> float:
	return absf(speed) * 3.6


func is_drifting() -> bool:
	return drift_dir != 0
