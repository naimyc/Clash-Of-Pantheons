# grid_manager.gd — thin coordinator.
extends Node
class_name GridManager

signal team_defeated(losing_team: int)

const GRID_SIZE = 7
const TILE_SIZE = 1.0

@export var tile_scene: PackedScene = preload("res://scenes/tile/tile.tscn")

var tiles = {}
var _win_checked: bool = false

@onready var input_manager    = $"../InputManager"
@onready var _battle:  BattleRpc        = $BattleRpc
@onready var _spawner: FigureSpawner    = $FigureSpawner

func _ready(): 	
	_generate_grid()
	if input_manager:
		input_manager.tile_hovered.connect(_on_tile_hovered)
		input_manager.tile_unhovered.connect(_on_tile_unhovered)
		input_manager.tile_clicked.connect(func(t): _battle.on_tile_clicked(t))
	_spawner.spawn_all()

func _generate_grid():
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var tile     = tile_scene.instantiate()
			var mesh     = tile.get_node("MeshInstance3D")
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.8,0.8,0.8) if (x+z)%2==0 else Color(0.2,0.2,0.2)
			mesh.material_override = material
			tile.position      = grid_to_world(Vector2i(x, z))
			tile.grid_position = Vector2i(x, z)
			add_child(tile)
			if input_manager: input_manager.register_tile(tile)
			tiles[Vector2i(x, z)] = tile

func grid_to_world(pos: Vector2i) -> Vector3:
	return Vector3((pos.x - GRID_SIZE/2.0)*TILE_SIZE, 0, (pos.y - GRID_SIZE/2.0)*TILE_SIZE)

func get_tile(coord: Vector2i):
	return tiles.get(coord)

func get_figure_at(pos: Vector2i) -> Figure:
	var t = get_tile(pos)
	if t and t.occupied and is_instance_valid(t.occupying_unit):
		return t.occupying_unit
	for child in get_children():
		if child is Figure and child.grid_position == pos:
			if t and not t.occupied:
				t.occupied = true
				t.occupying_unit = child
				child.current_tile = t
			return child
	return null

func select_figure(fig: Figure):
	_battle.select_figure(fig)

# Wird von TurnManager beim Rundenwechsel aufgerufen
func reset_all_movements():
	$IndicatorManager.clear()
	for child in get_children():
		if child is Figure:
			child.has_moved_this_round      = false
			child.has_attacked_this_round   = false
			child.has_used_skill_this_round = false
			child.has_used_skill_this_round = false

# Wird von TurnManager am Ende der Runde des petrifizierten Teams aufgerufen
func clear_petrification_for_team(team: int) -> void:
	for child in get_children():
		if child is Figure and child.team == team and child.is_petrified:
			child.set_petrified(false)

func _on_tile_hovered(tile):
	tile.set_highlight(true)

func _on_tile_unhovered(tile):
	tile.set_highlight(false)

# --- SIEGBEDINGUNG ---
# Ein Team verliert, sobald sein Basilefs (Klasse "K") stirbt — nicht erst wenn
# das ganze Team ausgeloescht ist (wie ein Koenig beim Schach).
func is_basilefs_alive(team: int) -> bool:
	for child in get_children():
		if child is Figure and child.team == team and child.current_hp > 0:
			if child.stats and child.stats.class_data and child.stats.class_data.typ_name == "K":
				return true
	return false

func check_win_condition() -> void:
	if _win_checked:
		return
	for team in [0, 1]:
		if not is_basilefs_alive(team):
			_win_checked = true
			team_defeated.emit(team)
			return
