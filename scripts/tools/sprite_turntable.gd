extends Node3D
## Dev scene: one composed kart+rider billboard at the origin, camera
## orbiting around it. Used to verify the 8-direction frame selection
## and the rider's seat placement on every kart.
## Drive from MCP/game_eval: set_orbit(deg), set_anim(name),
## set_character(id), set_kart(id), get_state().

@export var character_id: StringName = &"rosso"
@export var kart_id: StringName = &"standard"
@export var auto_orbit: bool = false
@export var orbit_speed_deg: float = 20.0

var orbit_deg: float = 0.0
var _visual: KartVisual
var _kart_root: Node3D
var _cam: Camera3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6a89b5")
	add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	add_child(light)

	var ground := CSGBox3D.new()
	ground.size = Vector3(20, 0.2, 20)
	ground.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a6a4a")
	ground.material = mat
	add_child(ground)

	_kart_root = Node3D.new()
	_kart_root.name = "Kart"
	add_child(_kart_root)
	_visual = KartVisual.new()
	_visual.facing_node = _kart_root
	_kart_root.add_child(_visual)

	_cam = Camera3D.new()
	add_child(_cam)
	_update_camera()
	_cam.make_current()

	_apply()


func _process(delta: float) -> void:
	if auto_orbit:
		orbit_deg = wrapf(orbit_deg + orbit_speed_deg * delta, 0.0, 360.0)
	_update_camera()


func _update_camera() -> void:
	var th := deg_to_rad(orbit_deg)
	_cam.position = Vector3(sin(th) * 5.0, 2.2, cos(th) * 5.0)
	_cam.look_at(Vector3(0, 0.7, 0))


func set_orbit(deg: float) -> void:
	auto_orbit = false
	orbit_deg = wrapf(deg, 0.0, 360.0)
	_update_camera()


func set_anim(anim: String) -> void:
	_visual.anim = anim


func set_character(id: StringName) -> bool:
	if Registry.get_character(id) == null:
		push_error("Turntable: unknown character '%s'" % id)
		return false
	character_id = id
	_apply()
	return true


func set_kart(id: StringName) -> bool:
	if Registry.get_kart(id) == null:
		push_error("Turntable: unknown kart '%s'" % id)
		return false
	kart_id = id
	_apply()
	return true


func _apply() -> void:
	var character: CharacterDef = Registry.get_character(character_id)
	var kart: KartDef = Registry.get_kart(kart_id)
	if character == null or kart == null:
		push_error("Turntable: missing character or kart def")
		return
	var anim := _visual.anim
	_visual.setup(character, kart)
	_visual.anim = anim if anim != "" else "idle"


## Camera at orbit angle th means expected dir = DIRS[wrap(-th)/45].
func get_state() -> Dictionary:
	var expected: String = BillboardSprite.DIRS[int(round(wrapf(-orbit_deg, 0.0, 360.0) / 45.0)) % 8]
	return {
		"character": character_id,
		"kart": kart_id,
		"anim": _visual.anim,
		"orbit_deg": orbit_deg,
		"shown_dir": _visual.kart_layer._dir,
		"rider_dir": _visual.rider_layer._dir,
		"expected_dir": expected,
		"kart_flip": _visual.kart_layer.flip_h,
		"rider_flip": _visual.rider_layer.flip_h,
		"kart_region": _visual.kart_layer.region_rect,
		"rider_region": _visual.rider_layer.region_rect,
		"rider_pos": _visual.rider_layer.global_position,
	}
