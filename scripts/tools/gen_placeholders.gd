extends SceneTree
## Headless placeholder asset generator. Run from the project root:
##   godot --headless --path . --script res://scripts/tools/gen_placeholders.gd
##
## Characters and karts are separate, composable sheets: the character
## sheet is the RIDER only (bottom-center = seat contact point) and the
## kart sheet is the chassis + wheels + blob shadow with no rider. The
## game layers them at the KartDef seat anchor, so any character can
## ride any kart. For each entry it draws a 32x32-per-frame sheet from
## 8 (or 5 mirrored) view angles with the Image API, then writes:
##   assets/characters/<id>/sheet.png|sheet.json|<id>.tres
##   assets/karts/<id>/sheet.png|sheet.json|<id>.tres
## The JSON goes through the exact same AsepriteSheet loader user art will use.

const FRAME := 32
const COLS := 8

const DIR_PHI := {
	"n": 0.0, "ne": 45.0, "e": 90.0, "se": 135.0,
	"s": 180.0, "sw": 225.0, "w": 270.0, "nw": 315.0,
}
const ALL_DIRS := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const MIRROR_DIRS := ["n", "ne", "e", "se", "s"]

const CHARACTERS := [
	{
		"id": "rosso", "name": "Rosso", "mirror": false,
		"body": Color("d22f2f"),
		"head": Color("f0c08a"), "helmet": Color("8a1010"),
		"speed": 1.1, "accel": 0.95, "handling": 0.95, "weight": 1.2,
	},
	{
		"id": "blu", "name": "Blu", "mirror": false,
		"body": Color("2f5fd2"),
		"head": Color("e8b27a"), "helmet": Color("10268a"),
		"speed": 1.0, "accel": 1.0, "handling": 1.0, "weight": 1.0,
	},
	{
		"id": "verde", "name": "Verde", "mirror": true,
		"body": Color("2fa844"),
		"head": Color("d9a06b"), "helmet": Color("0f6e22"),
		"speed": 0.92, "accel": 1.15, "handling": 1.1, "weight": 0.8,
	},
]

const KARTS := [
	{
		"id": "standard", "name": "Standard", "mirror": true,
		"body": Color("9aa0ad"), "trim": Color("4d5360"),
		"top_speed": 18.0, "acceleration": 10.0, "braking": 22.0, "reverse_speed": 6.0,
		"steer_speed": 1.8, "steer_speed_falloff": 0.35, "grip": 8.0,
		"drift_steer_min": 0.6, "drift_steer_max": 1.8,
		"mini_turbo_threshold": 1.0, "boost_strength": 1.35, "boost_duration": 1.2,
	},
	{
		"id": "speedy", "name": "Speedy", "mirror": false,
		"body": Color("e8c22f"), "trim": Color("9a6a10"),
		"top_speed": 22.0, "acceleration": 8.5, "braking": 20.0, "reverse_speed": 6.0,
		"steer_speed": 1.5, "steer_speed_falloff": 0.45, "grip": 6.5,
		"drift_steer_min": 0.55, "drift_steer_max": 1.7,
		"mini_turbo_threshold": 1.3, "boost_strength": 1.4, "boost_duration": 1.4,
	},
]


func _init() -> void:
	for c in CHARACTERS:
		_gen_character(c)
	for k in KARTS:
		_gen_kart(k)
	print("gen_placeholders: done")
	quit()


# --- shared sheet generation -------------------------------------------------

## Build the ordered frame list and Aseprite tag ranges for one sheet.
## Every frame is { phi, bounce, duration }.
func _build_frames(mirror: bool) -> Dictionary:
	var frames: Array = []
	var tag_defs: Array = []  # { name, from, to }
	var dirs: Array = MIRROR_DIRS if mirror else ALL_DIRS
	for d in dirs:
		var phi: float = DIR_PHI[d]
		_add_tag(tag_defs, frames, "idle_%s" % d, [{"phi": phi, "bounce": 0, "duration": 200}])
		_add_tag(tag_defs, frames, "drive_%s" % d, [
			{"phi": phi, "bounce": 0, "duration": 120},
			{"phi": phi, "bounce": 1, "duration": 120},
		])
		_add_tag(tag_defs, frames, "drift_l_%s" % d,
			[{"phi": wrapf(phi - 30.0, 0.0, 360.0), "bounce": 1, "duration": 120}])
		_add_tag(tag_defs, frames, "drift_r_%s" % d,
			[{"phi": wrapf(phi + 30.0, 0.0, 360.0), "bounce": 1, "duration": 120}])
	var spin_frames: Array = []
	for i in 8:
		spin_frames.append({"phi": i * 45.0, "bounce": 0, "duration": 80})
	_add_tag(tag_defs, frames, "spin", spin_frames)
	return {"frames": frames, "tag_defs": tag_defs}


