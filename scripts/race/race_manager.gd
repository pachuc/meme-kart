class_name RaceManager
extends Node3D
## Owns a race: instantiates the selected track, validates the track node
## contract, spawns karts on the grid, runs countdown -> racing -> results,
## and tracks per-kart checkpoint/lap progress and ranking.

enum Phase { LOADING, COUNTDOWN, RACING, FINISHED }

const CONTRACT_NODES := ["TrackGeometry", "Checkpoints", "StartGrid", "ItemBoxes", "AIPath"]
const COUNTDOWN_SECONDS := 3
const AI_COUNT := 5

var phase: int = Phase.LOADING
var track_def: TrackDef
var track: Node3D
var checkpoints: Array = []      # Area3D, in order; [0] = finish line
var grid_markers: Array = []     # Marker3D
var item_markers: Array = []     # Marker3D
var ai_path: Path3D
var karts: Array = []            # KartController
var player: KartController
var progress: Dictionary = {}    # KartController -> progress dict
var race_time: float = 0.0
var finish_order: Array = []     # KartController, in finishing order

var _countdown_left: float = 0.0
var _wrong_way_time: float = 0.0

@onready var hud: RaceHud = $HUD


func _ready() -> void:
	if not Game.ensure_selections():
		push_error("RaceManager: registry is missing assets, cannot start")
		return
	track_def = Game.selected_track
	track = track_def.scene.instantiate()
	add_child(track)
	if not _collect_contract_nodes():
		return
	_spawn_item_boxes()
	_spawn_karts()
	hud.rematch_pressed.connect(func(): Game.goto(&"race"))
	hud.menu_pressed.connect(func(): Game.goto(&"menu"))
	hud.set_lap(1, track_def.laps)
	hud.set_rank(1, karts.size())
	if track_def.music != null:
		SoundFx.play_music(track_def.music)
	phase = Phase.COUNTDOWN
	_countdown_left = float(COUNTDOWN_SECONDS) + 0.5  # small hold before "3"


func _collect_contract_nodes() -> bool:
	for node_name in CONTRACT_NODES:
		if not track.has_node(node_name):
			push_error("Track contract violation: '%s' is missing required child '%s' (see README)" % [track.name, node_name])
			return false
	for cp in track.get_node("Checkpoints").get_children():
		if cp is Area3D:
			cp.body_entered.connect(_on_checkpoint_entered.bind(checkpoints.size()))
			checkpoints.append(cp)
	grid_markers = track.get_node("StartGrid").get_children()
	item_markers = track.get_node("ItemBoxes").get_children()
	ai_path = track.get_node("AIPath")
	if checkpoints.size() < 3:
		push_error("Track contract violation: need at least 3 checkpoints, found %d" % checkpoints.size())
		return false
	if grid_markers.is_empty():
		push_error("Track contract violation: StartGrid has no markers")
		return false
	return true


func _spawn_item_boxes() -> void:
	var box_scene: PackedScene = load("res://scenes/items/item_box.tscn")
	for marker in item_markers:
		var box: ItemBox = box_scene.instantiate()
		add_child(box)
		box.global_transform = marker.global_transform


func _spawn_karts() -> void:
	# Player starts at the back of the grid, MK64 style (also keeps the
	# chase camera clear of the pack).
	var ai_total: int = mini(AI_COUNT, grid_markers.size() - 1)
	player = _add_kart(Game.selected_character, Game.selected_kart, ai_total)
	player.name = "PlayerKart"
	player.add_child(PlayerInput.new())
	var player_holder: ItemHolder = player.get_node("ItemHolder")
	player_holder.is_player = true
	player_holder.changed.connect(func(item: int): hud.set_item(ItemHolder.icon(item)))

	var cam := ChaseCamera.new()
	cam.target = player
	add_child(cam)
	cam.make_current()
	cam.snap_to_target()

	# AI opponents: round-robin through the registry, offset so the first
	# AI differs from the player's pick when possible.
	var chars: Array = Registry.get_characters()
	var kart_defs: Array = Registry.get_karts()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("meme-kart-ai")
	var seen_names: Dictionary = {}
	seen_names[Game.selected_character.display_name] = 1
	for i in ai_total:
		var character: CharacterDef = chars[(chars.find(Game.selected_character) + 1 + i) % chars.size()]
		var kart_def: KartDef = kart_defs[i % kart_defs.size()]
		var ai := _add_kart(character, kart_def, i)
		var count: int = seen_names.get(character.display_name, 0) + 1
		seen_names[character.display_name] = count
		progress[ai].display_name = character.display_name if count == 1 else "%s %d" % [character.display_name, count]
		ai.name = "AIKart%d" % i
		AIDriver.attach(ai, ai_path, rng)


