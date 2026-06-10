class_name ItemHolder
extends Node
## Per-kart item slot: roulette on pickup, one held item, use on demand.
## Added to every kart by RaceManager. Listens for the kart's
## input_item_pressed flag (set by PlayerInput or AIDriver).

enum Item { NONE, MUSHROOM, SHELL }

signal changed(item: int)

const SHELL_SCENE := "res://scenes/items/shell_projectile.tscn"
const ROULETTE_TIME := 1.0
const ROULETTE_STEP := 0.08

static var _icons: Dictionary = {}

var item: int = Item.NONE
var rolling: bool = false
## Set by RaceManager; gates the roulette tick sounds to the player.
var is_player: bool = false

var _roll_left: float = 0.0
var _step_left: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var kart: KartController = get_parent()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if rolling:
		_roll_left -= delta
		_step_left -= delta
		if _roll_left <= 0.0:
			rolling = false
			item = _rng.randi_range(1, Item.size() - 1)
			changed.emit(item)
			if is_player:
				SoundFx.play("pickup")
		elif _step_left <= 0.0:
			_step_left = ROULETTE_STEP
			changed.emit(_rng.randi_range(1, Item.size() - 1))
			if is_player:
				SoundFx.play("tick", -6.0)
	if kart.input_item_pressed:
		kart.input_item_pressed = false
		use()


func start_roulette() -> void:
	if item != Item.NONE or rolling:
		return
	rolling = true
	_roll_left = ROULETTE_TIME
	_step_left = 0.0


func use() -> void:
	if rolling or item == Item.NONE:
		return
	match item:
		Item.MUSHROOM:
			kart.apply_boost(1.5, 1.5)
		Item.SHELL:
			_fire_shell()
	item = Item.NONE
	changed.emit(Item.NONE)


func _fire_shell() -> void:
	var shell: ShellProjectile = (load(SHELL_SCENE) as PackedScene).instantiate()
	kart.get_parent().add_child(shell)
	var fwd := -kart.global_transform.basis.z
	shell.launch(kart, kart.global_position + fwd * 1.5 + Vector3.UP * 0.5, fwd)
	SoundFx.play_3d("shell", kart.global_position)


## Procedurally drawn 16x16 icons so the shell needs no art files.
static func icon(which: int) -> Texture2D:
	if which == Item.NONE:
		return null
	if _icons.has(which):
		return _icons[which]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match which:
		Item.MUSHROOM:
			for y in range(9, 14):
				for x in range(6, 10):
					img.set_pixel(x, y, Color("f0e0c0"))
			for y in range(2, 9):
				for x in range(2, 14):
					var dx := (x - 7.5) / 6.0
					var dy := (y - 5.5) / 3.5
					if dx * dx + dy * dy <= 1.0:
						img.set_pixel(x, y, Color("d22f2f"))
			for spot in [Vector2i(5, 4), Vector2i(10, 4), Vector2i(7, 6)]:
				img.set_pixel(spot.x, spot.y, Color.WHITE)
				img.set_pixel(spot.x + 1, spot.y, Color.WHITE)
		Item.SHELL:
			for y in 16:
				for x in 16:
					var dx := (x - 7.5) / 6.5
					var dy := (y - 7.5) / 6.5
					var d := dx * dx + dy * dy
					if d <= 1.0:
						img.set_pixel(x, y, Color("2fa844") if d < 0.55 else Color("e8e8d8"))
	var tex := ImageTexture.create_from_image(img)
	_icons[which] = tex
	return tex