func _add_tag(tag_defs: Array, frames: Array, tag_name: String, tag_frames: Array) -> void:
	tag_defs.append({"name": tag_name, "from": frames.size(), "to": frames.size() + tag_frames.size() - 1})
	frames.append_array(tag_frames)


## Draw every frame via draw_frame.call(img, ox, oy, phi, bounce) and write
## sheet.png + Aseprite-format sheet.json (Array + frameTags) into dir_path.
func _write_sheet(dir_path: String, mirror: bool, draw_frame: Callable) -> bool:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var built := _build_frames(mirror)
	var frames: Array = built.frames
	var tag_defs: Array = built.tag_defs

	var rows := ceili(float(frames.size()) / COLS)
	var img := Image.create(COLS * FRAME, rows * FRAME, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var ox := (i % COLS) * FRAME
		var oy := (i / COLS) * FRAME
		draw_frame.call(img, ox, oy, frames[i].phi, frames[i].bounce)

	var png_path := dir_path.path_join("sheet.png")
	var err := img.save_png(ProjectSettings.globalize_path(png_path))
	if err != OK:
		push_error("gen_placeholders: failed to save %s (%d)" % [png_path, err])
		return false

	var ase_frames: Array = []
	for i in frames.size():
		ase_frames.append({
			"filename": str(i),
			"frame": {"x": (i % COLS) * FRAME, "y": (i / COLS) * FRAME, "w": FRAME, "h": FRAME},
			"rotated": false,
			"trimmed": false,
			"spriteSourceSize": {"x": 0, "y": 0, "w": FRAME, "h": FRAME},
			"sourceSize": {"w": FRAME, "h": FRAME},
			"duration": frames[i].duration,
		})
	var ase_tags: Array = []
	for t in tag_defs:
		ase_tags.append({"name": t.name, "from": t.from, "to": t.to, "direction": "forward"})
	var doc := {
		"frames": ase_frames,
		"meta": {
			"app": "meme-kart gen_placeholders",
			"image": "sheet.png",
			"format": "RGBA8888",
			"size": {"w": img.get_width(), "h": img.get_height()},
			"scale": "1",
			"frameTags": ase_tags,
		},
	}
	_write_text(dir_path.path_join("sheet.json"), JSON.stringify(doc, "\t"))
	print("gen_placeholders: %s (%d frames, %d tags)" % [dir_path, frames.size(), tag_defs.size()])
	return true


# --- characters (rider only) -------------------------------------------------

func _gen_character(c: Dictionary) -> void:
	var dir_path: String = "res://assets/characters/%s" % c.id
	if not _write_sheet(dir_path, c.mirror,
			func(img, ox, oy, phi, bounce): _draw_rider(img, ox, oy, phi, bounce, c)):
		return

	_write_text(dir_path.path_join("%s.tres" % c.id), """[gd_resource type="Resource" script_class="CharacterDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/defs/character_def.gd" id="1"]
[ext_resource type="Texture2D" path="%s" id="2"]
[ext_resource type="JSON" path="%s" id="3"]

[resource]
script = ExtResource("1")
id = &"%s"
display_name = "%s"
sprite_sheet = ExtResource("2")
aseprite_json = ExtResource("3")
mirror_sprites = %s
sprite_pixel_size = 0.045
speed_mod = %s
accel_mod = %s
handling_mod = %s
weight = %s
""" % [dir_path.path_join("sheet.png"), dir_path.path_join("sheet.json"), c.id, c.name,
		str(c.mirror).to_lower(), c.speed, c.accel, c.handling, c.weight])


## Draw one rider view into a FRAME x FRAME cell: shoulders + helmeted
## head, nothing else. The frame's bottom-center is the seat contact
## point — in-game it lands exactly on the kart's seat anchor. The 1px
## drive bounce matches the kart sheets so the two layers move together.
func _draw_rider(img: Image, ox: int, oy: int, phi_deg: float, bounce: int, c: Dictionary) -> void:
	var phi := deg_to_rad(phi_deg)
	var lx := sin(phi)
	var toward := cos(phi) < -0.2  # facing the camera
	var black := Color(0.1, 0.1, 0.1)

	var cx := 16
	var base := 31 - bounce  # bottom row = seat contact
	# Slight lean: the head trails the facing direction a touch.
	var hx := cx - int(round(lx * 1.0))
	_ellipse(img, ox, oy, cx, base - 2, 4, 2, c.body)            # shoulders
	_ellipse(img, ox, oy, hx, base - 6, 3, 3, c.head)            # head
	_ellipse(img, ox, oy, hx, base - 7, 3, 2, c.helmet)          # helmet
	if toward:
		var eye_off := int(round(lx * 1.5))
		_set_px(img, ox, oy, hx - 1 + eye_off, base - 5, black)
		_set_px(img, ox, oy, hx + 1 + eye_off, base - 5, black)


# --- karts (chassis, no rider) -----------------------------------------------

func _gen_kart(k: Dictionary) -> void:
	var dir_path: String = "res://assets/karts/%s" % k.id
	if not _write_sheet(dir_path, k.mirror,
			func(img, ox, oy, phi, bounce): _draw_kart(img, ox, oy, phi, bounce, k)):
		return

	_write_text(dir_path.path_join("%s.tres" % k.id), """[gd_resource type="Resource" script_class="KartDef" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/defs/kart_def.gd" id="1"]
[ext_resource type="Texture2D" path="%s" id="2"]
[ext_resource type="JSON" path="%s" id="3"]

[resource]
script = ExtResource("1")
id = &"%s"
display_name = "%s"
sprite_sheet = ExtResource("2")
aseprite_json = ExtResource("3")
mirror_sprites = %s
sprite_pixel_size = 0.045
sprite_y_offset = 0.0
seat_n = Vector2(0, 8)
seat_ne = Vector2(-1, 8)
seat_e = Vector2(-2, 8)
seat_se = Vector2(-1, 8)
seat_s = Vector2(0, 8)
top_speed = %s
acceleration = %s
braking = %s
reverse_speed = %s
steer_speed = %s
steer_speed_falloff = %s
grip = %s
drift_steer_min = %s
drift_steer_max = %s
mini_turbo_threshold = %s
boost_strength = %s
boost_duration = %s
""" % [dir_path.path_join("sheet.png"), dir_path.path_join("sheet.json"), k.id, k.name,
		str(k.mirror).to_lower(),
		k.top_speed, k.acceleration, k.braking, k.reverse_speed,
		k.steer_speed, k.steer_speed_falloff, k.grip, k.drift_steer_min,
		k.drift_steer_max, k.mini_turbo_threshold, k.boost_strength, k.boost_duration])


## Draw one riderless kart view into a FRAME x FRAME cell.
## phi = compass angle the kart faces on screen: 0 = away (back view),
## 90 = right, 180 = toward camera, 270 = left.
func _draw_kart(img: Image, ox: int, oy: int, phi_deg: float, bounce: int, k: Dictionary) -> void:
	var phi := deg_to_rad(phi_deg)
	# Screen-space length axis (x right, y down); 0.45 = vertical foreshortening.
	var lx := sin(phi)
	var ly := -cos(phi) * 0.45
	# Perpendicular (side) axis.
	var px := cos(phi)
	var py := sin(phi) * 0.45

	var cx := 16
	# Anchor the art to the frame bottom so the sprite's contact point sits
	# exactly at the kart origin (no transparent gap = no floating look).
	var cy := 24 - bounce
	var black := Color(0.1, 0.1, 0.1)

	# Shadow at the frame bottom (not affected by bounce). The blob shadow
	# lives on the kart layer; rider sheets have none.
	_ellipse(img, ox, oy, 16, 29, 11, 2, Color(0, 0, 0, 0.35))
	# Wheels: 4 corners = +-length*5 +-side*5.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var wx := int(round(corner.x * lx * 5.0 + corner.y * px * 5.0))
		var wy := int(round(corner.x * ly * 5.0 + corner.y * py * 5.0))
		_ellipse(img, ox, oy, cx + wx, cy + wy + 2, 2, 2, black)
	# Body: ellipse stretched along the dominant screen axis.
	var half_w := int(round(lerpf(7.0, 9.0, absf(lx))))
	var half_h := 4
	_ellipse(img, ox, oy, cx, cy, half_w, half_h, k.body)
	_ellipse(img, ox, oy, cx, cy - 1, half_w - 2, half_h - 1, k.trim)
	# Nose marker shows the facing direction.
	_ellipse(img, ox, oy, cx + int(round(lx * 6.0)), cy + int(round(ly * 6.0)) - 1, 2, 2, Color("cfe8ff"))


# --- drawing helpers ----------------------------------------------------------

func _ellipse(img: Image, ox: int, oy: int, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var fx := float(x) / float(rx)
			var fy := float(y) / float(ry)
			if fx * fx + fy * fy <= 1.0:
				_set_px(img, ox, oy, cx + x, cy + y, col)


func _set_px(img: Image, ox: int, oy: int, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < FRAME and y >= 0 and y < FRAME:
		img.set_pixel(ox + x, oy + y, col)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("gen_placeholders: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
