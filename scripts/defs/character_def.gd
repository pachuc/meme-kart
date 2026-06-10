class_name CharacterDef
extends Resource
## A playable character: the RIDER only — the kart they sit in is a
## separate KartDef with its own sheet, so any character can ride any
## kart. Create one .tres per character under res://assets/characters/
## <name>/ alongside the Aseprite-exported sheet.png and sheet.json.
## See docs/character-art-guide.md for export settings and tag naming.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Sprites")
## Aseprite-exported rider sprite sheet PNG. Draw only what is visible
## above the kart; the frame's bottom-center is placed at the kart's
## seat anchor.
@export var sprite_sheet: Texture2D
## The matching Aseprite JSON data file (Array format, tags enabled).
@export var aseprite_json: JSON
## If true, only n/ne/e/se/s angles need to be drawn; w/nw/sw are
## mirrored from the east-side angles automatically.
@export var mirror_sprites: bool = true
## World size of one sprite pixel in meters (Sprite3D.pixel_size).
## Use the same pixels-per-meter scale as the kart sheets.
@export var sprite_pixel_size: float = 0.045
## Menu portrait. Falls back to the first idle_s frame when empty.
@export var icon: Texture2D

@export_group("Stats")
@export_range(0.7, 1.3) var speed_mod: float = 1.0
@export_range(0.7, 1.3) var accel_mod: float = 1.0
@export_range(0.7, 1.3) var handling_mod: float = 1.0
## Heavier characters knock lighter ones around in bumps.
@export_range(0.5, 2.0) var weight: float = 1.0
