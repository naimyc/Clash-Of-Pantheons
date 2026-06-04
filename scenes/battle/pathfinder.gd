# pathfinder.gd — attach to GridManager node as a child named "Pathfinder"
# Handles all BFS movement and attack range calculations.
extends Node
class_name Pathfinder

var grid_manager: GridManager

func _ready():
	grid_manager = get_parent()

func get_directions(move_type: String) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if move_type == "Orthogonal" or move_type == "all":
		dirs.append_array([Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT])
	if move_type == "all":
		dirs.append_array([Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
	if dirs.is_empty():
		dirs.append_array([Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT])
	return dirs

func get_valid_moves(figure: Figure) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	if figure == null or figure.stats == null or figure.stats.class_data == null:
		return valid

	var start    = figure.grid_position
	var max_dist = figure.stats.move_range
	var dirs     = get_directions(figure.stats.class_data.movement_type)
	var queue    = [{"pos": start, "dist": 0}]
	var visited  = {start: true}

	while queue.size() > 0:
		var cur      = queue.pop_front()
		var pos      = cur["pos"]
		var dist     = cur["dist"]
		if pos != start:
			valid.append(pos)
		if dist >= max_dist:
			continue
		for dir in dirs:
			var next = pos + dir
			if not visited.has(next):
				var t = grid_manager.get_tile(next)
				if t == null or t.occupied:
					continue
				visited[next] = true
				queue.append({"pos": next, "dist": dist + 1})
	return valid

func get_valid_attacks(figure: Figure) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	if figure == null or figure.stats == null or figure.stats.class_data == null:
		return valid

	var start     = figure.grid_position
	var max_range = figure.stats.attack_range if "attack_range" in figure.stats else 1
	var dirs      = get_directions(figure.stats.class_data.movement_type)

	for dir in dirs:
		for i in range(1, max_range + 1):
			var target = start + dir * i
			var t      = grid_manager.get_tile(target)
			if t == null: break
			if t.occupied:
				if t.occupying_unit and t.occupying_unit.team != figure.team:
					valid.append(target)
				break
	return valid
