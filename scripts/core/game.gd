extends Node
## Autoload "Game". Cross-scene state: the player's menu selections,
## last race results, and the screen-change signal main.gd listens to.

signal screen_change_requested(screen: StringName)

var selected_character: CharacterDef
var selected_kart: KartDef
var selected_track: TrackDef

## Array of result dictionaries from the last finished race:
## { rank: int, name: String, time: float, is_player: bool }
var last_results: Array = []


func goto(screen: StringName) -> void:
	screen_change_requested.emit(screen)


## Fill any missing selections with the first registry entry so a race
## can start directly (e.g. from MCP testing) without visiting the menu.
func ensure_selections() -> bool:
	if selected_character == null:
		var chars: Array = Registry.get_characters()
		if chars.is_empty():
			push_error("Game: no characters registered")
			return false
		selected_character = chars[0]
	if selected_kart == null:
		var karts: Array = Registry.get_karts()
		if karts.is_empty():
			push_error("Game: no karts registered")
			return false
		selected_kart = karts[0]
	if selected_track == null:
		var tracks: Array = Registry.get_tracks()
		if tracks.is_empty():
			push_error("Game: no tracks registered")
			return false
		selected_track = tracks[0]
	return true
