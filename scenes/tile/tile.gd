extends Node3D
class_name Tile

signal hovered(tile)
signal unhovered(tile)
signal clicked(tile)

var grid_position: Vector2i

var occupied := false
var occupying_unit = null

func _ready():
	print("Tile ready:", name)
	var body = $StaticBody3D

	body.mouse_entered.connect(_on_mouse_entered)
	body.mouse_exited.connect(_on_mouse_exited)
	body.input_event.connect(_on_input_event)

func _on_mouse_entered():
	print("a")
	emit_signal("hovered", self)

func _on_mouse_exited():
	print("a")
	emit_signal("unhovered", self)

func _on_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("clicked", self)

func set_highlight(value: bool):
	$HighlightMesh.visible = value

func set_selected(value: bool):
	$HighlightMesh.visible = value
