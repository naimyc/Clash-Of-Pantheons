# battle_rpc.gd — attach to GridManager as child named "BattleRpc"
# Owns all @rpc functions for move and attack, plus select/click input handling.
extends Node
class_name BattleRpc

var grid_manager: GridManager
var selected_figure: Figure = null

func _ready():
	grid_manager = get_parent()

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _tm():    return grid_manager.get_node_or_null("%TurnManager")
func _ui():    return grid_manager.get_node_or_null("%GameUI")
func _cam():   return grid_manager.get_viewport().get_camera_3d()
func _pf()  -> Pathfinder:         return grid_manager.get_node_or_null("Pathfinder")
func _ind() -> IndicatorManager:   return grid_manager.get_node_or_null("IndicatorManager")

func deselect():
	if selected_figure:
		selected_figure.set_selected(false)
	selected_figure = null
	_ind().clear()
	var ui = _ui()
	if ui: ui.display_figure_stats(null)
	var cam = _cam()
	if cam and cam.has_method("on_figure_deselected"):
		cam.on_figure_deselected()

# ---------------------------------------------------------------------------
# FIGURE CLICK (called by Figure.gd)
# ---------------------------------------------------------------------------
func select_figure(clicked: Figure):
	var tm = _tm()
	if not tm: return
	var my_turn = tm.is_my_turn()
	var my_team = tm.get_my_team()

	# Attack if enemy clicked while own figure selected
	if selected_figure and selected_figure.team == my_team \
			and clicked.team != my_team and my_turn:
		if not selected_figure.has_attacked_this_round:
			var attacks = _pf().get_valid_attacks(selected_figure)
			if clicked.grid_position in attacks:
				var cost = selected_figure.stats.class_data.elixir_cost_atk \
						if selected_figure.stats.class_data else 1
				if tm.active_player.current_energy >= cost:
					var from = selected_figure.grid_position
					var to   = clicked.grid_position
					if not multiplayer.is_server():
						rpc_id(1, "request_attack", from, to, cost)
					else:
						var dmg = selected_figure.stats.attack if "attack" in selected_figure.stats else 10
						rpc("apply_attack", from, to, dmg, cost)
				return

	# Select
	if selected_figure != clicked:
		if selected_figure: selected_figure.set_selected(false)
		selected_figure = clicked
		selected_figure.set_selected(true)
		var ui = _ui()
		if ui: ui.display_figure_stats(clicked)

	if my_turn and clicked.team == my_team:
		_ind().show_for(selected_figure)
		var cam = _cam()
		if cam and cam.has_method("on_figure_selected"):
			var move_pos: Array[Vector3] = []
			for pos in _pf().get_valid_moves(selected_figure):
				var t = grid_manager.get_tile(pos)
				if t: move_pos.append(t.global_position)
			cam.on_figure_selected(clicked.global_position, move_pos)
	else:
		_ind().clear()

# ---------------------------------------------------------------------------
# TILE CLICK (connected from GridManager)
# ---------------------------------------------------------------------------
func on_tile_clicked(tile):
	if selected_figure == null: return
	if tile.grid_position == selected_figure.grid_position: return
	var tm = _tm()
	if not tm: return
	if selected_figure.team != tm.get_my_team():
		deselect(); return
	if not tm.is_my_turn(): return

	var valid = _pf().get_valid_moves(selected_figure)
	if tile.grid_position in valid:
		if selected_figure.has_moved_this_round: return
		var cost = selected_figure.stats.class_data.elixir_cost_move \
				if selected_figure.stats.class_data else 1
		if tm.active_player.current_energy < cost: return
		var from = selected_figure.grid_position
		var to   = tile.grid_position
		if not multiplayer.is_server():
			rpc_id(1, "request_move", from, to, cost)
		else:
			rpc("apply_move", from, to, cost)
	else:
		deselect()

# ---------------------------------------------------------------------------
# RPC — MOVE
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func request_move(from: Vector2i, to: Vector2i, cost: int):
	if not multiplayer.is_server(): return
	var tm  = _tm()
	if not tm: return
	var fig = grid_manager.get_figure_at(from)
	if fig == null or fig.has_moved_this_round: return
	if tm.active_player.current_energy < cost: return
	if not to in _pf().get_valid_moves(fig): return
	rpc("apply_move", from, to, cost)

@rpc("authority", "call_local", "reliable")
func apply_move(from: Vector2i, to: Vector2i, cost: int):
	var fig     = grid_manager.get_figure_at(from)
	var to_tile = grid_manager.get_tile(to)
	if fig == null or to_tile == null: return
	fig.move_to(to_tile, true)
	fig.has_moved_this_round = true
	var tm = _tm()
	if tm and (multiplayer.multiplayer_peer == null or multiplayer.is_server()):
		tm.spend_energy(cost)
	if selected_figure == fig:
		_ind().show_for(fig)

# ---------------------------------------------------------------------------
# RPC — ATTACK
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func request_attack(from: Vector2i, target: Vector2i, cost: int):
	if not multiplayer.is_server(): return
	var tm  = _tm()
	if not tm: return
	var atk = grid_manager.get_figure_at(from)
	var def = grid_manager.get_figure_at(target)
	if atk == null or def == null: return
	if atk.has_attacked_this_round or atk.team == def.team: return
	if tm.active_player.current_energy < cost: return
	if not target in _pf().get_valid_attacks(atk): return
	var cam = _cam()
	if cam and cam.has_method("on_attack_fired"):
		var atk_t = grid_manager.get_tile(from)
		var def_t = grid_manager.get_tile(target)
		cam.on_attack_fired(
			atk_t.global_position if atk_t else Vector3.ZERO,
			def_t.global_position if def_t else Vector3.ZERO)
	rpc("apply_attack", from, target, atk.stats.attack if "attack" in atk.stats else 10, cost)

@rpc("authority", "call_local", "reliable")
func apply_attack(from: Vector2i, target: Vector2i, damage: int, cost: int):
	var atk = grid_manager.get_figure_at(from)
	var def = grid_manager.get_figure_at(target)
	if atk == null or def == null: return
	atk.has_attacked_this_round = true
	def.take_damage(damage)
	var tm = _tm()
	if tm and (multiplayer.multiplayer_peer == null or multiplayer.is_server()):
		tm.spend_energy(cost)
	if def.current_hp <= 0:
		deselect()
	else:
		var ui = _ui()
		if ui and selected_figure == atk: ui.display_figure_stats(def)
		if selected_figure == atk: _ind().show_for(atk)
