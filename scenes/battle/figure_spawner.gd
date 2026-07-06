# figure_spawner.gd — attach to GridManager node as a child named "FigureSpawner"
# Handles initial figure placement for both teams.
extends Node
class_name FigureSpawner

@export var figure_scene: PackedScene = preload("res://scenes/figure/figure.tscn")

var grid_manager: GridManager


func _ready():
	grid_manager = get_parent()


func spawn_all():
	var R := {
		"knight":   load("res://resources/unit/Knight.tres"),
		"archer":   load("res://resources/unit/Archer.tres"),
		"apollo":   load("res://resources/unit/Apollo.tres"),
		"hercules": load("res://resources/unit/Hercules.tres"),
		"thanatos": load("res://resources/unit/Thanatos.tres"),
		"zeus":     load("res://resources/unit/Zeus.tres"),
		"medusa":   load("res://resources/unit/Medusa.tres"),
	}

	var placements = [
		# Team 0
		[Vector2i(1,1),0,"knight"],[Vector2i(2,1),0,"knight"],
		[Vector2i(4,1),0,"knight"],[Vector2i(5,1),0,"knight"],
		[Vector2i(1,0),0,"archer"],[Vector2i(5,0),0,"archer"],
		[Vector2i(3,2),0,"medusa"],[Vector2i(2,0),0,"thanatos"],
		[Vector2i(4,0),0,"apollo"],[Vector2i(3,1),0,"hercules"],
		[Vector2i(3,0),0,"zeus"],

		# Team 1
		[Vector2i(1,5),1,"knight"],[Vector2i(2,5),1,"knight"],
		[Vector2i(4,5),1,"knight"],[Vector2i(5,5),1,"knight"],
		[Vector2i(1,6),1,"archer"],[Vector2i(5,6),1,"archer"],
		[Vector2i(3,4),1,"medusa"],[Vector2i(4,6),1,"thanatos"],
		[Vector2i(2,6),1,"apollo"],[Vector2i(3,5),1,"hercules"],
		[Vector2i(3,6),1,"zeus"],
	]

	for p in placements:
		var stats = R[p[2]]
		if stats:
			spawn_figure(p[0], p[1], stats)


func spawn_figure(cell: Vector2i, team: int, stats: UnitStats):
	var fig = figure_scene.instantiate()

	fig.stats = stats
	fig.team = team
	fig.grid_manager = grid_manager
	fig.position = grid_manager.grid_to_world(cell)
	fig.grid_position = cell

	var tile = grid_manager.get_tile(cell)
	if tile:
		tile.occupied = true
		tile.occupying_unit = fig
		fig.current_tile = tile

	grid_manager.add_child(fig)

	# -----------------------------
	# SAFE MODEL DETECTION
	# -----------------------------
	var model = find_model(fig)

	if model:
		
		# Apply skin safely
		if model.has_method("apply_skin") and stats.unit_texture:
			model.apply_skin(stats.unit_texture)


# -----------------------------
# RECURSIVE MODEL SEARCH
# -----------------------------
func find_model(node: Node) -> Node:
	if node == null:
		return null

	if node.has_method("apply_skin"):
		return node

	for child in node.get_children():
		var result = find_model(child)
		if result:
			return result

	return null
