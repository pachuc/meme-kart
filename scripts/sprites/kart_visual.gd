class_name KartVisual
extends Node3D
## The complete visual for one kart on track: a kart billboard layer plus
## a rider billboard layer composited at the kart's seat anchor, so any
## CharacterDef can ride any KartDef. Drive it like a single sprite via
## `anim` and `speed_scale`.

## Node whose -Z heading the view direction is computed from.
## Defaults to the parent (the KartController body).
@export var facing_node: Node3D

var anim: String = "idle":
	set(value):
		anim = value
		if kart_layer != null:
			kart_layer.anim = value
			rider_layer.anim = value
var speed_scale: float = 1.0:
	set(value):
		speed_scale = value
		if kart_layer != null:
			kart_layer.speed_scale = value
			rider_layer.speed_scale = value

var kart_layer: BillboardSprite
var rider_layer: BillboardSprite

var _kart_def: KartDef
var _character: CharacterDef


func setup(character: CharacterDef, kart_def: KartDef) -> void:
	_character = character
	_kart_def = kart_def
	if kart_layer == null:
		kart_layer = BillboardSprite.new()
		kart_layer.name = "KartLayer"
		add_child(kart_layer)
		rider_layer = BillboardSprite.new()
		rider_layer.name = "RiderLayer"
		add_child(rider_layer)
	if facing_node == null:
		facing_node = get_parent_node_3d()
	kart_layer.facing_node = facing_node
	rider_layer.facing_node = facing_node
	kart_layer.setup(kart_def.aseprite_json, kart_def.sprite_sheet, kart_def.sprite_pixel_size)
	rider_layer.setup(character.aseprite_json, character.sprite_sheet, character.sprite_pixel_size)
	kart_layer.position.y = kart_def.sprite_y_offset + kart_layer.half_height_m()
	kart_layer.anim = anim
	rider_layer.anim = anim
	_place_rider()


func _process(_delta: float) -> void:
	_place_rider()


## Bottom-center of the rider frame goes at the kart's seat anchor. The
## anchor is given in the kart sprite's plane, so its x maps to the
## camera-right axis (the billboard plane), not the body's local axes.
func _place_rider() -> void:
	if _kart_def == null or rider_layer == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := -facing_node.global_transform.basis.z
	var c := -cam.global_transform.basis.z
	var rel := wrapf(rad_to_deg(atan2(f.x, f.z) - atan2(c.x, c.z)), 0.0, 360.0)
	var dir: String = BillboardSprite.DIRS[int(round(rel / 45.0)) % 8]
	var seat := _kart_def.seat_px(dir) * _kart_def.sprite_pixel_size

	var right := cam.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var toward_cam := cam.global_position - global_position
	toward_cam.y = 0.0
	if toward_cam.length_squared() < 0.0001:
		toward_cam = -c
	var y := _kart_def.sprite_y_offset + seat.y + rider_layer.half_height_m()
	rider_layer.global_position = global_position \
		+ right.normalized() * seat.x \
		+ Vector3.UP * y \
		+ toward_cam.normalized() * 0.05  # in front of the kart layer, no z-fight
