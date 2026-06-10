extends Node3D
## Dev scene: flat ground with walls and a player-controlled kart.
## Used to tune/verify driving feel before tracks exist.


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6a89b5")
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	add_child(light)

	_static_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0), Color("4a6a4a"))   # ground
	_static_box(Vector3(120, 3, 1), Vector3(0, 1.5, -60), Color("777777"))    # walls
	_static_box(Vector3(120, 3, 1), Vector3(0, 1.5, 60), Color("777777"))
	_static_box(Vector3(1, 3, 120), Vector3(-60, 1.5, 0), Color("777777"))
	_static_box(Vector3(1, 3, 120), Vector3(60, 1.5, 0), Color("777777"))
	_static_box(Vector3(4, 2, 4), Vector3(0, 1, -20), Color("8a6a3a"))        # obstacle

	var kart := KartController.spawn(Registry.get_characters()[0], Registry.get_karts()[0])
	kart.name = "PlayerKart"
	add_child(kart)
	kart.position = Vector3(0, 0.5, 0)
	kart.control_enabled = true
	kart.add_child(PlayerInput.new())

	var cam := ChaseCamera.new()
	cam.target = kart
	add_child(cam)
	cam.make_current()
	cam.snap_to_target()


func _static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.position = pos
	box.use_collision = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	add_child(box)


func get_kart() -> KartController:
	return $PlayerKart
