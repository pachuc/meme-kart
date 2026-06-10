extends Node3D
## Dev scene: one billboard kart sprite at the origin, camera orbiting
## around it. Used to verify the 8-direction frame selection.
## Drive from MCP/game_eval: set_orbit(deg), set_anim(name),
## set_character(id), get_state().

@export var character_id: StringName = &"rosso"
@export var auto_orbit: bool = false
@export var orbit_speed_deg: float = 20.0

var orbit_deg: float = 0.0
var _sprite: BillboardSprite
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
	_sprite = BillboardSprite.new()
	_kart_root.add_child(_sprite)

	_cam = Camera3D.new()
	add_child(_cam)
	_update_camera()
	_cam.make_current()

	set_character(character_id)


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
	_sprite.anim = anim


func set_character(id: StringName) -> bool:
	var def: CharacterDef = Registry.get_character(id)
	if def == null:
		push_error("Turntable: unknown character '%s'" % id)
		return false
	character_id = id
	_sprite.setup(def)
	_sprite.anim = "idle"
	return true


## Camera at orbit angle th means expected dir = DIRS[wrap(-th)/45].
func get_state() -> Dictionary:
	var expected: String = BillboardSprite.DIRS[int(round(wrapf(-orbit_deg, 0.0, 360.0) / 45.0)) % 8]
	return {
		"character": character_id,
		"anim": _sprite.anim,
		"orbit_deg": orbit_deg,
		"shown_dir": _sprite._dir,
		"expected_dir": expected,
		"flip_h": _sprite.flip_h,
		"region": _sprite.region_rect,
	}
