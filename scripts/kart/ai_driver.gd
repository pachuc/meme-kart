class_name AIDriver
extends Node
## CPU driver: steers the parent kart toward a lookahead point on the
## track's AIPath curve. Personality knobs (lookahead, skill) give each
## opponent slightly different lines and pace.

var path: Path3D
## Meters ahead on the curve to aim for. Lower = tighter lines.
var lookahead: float = 8.0
## Throttle cap (0..1). Slightly below 1 keeps AI beatable.
var skill: float = 1.0

@onready var kart: KartController = get_parent()


static func attach(to_kart: KartController, ai_path: Path3D, rng: RandomNumberGenerator) -> AIDriver:
	var driver := AIDriver.new()
	driver.path = ai_path
	driver.lookahead = rng.randf_range(7.0, 10.0)
	driver.skill = rng.randf_range(0.88, 1.0)
	to_kart.add_child(driver)
	return driver


func _physics_process(delta: float) -> void:
	if path == null or kart == null:
		return
	var curve := path.curve
	var length := curve.get_baked_length()
	var offset := curve.get_closest_offset(path.to_local(kart.global_position))
	var target := path.to_global(curve.sample_baked(fmod(offset + lookahead, length)))

	var to_target := target - kart.global_position
	to_target.y = 0.0
	var forward := -kart.global_transform.basis.z
	forward.y = 0.0
	# Positive signed angle = target is counterclockwise (left); steering
	# right is positive input, so flip the sign.
	var angle := forward.signed_angle_to(to_target, Vector3.UP)
	kart.input_steer = clampf(-angle * 2.5, -1.0, 1.0)
	# Ease off the throttle in sharp turns.
	kart.input_throttle = skill * (1.0 - clampf(absf(angle) * 0.6, 0.0, 0.45))
	kart.input_brake = 0.0
	_maybe_use_item(delta)


var _item_delay: float = -1.0

func _maybe_use_item(delta: float) -> void:
	var holder: ItemHolder = kart.get_node_or_null("ItemHolder")
	if holder == null or holder.item == ItemHolder.Item.NONE:
		_item_delay = -1.0
		return
	if _item_delay < 0.0:
		_item_delay = randf_range(0.5, 2.5)
	_item_delay -= delta
	if _item_delay <= 0.0:
		holder.use()
		_item_delay = -1.0
