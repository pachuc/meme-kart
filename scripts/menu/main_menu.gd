extends Control
## Main menu: pick character / kart / track from whatever the Registry
## found in res://assets/, then start the race.

var _char_list: ItemList
var _kart_list: ItemList
var _track_list: ItemList
var _chars: Array
var _karts: Array
var _tracks: Array


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("28304a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 60.0
	vb.offset_right = -60.0
	vb.offset_top = 30.0
	vb.offset_bottom = -30.0
	vb.add_theme_constant_override("separation", 18)
	add_child(vb)

	var title := Label.new()
	title.text = "MEME KART"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	vb.add_child(columns)

	_chars = Registry.get_characters()
	_karts = Registry.get_karts()
	_tracks = Registry.get_tracks()

	_char_list = _column(columns, "CHARACTER")
	for c in _chars:
		_char_list.add_item(c.display_name, _portrait(c.icon, c.aseprite_json, c.sprite_sheet))
	_kart_list = _column(columns, "KART")
	for k in _karts:
		_kart_list.add_item(k.display_name, _portrait(k.icon, k.aseprite_json, k.sprite_sheet))
	_track_list = _column(columns, "TRACK")
	for t in _tracks:
		_track_list.add_item(t.display_name, t.preview)

	for list in [_char_list, _kart_list, _track_list]:
		if list.item_count > 0:
			list.select(0)

	var start := Button.new()
	start.name = "StartButton"
	start.text = "START RACE"
	start.custom_minimum_size = Vector2(260, 56)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 28)
	start.pressed.connect(_start)
	vb.add_child(start)

	if _chars.is_empty() or _karts.is_empty() or _tracks.is_empty():
		start.disabled = true
		title.text = "MEME KART — no assets found in res://assets/"

	# Gamepad/keyboard focus map: left/right across columns, down to Start.
	var lists: Array = [_char_list, _kart_list, _track_list]
	for i in lists.size():
		var list: ItemList = lists[i]
		list.focus_neighbor_left = lists[(i + lists.size() - 1) % lists.size()].get_path()
		list.focus_neighbor_right = lists[(i + 1) % lists.size()].get_path()
		list.focus_neighbor_bottom = start.get_path()
	start.focus_neighbor_top = _char_list.get_path()
	start.focus_neighbor_left = _char_list.get_path()
	start.focus_neighbor_right = _track_list.get_path()

	_char_list.grab_focus()


func _column(parent: Control, label_text: String) -> ItemList:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 24)
	col.add_child(label)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(48, 48)
	list.add_theme_font_size_override("font_size", 20)
	col.add_child(list)
	return list


## Menu portrait: explicit icon, or the first idle_s frame of the sheet.
func _portrait(icon: Texture2D, json: JSON, sheet_tex: Texture2D) -> Texture2D:
	if icon != null:
		return icon
	var sheet := AsepriteSheet.load_sheet(json)
	if sheet == null or sheet_tex == null:
		return null
	var anim := sheet.get_anim("idle", "s")
	if anim.frames.is_empty():
		return null
	var tex := AtlasTexture.new()
	tex.atlas = sheet_tex
	tex.region = anim.frames[0].rect
	return tex


func _start() -> void:
	var ci := _char_list.get_selected_items()
	var ki := _kart_list.get_selected_items()
	var ti := _track_list.get_selected_items()
	if ci.is_empty() or ki.is_empty() or ti.is_empty():
		return
	Game.selected_character = _chars[ci[0]]
	Game.selected_kart = _karts[ki[0]]
	Game.selected_track = _tracks[ti[0]]
	SoundFx.play("ui_select")
	Game.goto(&"race")
