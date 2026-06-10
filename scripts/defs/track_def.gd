class_name TrackDef
extends Resource
## A race track. Create one .tres per track under res://assets/tracks/<name>/.
## The scene must follow the track node contract (see README.md):
## TrackGeometry, Checkpoints, StartGrid, ItemBoxes, AIPath.

@export var id: StringName = &""
@export var display_name: String = ""
## Track scene satisfying the node contract.
@export var scene: PackedScene
@export var laps: int = 3
## Menu thumbnail (optional).
@export var preview: Texture2D
## Background music (optional).
@export var music: AudioStream
## Karts falling below this Y are respawned at their last checkpoint.
@export var kill_y: float = -10.0
