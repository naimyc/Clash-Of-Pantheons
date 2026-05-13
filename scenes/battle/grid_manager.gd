extends Node3D
class_name GridManager

const GRID_SIZE = 7
const TILE_SIZE = 1.0

@export var tile_scene: PackedScene
@export var figure_scene: PackedScene

var tiles = {}

var hovered_tile = null
var selected_tile = null

func _ready():
	generate_grid()
	spawn_starting_figures()

func generate_grid():

	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):

			var tile = tile_scene.instantiate()
			var mesh = tile.get_node("MeshInstance3D")

			# checker pattern
			var material = StandardMaterial3D.new()

			if (x + z) % 2 == 0:
				material.albedo_color = Color(0.8, 0.8, 0.8)
			else:
				material.albedo_color = Color(0.2, 0.2, 0.2)

			mesh.material_override = material

			# position centered grid
			tile.position = Vector3(
				(x - GRID_SIZE / 2.0) * TILE_SIZE,
				0,
				(z - GRID_SIZE / 2.0) * TILE_SIZE
			)

			tile.grid_position = Vector2i(x, z)

			add_child(tile)
			tiles[Vector2i(x, z)] = tile

func get_tile(coord: Vector2i):
	return tiles.get(coord)

func spawn_starting_figures():

	for x in range(GRID_SIZE):

		spawn_figure(Vector2i(x, 0), 0)
		spawn_figure(Vector2i(x, 1), 0)

		spawn_figure(Vector2i(x, 5), 1)
		spawn_figure(Vector2i(x, 6), 1)

func spawn_figure(coord: Vector2i, team: int):
	var rotation = Vector3(0,0,0)
	
	var tile = get_tile(coord)
	if tile == null:
		return

	var figure = figure_scene.instantiate() as Figure

	figure.grid_manager = self
	figure.grid_position = coord
	figure.current_tile = tile

	tile.occupied = true
	tile.occupying_unit = figure

	figure.global_position = tile.global_position + Vector3(0, 0.1, 0)

	get_node("../Figures").add_child(figure)
	figure.set_team(team)

func set_hover(tile):

	if tile == hovered_tile:
		return

	# remove old hover
	if hovered_tile and hovered_tile != selected_tile:
		hovered_tile.set_highlight(false)

	hovered_tile = tile

	# apply new hover
	if hovered_tile and hovered_tile != selected_tile:
		hovered_tile.set_highlight(true)
