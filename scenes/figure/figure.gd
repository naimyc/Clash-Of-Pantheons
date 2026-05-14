extends Node3D
class_name Figure

signal clicked(figure)

var grid_position: Vector2i
var grid_manager
var current_tile = null

var selected := false
var team := 0

@onready var visual: Node3D = $FigureBody
@onready var stats: Stats = $Stats


func set_team(value: int):
	team = value
	update_team_visual()


func update_team_visual():
	if team == 1:
		visual.rotation_degrees.y = 180
	else:
		visual.rotation_degrees.y = 0


func move_to(tile):

	if tile == null:
		return

	if tile.occupied:
		return

	if current_tile:
		current_tile.occupied = false
		current_tile.occupying_unit = null

	current_tile = tile
	grid_position = tile.grid_position

	tile.occupied = true
	tile.occupying_unit = self

	global_position = tile.global_position + Vector3(0, 0.5, 0)


# =========================
# COMBAT
# =========================

func attack_target(target):

	if target == null:
		return

	target.take_damage(stats.attack)


func die():

	if current_tile:
		current_tile.occupied = false
		current_tile.occupying_unit = null

	queue_free()


# =========================
# SELECTION
# =========================

func set_selected(value: bool):

	selected = value
	$SelectionVisual.visible = value

	if value:
		play_select_effect()
	else:
		reset_visual()
		


func play_select_effect():

	var t = create_tween()
	t.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.12)
	t.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.18)


func reset_visual():

	var t = create_tween()
	t.tween_property(self, "scale", Vector3(1, 1, 1), 0.1)


# =========================
# INPUT
# =========================

func _on_figure_body_input_event(_camera, event, _position, _normal, _shape_idx):

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

			clicked.emit(self)
			set_selected(true)
