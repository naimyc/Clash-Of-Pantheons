# figure_spawner.gd — attach to GridManager node as a child named "FigureSpawner"
# Handles initial figure placement for both teams.
extends Node
class_name FigureSpawner

@export var figure_scene: PackedScene = preload("res://scenes/figure/figure.tscn")

var grid_manager: GridManager


func _ready():
	grid_manager = get_parent()


func spawn_all():
	# Host (Team0, linke Lobby-Haelfte) und Client (Team1, rechte Lobby-Haelfte) stellen
	# ihre Einheiten unabhaengig auf (siehe local_lobby.gd). Reihe 0 = eigene Grundlinie,
	# Reihe 2 = Front Richtung Zentrum. Team0 -> z=Reihe, Team1 -> z=6-Reihe (gespiegelt).
	_spawn_side(PlayerData.battle_formation_left, 0)
	_spawn_side(PlayerData.battle_formation_right, 1)


func _spawn_side(formation: Array, team: int) -> void:
	for row in PlayerData.FORMATION_ROWS:
		for col in PlayerData.FORMATION_COLS:
			var unit_name: String = formation[row * PlayerData.FORMATION_COLS + col]
			if unit_name == "" or unit_name == null:
				continue

			var stats: UnitStats = PlayerData.get_unit_stats(unit_name)
			if stats == null:
				continue

			var z: int = row if team == 0 else 6 - row
			spawn_figure(Vector2i(col, z), team, stats)


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
