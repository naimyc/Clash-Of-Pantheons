extends Node
class_name GridManager

const GRID_SIZE = 7
const TILE_SIZE = 1.0

@export var tile_scene: PackedScene
@export var figure_scene: PackedScene

var tiles = {}

var hovered_tile = null
var selected_tile = null

@onready var input_manager = $"../InputManager"

func _ready():

	generate_grid()

	# CONNECT SIGNALS
	input_manager.tile_hovered.connect(_on_tile_hovered)
	input_manager.tile_unhovered.connect(_on_tile_unhovered)
	input_manager.tile_clicked.connect(_on_tile_clicked)
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

			# centered grid
			tile.position = Vector3(
				(x - GRID_SIZE / 2.0) * TILE_SIZE,
				0,
				(z - GRID_SIZE / 2.0) * TILE_SIZE
			)

			tile.grid_position = Vector2i(x, z)

			add_child(tile)
			input_manager.register_tile(tile)
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

	var tile = get_tile(coord)

	if tile == null:
		return

	var figure = figure_scene.instantiate() as Figure

	figure.grid_manager = self
	figure.grid_position = coord
	figure.current_tile = tile

	tile.occupied = true
	tile.occupying_unit = figure

	figure.position = tile.position + Vector3(0, 0.1, 0)
	get_node("../Figures").add_child(figure)

	figure.set_team(team)

# =========================
# HOVER
# =========================
func _on_tile_hovered(tile):

	if tile == selected_tile:
		return

	hovered_tile = tile

	tile.set_highlight(true)
func _on_tile_unhovered(tile):

	if tile == selected_tile:
		return

	if hovered_tile == tile:
		hovered_tile = null

	tile.set_highlight(false)
# =========================
# CLICK / SELECTION
# =========================

func _on_tile_clicked(tile):

	# clear old selection
	if selected_tile:
		selected_tile.set_selected(false)

	selected_tile = tile

	# set new selection
	if selected_tile:
		selected_tile.set_selected(true)
