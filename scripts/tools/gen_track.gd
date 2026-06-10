extends SceneTree
## Headless placeholder track generator. Run from the project root:
##   godot --headless --path . --script res://scripts/tools/gen_track.gd
##
## Builds assets/tracks/test_oval/test_oval.tscn satisfying the track node
## contract (TrackGeometry, Checkpoints, StartGrid, ItemBoxes, AIPath) and
## writes the matching TrackDef .tres. The road and walls are CSGPolygon3D
## strips extruded along the same closed curve the AI follows.

const TRACK_DIR := "res://assets/tracks/test_oval"
const ROAD_HALF_WIDTH := 7.0
const WALL_HEIGHT := 1.2
const N_CHECKPOINTS := 10
const N_GRID := 8
const HANDLE := 8.28  # bezier handle for a 15m-radius quarter arc (0.5523 * r)

# Rounded-rectangle centerline, in travel order (counterclockwise from
# above; start/finish at mid south straight heading +X).
const POINTS := [
	{"p": Vector3(0, 0, 25), "t": Vector3(1, 0, 0)},
	{"p": Vector3(25, 0, 25), "t": Vector3(1, 0, 0)},
	{"p": Vector3(40, 0, 10), "t": Vector3(0, 0, -1)},
	{"p": Vector3(40, 0, -10), "t": Vector3(0, 0, -1)},
	{"p": Vector3(25, 0, -25), "t": Vector3(-1, 0, 0)},
	{"p": Vector3(-25, 0, -25), "t": Vector3(-1, 0, 0)},
	{"p": Vector3(-40, 0, -10), "t": Vector3(0, 0, 1)},
	{"p": Vector3(-40, 0, 10), "t": Vector3(0, 0, 1)},
	{"p": Vector3(-25, 0, 25), "t": Vector3(1, 0, 0)},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(TRACK_DIR)
	var root := Node3D.new()
	root.name = "TestOval"

	var curve := Curve3D.new()
	curve.closed = true
	for e in POINTS:
		curve.add_point(e.p, -e.t * HANDLE, e.t * HANDLE)

	var ai_path := Path3D.new()
	ai_path.name = "AIPath"
	ai_path.curve = curve
	root.add_child(ai_path)

	root.add_child(_build_geometry())
	root.add_child(_build_checkpoints(curve))
	root.add_child(_build_start_grid())
	root.add_child(_build_item_boxes())

	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("gen_track: pack failed (%d)" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, TRACK_DIR.path_join("test_oval.tscn"))
	if err != OK:
		push_error("gen_track: save failed (%d)" % err)
		quit(1)
		return

	var f := FileAccess.open(TRACK_DIR.path_join("test_oval.tres"), FileAccess.WRITE)
	f.store_string("""[gd_resource type="Resource" script_class="TrackDef" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/defs/track_def.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/tracks/test_oval/test_oval.tscn" id="2"]

[resource]
script = ExtResource("1")
id = &"test_oval"
display_name = "Test Oval"
scene = ExtResource("2")
laps = 3
kill_y = -10.0
""")
	f.close()
	print("gen_track: wrote test_oval (curve length %.1fm)" % curve.get_baked_length())
	quit()


func _build_geometry() -> Node3D:
	var geo := Node3D.new()
	geo.name = "TrackGeometry"

	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(220, 1, 160)
	ground.position = Vector3(0, -1.0, 0)
	ground.use_collision = true
	ground.material = _mat(Color("4a6a4a"))
	geo.add_child(ground)

	geo.add_child(_path_strip("Road", [
		Vector2(-ROAD_HALF_WIDTH, -0.5), Vector2(ROAD_HALF_WIDTH, -0.5),
		Vector2(ROAD_HALF_WIDTH, 0.0), Vector2(-ROAD_HALF_WIDTH, 0.0),
	], Color("555560")))
	geo.add_child(_path_strip("WallOuter", [
		Vector2(ROAD_HALF_WIDTH, -0.5), Vector2(ROAD_HALF_WIDTH + 1.0, -0.5),
		Vector2(ROAD_HALF_WIDTH + 1.0, WALL_HEIGHT), Vector2(ROAD_HALF_WIDTH, WALL_HEIGHT),
	], Color("b04040")))
	geo.add_child(_path_strip("WallInner", [
		Vector2(-ROAD_HALF_WIDTH - 1.0, -0.5), Vector2(-ROAD_HALF_WIDTH, -0.5),
		Vector2(-ROAD_HALF_WIDTH, WALL_HEIGHT), Vector2(-ROAD_HALF_WIDTH - 1.0, WALL_HEIGHT),
	], Color("b04040")))

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.shadow_enabled = true
	geo.add_child(light)

	var env := WorldEnvironment.new()
	env.name = "Env"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6a89b5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.environment.ambient_light_energy = 0.6
	geo.add_child(env)
	return geo


func _path_strip(strip_name: String, polygon: Array, color: Color) -> CSGPolygon3D:
	var csg := CSGPolygon3D.new()
	csg.name = strip_name
	csg.mode = CSGPolygon3D.MODE_PATH
	# Resolved relative to the CSG node once instanced.
	csg.path_node = NodePath("../../AIPath")
	csg.path_interval = 1.0
	csg.path_simplify_angle = 1.0
	csg.polygon = PackedVector2Array(polygon)
	csg.path_joined = true
	csg.use_collision = true
	csg.collision_layer = 1
	csg.material = _mat(color)
	return csg


func _build_checkpoints(curve: Curve3D) -> Node3D:
	var parent := Node3D.new()
	parent.name = "Checkpoints"
	var length := curve.get_baked_length()
	for i in N_CHECKPOINTS:
		var offset := length * float(i) / N_CHECKPOINTS
		var pos := curve.sample_baked(offset)
		var ahead := curve.sample_baked(fmod(offset + 1.0, length))
		var tangent := (ahead - pos).normalized()
		var area := Area3D.new()
		area.name = "Checkpoint%d" % i
		area.collision_layer = 4   # trigger
		area.collision_mask = 2    # karts
		area.monitoring = true
		area.basis = Basis.looking_at(tangent)
		area.position = pos
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0 * (ROAD_HALF_WIDTH + 2.0), 6.0, 2.0)
		shape.shape = box
		shape.position = Vector3(0, 2, 0)
		area.add_child(shape)
		parent.add_child(area)
	return parent


func _build_start_grid() -> Node3D:
	var grid := Node3D.new()
	grid.name = "StartGrid"
	for i in N_GRID:
		var m := Marker3D.new()
		m.name = "Slot%d" % i
		var row := i / 2
		var side := 3.0 if i % 2 == 0 else -3.0
		m.position = Vector3(-5.0 - row * 3.0, 0.0, 25.0 + side)
		m.rotation_degrees = Vector3(0, -90, 0)  # -Z faces +X = travel direction
		grid.add_child(m)
	return grid


func _build_item_boxes() -> Node3D:
	var boxes := Node3D.new()
	boxes.name = "ItemBoxes"
	var spots := [
		Vector3(0, 0, -29), Vector3(0, 0, -25), Vector3(0, 0, -21),  # north straight
		Vector3(-44, 0, 0), Vector3(-40, 0, 0), Vector3(-36, 0, 0),  # west straight
	]
	for i in spots.size():
		var m := Marker3D.new()
		m.name = "Box%d" % i
		m.position = spots[i]
		boxes.add_child(m)
	return boxes


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child, root)
