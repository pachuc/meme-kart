class_name ItemBox
extends Area3D
## Spinning pickup box. Grants a roulette roll to karts that drive
## through, then hides and respawns a few seconds later.

const RESPAWN_SECONDS := 3.0

@onready var visual: CSGBox3D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if visual.visible:
		visual.rotate_y(delta * 2.0)
		visual.rotate_x(delta * 1.3)


func _on_body_entered(body: Node3D) -> void:
	if not (body is KartController):
		return
	var holder: ItemHolder = body.get_node_or_null("ItemHolder")
	if holder == null or holder.item != ItemHolder.Item.NONE or holder.rolling:
		return
	holder.start_roulette()
	visual.visible = false
	set_deferred("monitoring", false)
	get_tree().create_timer(RESPAWN_SECONDS).timeout.connect(func():
		visual.visible = true
		set_deferred("monitoring", true)
	)
