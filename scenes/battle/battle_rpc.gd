# battle_rpc.gd — attach to GridManager as child named "BattleRpc"
extends Node
class_name BattleRpc

var grid_manager: GridManager
var selected_figure: Figure = null
var skill_mode: bool = false

func _ready():
	grid_manager = get_parent()

# ---------------------------------------------------------------------------
# SKILL MODE (called from GameUI skill button)
# ---------------------------------------------------------------------------
func toggle_skill_mode():
	if selected_figure == null: return
	if selected_figure.has_used_skill_this_round: return
	var tm = _tm()
	if not tm or not tm.is_my_turn(): return
	if selected_figure.team != tm.get_my_team(): return
	if not selected_figure.can_act(): return
	skill_mode = not skill_mode
	var ind = _ind()
	if ind:
		if skill_mode: ind.show_skill_for(selected_figure)
		else:          ind.show_for(selected_figure)
	var ui = _ui()
	if ui and ui.has_method("set_skill_mode_visual"):
		ui.set_skill_mode_visual(skill_mode)

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _tm():    return grid_manager.get_node_or_null("%TurnManager")
func _ui():    return grid_manager.get_node_or_null("%GameUI")
func _cam():   return grid_manager.get_viewport().get_camera_3d()
func _pf()  -> Pathfinder:         return grid_manager.get_node_or_null("Pathfinder")
func _ind() -> IndicatorManager:   return grid_manager.get_node_or_null("IndicatorManager")

func _cancel_skill_mode():
	skill_mode = false
	if selected_figure: _ind().show_for(selected_figure)
	var ui = _ui()
	if ui and ui.has_method("set_skill_mode_visual"):
		ui.set_skill_mode_visual(false)

func deselect():
	if selected_figure:
		selected_figure.set_selected(false)
	selected_figure = null
	skill_mode = false
	_ind().clear()
	var ui = _ui()
	if ui: ui.display_figure_stats(null)
	var cam = _cam()
	if cam and cam.has_method("on_figure_deselected"):
		cam.on_figure_deselected()

# ---------------------------------------------------------------------------
# FIGURE CLICK
# ---------------------------------------------------------------------------
func select_figure(clicked: Figure):
	var tm = _tm()
	if not tm: return
	var my_turn = tm.is_my_turn()
	var my_team = tm.get_my_team()

	# Skill target: own figure selected, skill_mode active, enemy clicked
	if skill_mode and selected_figure and selected_figure.team == my_team \
			and clicked.team != my_team and my_turn:
		var skill_range = _pf().get_valid_attacks(selected_figure)
		if clicked.grid_position in skill_range \
				and not selected_figure.has_used_skill_this_round \
				and selected_figure.can_act():
			var cost = selected_figure.stats.class_data.elixir_cost_skill \
					if selected_figure.stats.class_data else 1
			if tm.active_player.current_energy >= cost:
				var from = selected_figure.grid_position
				var to   = clicked.grid_position
				if not multiplayer.is_server():
					rpc_id(1, "request_skill", from, to, cost)
				else:
					rpc("apply_skill", from, to, cost)
		_cancel_skill_mode()
		return

	# Klick auf eigene Figur im Skill-Modus → Skill-Modus abbrechen
	if skill_mode:
		_cancel_skill_mode()

	# Attack if enemy clicked while own figure selected
	if selected_figure and selected_figure.team == my_team \
			and clicked.team != my_team and my_turn:
		if not selected_figure.has_attacked_this_round and selected_figure.can_act():
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
# TILE CLICK
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
	if skill_mode:
		_cancel_skill_mode()
		return
	if tile.grid_position in valid:
		if selected_figure.has_moved_this_round or not selected_figure.can_act(): return
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
	var tm = _tm()
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
		deselect()

# ---------------------------------------------------------------------------
# RPC — ATTACK
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func request_attack(from: Vector2i, target: Vector2i, cost: int):
	if not multiplayer.is_server(): return
	var tm = _tm()
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

	# Attack-Animation abspielen, auf Hit-Frame warten
	var hit_signal = atk.play_attack_animation(def.global_position)
	await hit_signal
	if not is_instance_valid(def): return

	def.take_damage(damage)
	var tm = _tm()
	if tm and (multiplayer.multiplayer_peer == null or multiplayer.is_server()):
		tm.spend_energy(cost)
	if selected_figure == atk:
		deselect()

# ---------------------------------------------------------------------------
# RPC — SKILL
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func request_skill(from: Vector2i, target: Vector2i, cost: int):
	if not multiplayer.is_server(): return
	var tm = _tm()
	if not tm: return
	var caster = grid_manager.get_figure_at(from)
	var def    = grid_manager.get_figure_at(target)
	if caster == null or def == null: return
	if caster.has_used_skill_this_round or not caster.can_act() or caster.team == def.team: return
	if tm.active_player.current_energy < cost: return
	if not target in _pf().get_valid_attacks(caster): return
	rpc("apply_skill", from, target, cost)

@rpc("authority", "call_local", "reliable")
func apply_skill(from: Vector2i, target: Vector2i, cost: int):
	var caster = grid_manager.get_figure_at(from)
	var def    = grid_manager.get_figure_at(target)
	if caster == null or def == null: return
	caster.has_used_skill_this_round = true

	# Skill-Animation abspielen, auf Trigger-Frame warten
	var trigger_signal = caster.play_skill_animation(def.global_position)
	await trigger_signal
	if not is_instance_valid(def): return

	# Skill effect dispatch
	var skill_name = caster.stats.skill_name if caster.stats else ""
	match skill_name:
		"petrification":
			def.set_petrified(true)
			# Broadcast: alle Clients sollen den Effekt zeigen
			if multiplayer.multiplayer_peer != null and multiplayer.is_server():
				rpc("sync_petrification", target, true)
		_:
			pass

	var tm = _tm()
	if tm and (multiplayer.multiplayer_peer == null or multiplayer.is_server()):
		tm.spend_energy(cost)
	if selected_figure == caster:
		deselect()

# Sync-Broadcast damit Client den Petrifizierungs-Effekt visuell zeigt
@rpc("authority", "call_local", "reliable")
func sync_petrification(target: Vector2i, value: bool):
	var fig = grid_manager.get_figure_at(target)
	if fig: fig.set_petrified(value)

# Löst Petrifizierung nach Runde auf allen Peers auf
@rpc("authority", "call_local", "reliable")
func sync_clear_petrification(team: int):
	if grid_manager and grid_manager.has_method("clear_petrification_for_team"):
		grid_manager.clear_petrification_for_team(team)
