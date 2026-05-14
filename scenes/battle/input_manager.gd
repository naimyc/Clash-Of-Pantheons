extends Node
class_name InputManager

signal tile_hovered(tile)
signal tile_unhovered(tile)
signal tile_clicked(tile)

# Tiles register themselves
func register_tile(tile):
	tile.hovered.connect(_on_tile_hovered)
	tile.unhovered.connect(_on_tile_unhovered)
	tile.clicked.connect(_on_tile_clicked)

func _on_tile_hovered(tile):
	emit_signal("tile_hovered", tile)

func _on_tile_unhovered(tile):
	emit_signal("tile_unhovered", tile)

func _on_tile_clicked(tile):
	emit_signal("tile_clicked", tile)
