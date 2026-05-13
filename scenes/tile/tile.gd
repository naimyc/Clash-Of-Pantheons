extends Node3D


var occupied = false
var occupying_unit = null

signal hovered(tile)
signal clicked(tile)

var grid_position : Vector2i
@onready var highlight = $HighlightMesh


func set_highlight(enabled: bool):
	highlight.visible = enabled


func _on_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("clicked", self)
