extends Node3D

@export var camera: Camera3D
@export var grid_manager: Node

var hovered_tile = null
var selected_tile = null


func _process(delta):
	update_hover()
	
"""
func _input(event):

	if event is InputEventMouseButton and event.pressed:

		if event.button_index == MOUSE_BUTTON_LEFT:
			if hovered_tile != null:
				select_tile(hovered_tile)
"""
# HOVER + RAYCAST
func update_hover():

	if camera == null:
		return

	var mouse_pos = get_viewport().get_mouse_position()

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = get_world_3d().direct_space_state.intersect_ray(query)

	var new_tile = null

	if result:
		var collider = result.collider
		new_tile = collider.get_parent()

	set_hover(new_tile)

# HOVER STATE
func set_hover(tile):

	if tile == hovered_tile:
		return

	# remove old hover (only if not selected)
	if hovered_tile and hovered_tile != selected_tile:
		hovered_tile.set_highlight(false)

	hovered_tile = tile

	# apply new hover (only if not selected)
	if hovered_tile and hovered_tile != selected_tile:
		hovered_tile.set_highlight(true)

# SELECT STATE
"""
func select_tile(tile):

	if selected_tile == tile:
		return

	# clear old selection
	if selected_tile:
		selected_tile.set_selected(false)

	selected_tile = tile

	if selected_tile:

		selected_tile.set_selected(true)
"""
