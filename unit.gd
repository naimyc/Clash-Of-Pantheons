extends Node3D

class_name Unit

var grid_position: Vector2i
var movement_range: int = 3

var grid_manager
var selected: bool = false

# MOVE FUNCTION
func move_to(tile):

	if tile == null:
		return

	if tile.occupied:
		return

	var old_tile = grid_manager.get_tile(grid_position)
	if old_tile:
		old_tile.occupied = false
		old_tile.occupying_unit = null

	grid_position = tile.grid_position

	tile.occupied = true
	tile.occupying_unit = self

	global_position = tile.global_position + Vector3(0, 0.5, 0)

# SELECTION SYSTEM
func set_selected(value: bool):
	selected = value

	$SelectionVisual.visible = value
