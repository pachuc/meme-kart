extends Node3D
## Root screen-swapper. Shows exactly one screen scene at a time,
## driven by Game.goto(). Screens: "menu", "race".

const SCREENS := {
	&"menu": "res://scenes/menu/main_menu.tscn",
	&"race": "res://scenes/race/race.tscn",
}

var _current: Node


func _ready() -> void:
	Game.screen_change_requested.connect(_change_screen)
	_change_screen(&"menu")


func _change_screen(screen: StringName) -> void:
	get_tree().paused = false
	if _current != null:
		_current.queue_free()
		_current = null
	var path: String = SCREENS.get(screen, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Main: screen '%s' not available yet" % screen)
		return
	_current = load(path).instantiate()
	add_child(_current)
