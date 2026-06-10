class_name ChaseCamera
extends Camera3D
## MK64-style follow camera: trails the kart's heading with smoothed yaw,
## fixed distance and height.

@export var target: Node3D
@export var distance: float = 5.0
@export var height: float = 2.2
@export var look_height: float = 0.9
@export var yaw_smoothing: float = 5.0

var _yaw: float = 0.0


func snap_to_target() -> void:
	if target != null:
		_yaw = target.global_rotation.y
		_update_position(true)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_yaw = lerp_angle(_yaw, target.global_rotation.y, 1.0 - exp(-yaw_smoothing * delta))
	_update_position(false)


func _update_position(_snap: bool) -> void:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))  # behind a kart facing -Z at yaw
	global_position = target.global_position + back * distance + Vector3.UP * height
	look_at(target.global_position + Vector3.UP * look_height)
