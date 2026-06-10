class_name BillboardSprite
extends Sprite3D
## MK64-style 8-direction billboard. Shows the frame of the current
## animation matching the camera-relative yaw of `facing_node` (the kart).
##
## Direction sectors, by (kart_yaw - camera_yaw): 0 deg = "n" (back view,
## camera behind kart), 90 deg = kart pointing screen-left = "w", etc.

const DIRS := ["n", "nw", "w", "sw", "s", "se", "e", "ne"]

## Node whose -Z heading the sprite direction is computed from.
## Defaults to the parent.
@export var facing_node: Node3D

## Current animation: idle | drive | drift_l | drift_r | spin.
var anim: String = "idle":
	set(value):
		if anim != value:
			anim = value
			_frame = 0
			_time_ms = 0.0
var speed_scale: float = 1.0

var _sheet: AsepriteSheet
var _frames: Array = []
var _flip := false
var _dir := "n"
var _resolved_key := ""
var _frame := 0
var _time_ms := 0.0


## One billboard layer showing one sheet (a kart or a rider). The caller
## owns placement; a frame's bottom edge sits at position.y - half_height_m().
func setup(json: JSON, sheet_texture: Texture2D, p_pixel_size: float) -> void:
	_sheet = AsepriteSheet.load_sheet(json)
	texture = sheet_texture
	pixel_size = p_pixel_size
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	region_enabled = true
	# Sheets bake a blob shadow; a real projected sprite shadow on top
	# looks wrong, MK64 style is shadowless billboards.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_resolved_key = ""
	_refresh()


## World half-height of one frame in meters (Sprite3D draws centered).
func half_height_m() -> float:
	if _sheet == null:
		return 0.0
	return _sheet.frame_size.y * pixel_size * 0.5


func _ready() -> void:
	if facing_node == null:
		facing_node = get_parent_node_3d()


func _process(delta: float) -> void:
	if _sheet == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null and facing_node != null:
		var f := -facing_node.global_transform.basis.z
		var c := -cam.global_transform.basis.z
		var rel := wrapf(rad_to_deg(atan2(f.x, f.z) - atan2(c.x, c.z)), 0.0, 360.0)
		_dir = DIRS[int(round(rel / 45.0)) % 8]
	_refresh()
	if _frames.is_empty():
		return
	_time_ms += delta * 1000.0 * speed_scale
	while _time_ms >= float(_frames[_frame].duration):
		_time_ms -= float(_frames[_frame].duration)
		_frame = (_frame + 1) % _frames.size()
	region_rect = _frames[_frame].rect
	flip_h = _flip


func _refresh() -> void:
	var key := "%s|%s" % [anim, _dir]
	if key == _resolved_key or _sheet == null:
		return
	_resolved_key = key
	var res := _sheet.get_anim(anim, _dir)
	_frames = res.frames
	_flip = res.flip_h
	# Keep frame phase when only the view direction changed.
	_frame = _frame % maxi(_frames.size(), 1)
	if not _frames.is_empty():
		region_rect = _frames[_frame].rect
		flip_h = _flip
