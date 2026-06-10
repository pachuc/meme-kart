class_name AsepriteSheet
extends RefCounted
## Parses an Aseprite "Export Sprite Sheet" JSON data file (Array format,
## Tags enabled, Trim OFF) into tag -> frame-list lookups.
##
## Tag naming convention: <anim>_<dir>
##   anim: idle | drive | drift_l | drift_r   dir: n ne e se s sw w nw
##   plus a direction-less "spin" tag.
## "n" is the back view (camera behind the kart). If a west-side tag is
## missing, the matching east-side tag is used horizontally flipped
## (drift_l/drift_r are swapped when mirrored).

const MIRROR_DIR := {"w": "e", "nw": "ne", "sw": "se"}

var tags: Dictionary = {}  # String -> Array of { rect: Rect2, duration: int (ms) }
var frame_size: Vector2i = Vector2i.ZERO


static func load_sheet(json: JSON) -> AsepriteSheet:
	if json == null or json.data == null:
		push_error("AsepriteSheet: missing or unparsable JSON")
		return null
	var data: Variant = json.data
	if not (data is Dictionary) or not data.has("frames"):
		push_error("AsepriteSheet: JSON has no 'frames' key — is this an Aseprite data export?")
		return null
	if not (data.frames is Array):
		push_error("AsepriteSheet: 'frames' must be an Array — re-export with JSON Data type 'Array' (not Hash)")
		return null

	var sheet := AsepriteSheet.new()
	var frames: Array = []
	for f in data.frames:
		if f.get("rotated", false) or f.get("trimmed", false):
			push_error("AsepriteSheet: rotated/trimmed frames unsupported — export with Trim OFF")
			return null
		var r: Dictionary = f.frame
		frames.append({
			"rect": Rect2(r.x, r.y, r.w, r.h),
			"duration": int(f.get("duration", 100)),
		})
		sheet.frame_size = Vector2i(int(r.w), int(r.h))

	var frame_tags: Array = data.get("meta", {}).get("frameTags", [])
	for t in frame_tags:
		var from_i := int(t.from)
		var to_i := int(t.to)
		if from_i < 0 or to_i >= frames.size() or from_i > to_i:
			push_warning("AsepriteSheet: tag '%s' has out-of-range frames, skipping" % t.name)
			continue
		sheet.tags[String(t.name)] = frames.slice(from_i, to_i + 1)
	if sheet.tags.is_empty():
		# No tags at all: treat the whole sheet as a single drive_n loop.
		sheet.tags["drive_n"] = frames
	return sheet


func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Resolve an animation for a view direction. Returns
## { frames: Array, flip_h: bool }. Never fails on missing art:
## falls back mirror -> <anim>_n -> idle_n -> drive_n -> first tag.
func get_anim(anim: String, dir: String) -> Dictionary:
	if anim == "spin" and tags.has("spin"):
		return {"frames": tags["spin"], "flip_h": false}
	var key := "%s_%s" % [anim, dir]
	if tags.has(key):
		return {"frames": tags[key], "flip_h": false}
	if MIRROR_DIR.has(dir):
		var m_anim := anim
		if anim == "drift_l":
			m_anim = "drift_r"
		elif anim == "drift_r":
			m_anim = "drift_l"
		var m_key := "%s_%s" % [m_anim, MIRROR_DIR[dir]]
		if tags.has(m_key):
			return {"frames": tags[m_key], "flip_h": true}
	for fallback in ["%s_n" % anim, "idle_n", "drive_n"]:
		if tags.has(fallback):
			return {"frames": tags[fallback], "flip_h": false}
	return {"frames": tags[tags.keys()[0]], "flip_h": false}
