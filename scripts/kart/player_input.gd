class_name PlayerInput
extends Node
## Feeds InputMap state into the parent KartController each physics tick.
## Steering uses get_axis so analog sticks come through proportionally.

@onready var kart: KartController = get_parent()


func _physics_process(_delta: float) -> void:
	kart.input_steer = Input.get_axis("steer_left", "steer_right")
	kart.input_throttle = Input.get_action_strength("accelerate")
	kart.input_brake = Input.get_action_strength("brake_reverse")
	kart.input_drift_held = Input.is_action_pressed("drift_hop")
	if Input.is_action_just_pressed("drift_hop"):
		kart.input_drift_pressed = true
	if Input.is_action_just_pressed("use_item"):
		kart.input_item_pressed = true