func _add_kart(character: CharacterDef, kart_def: KartDef, grid_idx: int) -> KartController:
	var kart := KartController.spawn(character, kart_def)
	add_child(kart)
	if grid_idx < grid_markers.size():
		kart.global_transform = grid_markers[grid_idx].global_transform
	var holder := ItemHolder.new()
	holder.name = "ItemHolder"
	kart.add_child(holder)
	karts.append(kart)
	progress[kart] = {
		"next_cp": 0,
		"cps_passed": 0,
		"lap": 1,
		"respawn": kart.global_transform,
		"finished": false,
		"finish_time": -1.0,
		"display_name": character.display_name,
	}
	return kart


func _physics_process(delta: float) -> void:
	match phase:
		Phase.COUNTDOWN:
			_tick_countdown(delta)
		Phase.RACING, Phase.FINISHED:
			race_time += delta
			_tick_race(delta)


func _tick_countdown(delta: float) -> void:
	_countdown_left -= delta
	if _countdown_left > 0.0:
		var n := ceili(_countdown_left - 0.5)
		var text := str(n) if n >= 1 else "GO!"
		if text != _last_countdown_text and n >= 1:
			SoundFx.play("count")
		_last_countdown_text = text
		hud.set_countdown(text)
		return
	hud.set_countdown("GO!")
	SoundFx.play("go")
	get_tree().create_timer(0.8).timeout.connect(func(): hud.set_countdown(""))
	for kart in karts:
		kart.control_enabled = true
	phase = Phase.RACING


var _last_countdown_text := ""


func _tick_race(delta: float) -> void:
	for kart in karts:
		if kart.global_position.y < track_def.kill_y:
			kart.respawn_at(progress[kart].respawn)
	if player == null or progress[player].finished:
		return
	var pr: Dictionary = progress[player]
	hud.set_lap(pr.lap, track_def.laps)
	hud.set_rank(get_rank(player), karts.size())
	hud.set_speed(player.speed_kmh())
	hud.set_timer(race_time)
	_check_wrong_way(delta)


func _check_wrong_way(delta: float) -> void:
	var local := ai_path.to_local(player.global_position)
	var offset := ai_path.curve.get_closest_offset(local)
	var length := ai_path.curve.get_baked_length()
	var tangent := (ai_path.curve.sample_baked(fmod(offset + 1.0, length)) - ai_path.curve.sample_baked(offset)).normalized()
	var forward := -player.global_transform.basis.z
	if player.speed > 3.0 and forward.dot(tangent) < -0.3:
		_wrong_way_time += delta
	else:
		_wrong_way_time = 0.0
	hud.set_wrong_way(_wrong_way_time > 0.7)


func _on_checkpoint_entered(body: Node3D, cp_index: int) -> void:
	if not progress.has(body):
		return
	var pr: Dictionary = progress[body]
	if pr.finished or cp_index != pr.next_cp:
		return
	pr.cps_passed += 1
	pr.next_cp = (cp_index + 1) % checkpoints.size()
	pr.respawn = checkpoints[cp_index].global_transform
	if cp_index == 0 and pr.cps_passed > 1:
		pr.lap += 1
		if pr.lap > track_def.laps:
			_finish(body)


func _finish(kart: KartController) -> void:
	var pr: Dictionary = progress[kart]
	pr.finished = true
	pr.finish_time = race_time
	finish_order.append(kart)
	if kart == player:
		kart.control_enabled = false
		phase = Phase.FINISHED
		SoundFx.play("finish")
		hud.set_countdown("FINISH!")
		get_tree().create_timer(1.5).timeout.connect(func():
			hud.set_countdown("")
			hud.show_results(build_results())
		)


## Total race progress, larger = further ahead. Checkpoints passed,
## tie-broken by how close the kart is to its next checkpoint.
func progress_metric(kart: KartController) -> float:
	var pr: Dictionary = progress[kart]
	var next_pos: Vector3 = checkpoints[pr.next_cp].global_position
	var dist: float = kart.global_position.distance_to(next_pos)
	return float(pr.cps_passed) + 1.0 / (1.0 + dist)


func get_rank(kart: KartController) -> int:
	if progress[kart].finished:
		return finish_order.find(kart) + 1
	var rank := finish_order.size() + 1
	var mine := progress_metric(kart)
	for other in karts:
		if other != kart and not progress[other].finished and progress_metric(other) > mine:
			rank += 1
	return rank


func build_results() -> Array:
	var rows: Array = []
	for kart in finish_order:
		rows.append({
			"rank": rows.size() + 1,
			"name": progress[kart].display_name,
			"time": progress[kart].finish_time,
			"is_player": kart == player,
		})
	var unfinished := karts.filter(func(k): return not progress[k].finished)
	unfinished.sort_custom(func(a, b): return progress_metric(a) > progress_metric(b))
	for kart in unfinished:
		rows.append({
			"rank": rows.size() + 1,
			"name": progress[kart].display_name,
			"time": -1.0,
			"is_player": kart == player,
		})
	return rows
