extends Node3D
class_name Figure

var grid_position: Vector2i
var movement_range := 3

var grid_manager
var current_tile = null

var selected := false
var team := 0

@onready var visual: Node3D = $Visual

func set_team(value: int):
	team = value
	update_team_visual()

func update_team_visual():
	if visual == null:
		print("Visual is null")
		return

	if team == 1:
		visual.rotation_degrees.y = 180
	else:
		visual.rotation_degrees.y = 0
func move_to(tile):

	if tile == null:
		return

	if tile.occupied:
		return

	# free old tile
	if current_tile:
		current_tile.occupied = false
		current_tile.occupying_unit = null

	# assign new tile
	current_tile = tile
	grid_position = tile.grid_position

	tile.occupied = true
	tile.occupying_unit = self

	global_position = tile.global_position + Vector3(0, 0.5, 0)

func set_selected(value: bool):

	selected = value
	$SelectionVisual.visible = value
