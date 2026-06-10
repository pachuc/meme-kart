class_name RaceHud
extends CanvasLayer
## In-race HUD: lap, position, speed, timer, countdown, item slot,
## wrong-way warning and the results panel. Built in code; restyle or
## replace this scene freely — RaceManager only calls the public methods.

signal rematch_pressed
signal menu_pressed

var _lap: Label
var _pos: Label
var _speed: Label
var _timer: Label
var _countdown: Label
var _wrong_way: Label
var _item_panel: PanelContainer
var _item_icon: TextureRect
var _results: PanelContainer
var _results_rows: VBoxContainer
var _rematch_button: Button


func _ready() -> void:
	# Keep processing while the tree is paused so Esc can unpause and the
	# results buttons stay clickable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_lap = _label(root, 28)
	_place(_lap, Vector2(0, 0), Vector2(24, 16))

	_pos = _label(root, 48)
	_place(_pos, Vector2(0, 0), Vector2(24, 52))

	_timer = _label(root, 24)
	_place(_timer, Vector2(0.5, 0), Vector2(-60, 16))

	_speed = _label(root, 28)
	_place(_speed, Vector2(1, 1), Vector2(-190, -60))

	_countdown = _label(root, 96)
	_place(_countdown, Vector2(0.5, 0.35), Vector2(-300, -60))
	_countdown.anchor_right = 0.5
	_countdown.offset_right = 300.0
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.visible = false

	_wrong_way = _label(root, 40)
	_wrong_way.text = "WRONG WAY!"
	_wrong_way.modulate = Color("ff5050")
	_place(_wrong_way, Vector2(0.5, 0.65), Vector2(-300, 0))
	_wrong_way.anchor_right = 0.5
	_wrong_way.offset_right = 300.0
	_wrong_way.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrong_way.visible = false

	_item_panel = PanelContainer.new()
	root.add_child(_item_panel)
	_place(_item_panel, Vector2(1, 0), Vector2(-104, 16))
	_item_panel.custom_minimum_size = Vector2(80, 80)
	_item_icon = TextureRect.new()
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_panel.add_child(_item_icon)

	_results = PanelContainer.new()
	root.add_child(_results)
	_place(_results, Vector2(0.5, 0.5), Vector2(-220, -180))
	_results.custom_minimum_size = Vector2(440, 360)
	_results.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_results.add_child(vb)
	var title := Label.new()
	title.text = "RESULTS"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_results_rows = VBoxContainer.new()
	_results_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_results_rows)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	vb.add_child(buttons)
	var rematch := Button.new()
	rematch.name = "RematchButton"
	rematch.text = "Rematch"
	rematch.custom_minimum_size = Vector2(140, 44)
	rematch.pressed.connect(func():
		SoundFx.play("ui_select")
		rematch_pressed.emit()
	)
	buttons.add_child(rematch)
	_rematch_button = rematch
	var menu := Button.new()
	menu.name = "MenuButton"
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(140, 44)
	menu.pressed.connect(func():
		SoundFx.play("ui_select")
		menu_pressed.emit()
	)
	buttons.add_child(menu)


## Pin a control's top-left to `anchor` (0..1 of the screen) plus a pixel
## offset. Offsets are explicit so layout is independent of parent size
## at build time.
func _place(ctl: Control, anchor: Vector2, px: Vector2) -> void:
	ctl.anchor_left = anchor.x
	ctl.anchor_right = anchor.x
	ctl.anchor_top = anchor.y
	ctl.anchor_bottom = anchor.y
	ctl.offset_left = px.x
	ctl.offset_top = px.y
	ctl.grow_horizontal = Control.GROW_DIRECTION_END
	ctl.grow_vertical = Control.GROW_DIRECTION_END


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var paused := not get_tree().paused
		get_tree().paused = paused
		set_countdown("PAUSED" if paused else "")


func _label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l


func set_lap(lap: int, total: int) -> void:
	_lap.text = "LAP %d/%d" % [mini(lap, total), total]


func set_rank(rank: int, total: int) -> void:
	_pos.text = "%s / %d" % [_ordinal(rank), total]


func set_speed(kmh: float) -> void:
	_speed.text = "%d km/h" % int(kmh)


func set_timer(t: float) -> void:
	_timer.text = format_time(t)


func set_countdown(text: String) -> void:
	_countdown.visible = text != ""
	_countdown.text = text


func set_wrong_way(on: bool) -> void:
	_wrong_way.visible = on


func set_item(icon: Texture2D) -> void:
	_item_icon.texture = icon


## rows: Array of { rank: int, name: String, time: float, is_player: bool }
func show_results(rows: Array) -> void:
	for child in _results_rows.get_children():
		child.queue_free()
	for r in rows:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 24)
		var time_text: String = format_time(r.time) if r.time >= 0.0 else "—"
		l.text = "%s   %s   %s" % [_ordinal(r.rank), r.name, time_text]
		if r.is_player:
			l.modulate = Color("ffd24a")
		_results_rows.add_child(l)
	_results.visible = true
	_rematch_button.grab_focus()  # gamepad can navigate/press the buttons


func hide_results() -> void:
	_results.visible = false


static func format_time(t: float) -> String:
	var ms := int(round(t * 1000.0))
	@warning_ignore("integer_division")
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n
