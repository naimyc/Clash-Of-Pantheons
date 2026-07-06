# indicator_manager.gd — attach to GridManager as child named "IndicatorManager"
# Spawns and clears the animated X markers (move) and spinning rings (attack).
extends Node
class_name IndicatorManager

var grid_manager:  GridManager
var battle_rpc:    BattleRpc
var _nodes:        Array = []   # spawned Node3D indicators
var _atk_tiles:    Array = []   # tiles with attack-target figures
var _skill_nodes:  Array = []   # purple skill-target indicators
var _skill_tiles:  Array = []   # tiles with skill targets

func _ready():
	grid_manager = get_parent()
	if grid_manager:
		battle_rpc = grid_manager.get_node_or_null("BattleRpc")

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func clear():
	for n in _nodes:
		if is_instance_valid(n): n.queue_free()
	_nodes.clear()
	for n in _skill_nodes:
		if is_instance_valid(n): n.queue_free()
	_skill_nodes.clear()
	for tile in _atk_tiles:
		if is_instance_valid(tile) and tile.occupied and is_instance_valid(tile.occupying_unit):
			tile.occupying_unit.set_attack_target(false)
	_atk_tiles.clear()
	for tile in _skill_tiles:
		if is_instance_valid(tile) and tile.occupied and is_instance_valid(tile.occupying_unit):
			tile.occupying_unit.set_attack_target(false)
	_skill_tiles.clear()


func show_for(figure: Figure):
	clear()
	var pf: Pathfinder = grid_manager.get_node_or_null("Pathfinder")
	if pf == null: return

	# Petrifizierte Einheiten können nichts tun — keine Indikatoren zeigen
	if not figure.can_act(): return

	if not figure.has_moved_this_round:
		for pos in pf.get_valid_moves(figure):
			var t = grid_manager.get_tile(pos)
			if t: _spawn_move_x(t.global_position)

	if not figure.has_attacked_this_round:
		for pos in pf.get_valid_attacks(figure):
			var t = grid_manager.get_tile(pos)
			if not t: continue
			_atk_tiles.append(t)
			if t.occupied and is_instance_valid(t.occupying_unit):
				t.occupying_unit.set_attack_target(true)
				_spawn_attack_ring(t.occupying_unit.global_position)

func show_skill_for(figure: Figure):
	clear()
	var pf: Pathfinder = grid_manager.get_node_or_null("Pathfinder")
	if pf == null: return
	for pos in pf.get_valid_attacks(figure):
		var t = grid_manager.get_tile(pos)
		if not t: continue
		_skill_tiles.append(t)
		if t.occupied and is_instance_valid(t.occupying_unit):
			t.occupying_unit.set_attack_target(true)
			_spawn_skill_ring(t.occupying_unit.global_position)

# ---------------------------------------------------------------------------
# MOVE INDICATOR — animated blue X
# ---------------------------------------------------------------------------
func _spawn_move_x(world_pos: Vector3) -> void:
	var root = Node3D.new()
	grid_manager.add_child(root)
	root.global_position = world_pos + Vector3(0, 0.1, 0)
	_nodes.append(root)

	var mat        = StandardMaterial3D.new()
	mat.albedo_color               = Color(0.25, 0.65, 1.0)
	mat.emission_enabled           = true
	mat.emission                   = Color(0.1, 0.5, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED

	for angle in [45.0, -45.0]:
		var arm  = MeshInstance3D.new()
		var box  = BoxMesh.new()
		box.size = Vector3(0.72, 0.04, 0.10)
		arm.mesh = box
		arm.rotation_degrees.y  = angle
		arm.material_override   = mat
		root.add_child(arm)

	var tw = root.create_tween().set_loops()
	tw.tween_property(root, "scale", Vector3(1.15, 1.0, 1.15), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "scale", Vector3(0.88, 1.0, 0.88), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "scale", Vector3(1.0,  1.0, 1.0),  0.25).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------------------
# ATTACK INDICATOR — spinning red ring
# ---------------------------------------------------------------------------
func _spawn_attack_ring(world_pos: Vector3) -> void:
	var mi  = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius  = 0.38
	tor.outer_radius  = 0.50
	tor.rings         = 32
	tor.ring_segments = 12
	mi.mesh           = tor

	var mat = StandardMaterial3D.new()
	mat.albedo_color               = Color(1.0, 0.2, 0.05, 0.95)
	mat.emission_enabled           = true
	mat.emission                   = Color(1.0, 0.1, 0.0)
	mat.emission_energy_multiplier = 2.2
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	grid_manager.add_child(mi)
	mi.global_position = world_pos + Vector3(0, 0.35, 0)
	_nodes.append(mi)

	var tw = mi.create_tween().set_loops()
	tw.set_parallel(true)
	tw.tween_property(mi, "rotation_degrees:y", 360.0, 1.2).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(mi, "position:y", world_pos.y + 0.55, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(mi, "position:y", world_pos.y + 0.35, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------------
# SKILL INDICATOR — pulsierender lilaner Ring (dreht sich gegenläufig)
# ---------------------------------------------------------------------------
func _spawn_skill_ring(world_pos: Vector3) -> void:
	var mi  = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius  = 0.35
	tor.outer_radius  = 0.52
	tor.rings         = 32
	tor.ring_segments = 12
	mi.mesh           = tor

	var mat = StandardMaterial3D.new()
	mat.albedo_color               = Color(0.80, 0.20, 1.0, 0.95)
	mat.emission_enabled           = true
	mat.emission                   = Color(0.65, 0.05, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	grid_manager.add_child(mi)
	mi.global_position = world_pos + Vector3(0, 0.40, 0)
	_skill_nodes.append(mi)

	# Gegenläufige Rotation + Puls-Skalierung — klar erkennbar als Skill-Ziel
	var tw = mi.create_tween().set_loops()
	tw.set_parallel(true)
	tw.tween_property(mi, "rotation_degrees:y", -360.0, 0.9).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(mi, "scale", Vector3(1.18, 1.0, 1.18), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(mi, "scale", Vector3(0.85, 1.0, 0.85), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
