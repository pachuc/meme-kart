class_name ShellProjectile
extends Area3D
## Green-shell-style projectile: travels flat and straight, bounces off
## walls, spins out the first kart it touches. The thrower is immune for
## a short grace period so it doesn't hit itself leaving the kart.

const SPEED := 26.0
const LIFETIME := 10.0
const OWNER_GRACE := 0.6

var dir := Vector3.FORWARD
var _thrower: KartController
var _grace: float = OWNER_GRACE
var _life: float = LIFETIME


func launch(from_kart: KartController, pos: Vector3, direction: Vector3) -> void:
	_thrower = from_kart
	global_position = pos
	dir = direction.normalized()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_life -= delta
	_grace -= delta
	if _life <= 0.0:
		queue_free()
		return
	var motion := dir * SPEED * delta
	# Wall bounce: probe the world layer slightly past this step.
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position + motion + dir * 0.5, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		dir = dir.bounce(hit.normal)
		dir.y = 0.0
		dir = dir.normalized()
	else:
		global_position += motion


func _on_body_entered(body: Node3D) -> void:
	if body is KartController:
		if body == _thrower and _grace > 0.0:
			return
		body.spin_out()
		queue_free()
