extends Node
## Autoload "StickNav". Raw joypad motion events don't reliably drive
## Godot's UI focus navigation (and never auto-repeat), so this converts
## left-stick movement into synthesized ui_left/right/up/down action
## events with an initial delay + repeat, exactly like holding an arrow
## key. Only active while some Control has focus, so it never interferes
## with driving.

const DEADZONE := 0.5
const REPEAT_DELAY := 0.35
const REPEAT_RATE := 0.14

var _dir := Vector2i.ZERO
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() == null:
		_dir = Vector2i.ZERO
		return

	# Strongest left-stick deflection across pads (covers any device index).
	var v := Vector2.ZERO
	for pad in Input.get_connected_joypads():
		var pv := Vector2(
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if pv.length_squared() > v.length_squared():
			v = pv

	# Dominant axis only — no diagonal double-steps.
	var dir := Vector2i.ZERO
	if v.length() > DEADZONE:
		if absf(v.x) > absf(v.y):
			dir = Vector2i(1 if v.x > 0.0 else -1, 0)
		else:
			dir = Vector2i(0, 1 if v.y > 0.0 else -1)

	if dir != _dir:
		_dir = dir
		_timer = REPEAT_DELAY
		if dir != Vector2i.ZERO:
			_fire(dir)
	elif dir != Vector2i.ZERO:
		_timer -= delta
		if _timer <= 0.0:
			_timer = REPEAT_RATE
			_fire(dir)


func _fire(dir: Vector2i) -> void:
	var action := ""
	if dir.x < 0:
		action = "ui_left"
	elif dir.x > 0:
		action = "ui_right"
	elif dir.y < 0:
		action = "ui_up"
	else:
		action = "ui_down"
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	SoundFx.play("ui_move", -8.0)
