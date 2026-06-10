extends Node
## Autoload "Registry". Scans res://assets/ at startup and indexes every
## CharacterDef / KartDef / TrackDef .tres it finds. Adding new content
## is just dropping a folder with a .tres into assets/ — no code changes.

const ASSETS_ROOT := "res://assets"

var characters: Dictionary = {}  # StringName -> CharacterDef
var karts: Dictionary = {}       # StringName -> KartDef
var tracks: Dictionary = {}      # StringName -> TrackDef


func _ready() -> void:
	rescan()


func rescan() -> void:
	characters.clear()
	karts.clear()
	tracks.clear()
	_scan_dir(ASSETS_ROOT)
	print("Registry: %d characters, %d karts, %d tracks" % [
		characters.size(), karts.size(), tracks.size()])


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(full)
		elif entry.get_extension() in ["tres", "res"]:
			_register(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _register(path: String) -> void:
	var res := load(path)
	if res == null:
		push_warning("Registry: failed to load %s" % path)
		return
	var bucket: Dictionary
	if res is CharacterDef:
		bucket = characters
	elif res is KartDef:
		bucket = karts
	elif res is TrackDef:
		bucket = tracks
	else:
		return
	var def_id: StringName = res.id
	if def_id == &"":
		push_warning("Registry: %s has an empty id, skipping" % path)
		return
	if bucket.has(def_id):
		push_warning("Registry: duplicate id '%s' (%s overrides previous)" % [def_id, path])
	bucket[def_id] = res


func get_characters() -> Array:
	return _sorted_values(characters)


func get_karts() -> Array:
	return _sorted_values(karts)


func get_tracks() -> Array:
	return _sorted_values(tracks)


func get_character(id: StringName) -> CharacterDef:
	return characters.get(id)


func get_kart(id: StringName) -> KartDef:
	return karts.get(id)


func get_track(id: StringName) -> TrackDef:
	return tracks.get(id)


func _sorted_values(bucket: Dictionary) -> Array:
	var ids := bucket.keys()
	# StringName doesn't order alphabetically; compare as String.
	ids.sort_custom(func(a, b): return String(a) < String(b))
	var out: Array = []
	for k in ids:
		out.append(bucket[k])
	return out
