extends Node

# --- SIGNALE ---
signal turn_changed(active_player_ref)
signal energy_updated(my_energy: int, opponent_energy: int)

# --- INTERNE KLASSEN ---
class PlayerState:
	var total_game_time: float = 300.0
	var current_energy: int = 0
	var time_bonus: float = 0.0
	var is_active: bool = false
	var peer_id: int = 0

# --- VARIABLEN UND CONFIG ---
var player_one = PlayerState.new()   # always the host (peer_id 1)
var player_two = PlayerState.new()   # always the client
var active_player: PlayerState

const MAX_ENERGY: int = 10
const ENERGY_PER_ROUND: int = 2
const BASE_ROUND_TIME: float = 10.0

var current_round_time: float = 0.0

const SYNC_INTERVAL: float = 1.0
var _sync_timer: float = 0.0

# --- INITIALISIERUNG ---
func _ready():
	player_one.peer_id = 1

	if not is_offline():
		if not multiplayer.is_server():
			player_two.peer_id = multiplayer.get_unique_id()
		else:
			player_two.peer_id = 2
			multiplayer.peer_connected.connect(func(id):
				player_two.peer_id = id
			)
	else:
		player_two.peer_id = 2

	active_player = player_one
	player_one.is_active = true
	start_new_round()
	call_deferred("_connect_end_round_button")

# --- OFFLINE-ERKENNUNG ---
# Godot setzt multiplayer_peer NIE auf null — ohne echte Verbindung steht dort ein
# OfflineMultiplayerPeer-Platzhalter. Nur darauf zu pruefen ("== null") erkennt lokales
# Hotseat-Spiel faelschlich als "online" und bricht die Zug-/Team-Logik.
func is_offline() -> bool:
	var peer = multiplayer.multiplayer_peer
	return peer == null or peer is OfflineMultiplayerPeer

# --- TEAM HELPER ---
# In lokalem Hotseat (kein echter Netzwerk-Peer) steuert der eine lokale Client abwechselnd
# beide Seiten, daher folgt "mein Team" hier dem gerade aktiven Spieler.
func get_my_team() -> int:
	if is_offline():
		return team_of(active_player)
	var my_id = multiplayer.get_unique_id()
	return 1 if my_id == 1 else 0

# Maps a PlayerState (player_one/player_two) to the figure "team" int used by GridManager/Figure.
# player_one (Host) = Team 0 (figure_spawner spawnt battle_formation_left als Team0/Host).
func team_of(player) -> int:
	return 0 if player == player_one else 1

# --- HELPER METHOD TO CHECK LOCAL AUTHORITY ---
func is_my_turn() -> bool:
	if is_offline():
		# Lokales Hotseat: keine Netzwerk-Autoritaet noetig, beide Spielerzuege sind lokal erlaubt.
		return true
	return active_player.peer_id == multiplayer.get_unique_id()

# --- PROZESS-SCHLEIFE ---
func _process(delta: float):
	var is_online = not is_offline()
	var is_server = not is_online or multiplayer.is_server()

	if active_player.total_game_time > 0 and current_round_time > 0:
		current_round_time            -= delta
		active_player.total_game_time -= delta

		if is_server:
			if current_round_time <= 0:
				end_current_round()
				return
			_sync_timer -= delta
			if _sync_timer <= 0 and is_online:
				_sync_timer = SYNC_INTERVAL
				rpc("sync_time_tick",
					active_player == player_one,
					current_round_time,
					active_player.total_game_time)

# --- ELIXIER VERBRAUCHEN ---
# Only called on the server. Broadcasts updated energy to client immediately.
func spend_energy(amount: int):
	if active_player == null: return
	active_player.current_energy = max(0, active_player.current_energy - amount)

	# Push the authoritative energy values to the client right away
	if not is_offline():
		rpc("sync_energy", player_one.current_energy, player_two.current_energy)

	_emit_energy()

	if active_player.current_energy <= 0:
		if is_offline() or multiplayer.is_server():
			end_current_round()
		else:
			rpc_id(1, "request_end_round")

# Emits the energy signal with the correct (my, opponent) ordering per window.
func _emit_energy():
	var my_id = multiplayer.get_unique_id() if not is_offline() else 1
	if my_id == 1:
		energy_updated.emit(player_one.current_energy, player_two.current_energy)
	else:
		energy_updated.emit(player_two.current_energy, player_one.current_energy)

# Lightweight RPC: client receives authoritative energy and updates its local state + UI.
@rpc("authority", "call_remote", "reliable")
func sync_energy(p1_energy: int, p2_energy: int):
	player_one.current_energy = p1_energy
	player_two.current_energy = p2_energy
	_emit_energy()

# --- RUNDEN-LOGIK ---
func start_new_round():
	current_round_time = BASE_ROUND_TIME + active_player.time_bonus
	active_player.time_bonus = 0.0
	_sync_timer = SYNC_INTERVAL

	active_player.current_energy = clampi(
		active_player.current_energy + ENERGY_PER_ROUND, 0, MAX_ENERGY)

	_emit_energy()
	turn_changed.emit(active_player)

	var grid_manager = get_node_or_null("../GridManager")
	if grid_manager and grid_manager.has_method("reset_all_movements"):
		grid_manager.reset_all_movements()

func end_current_round():
	if not is_offline() and not multiplayer.is_server():
		rpc_id(1, "request_end_round")
		return

	var remaining_time = max(0, current_round_time)
	active_player.time_bonus = remaining_time * 0.5

	# Team, dessen Runde gerade endet, wird entpetrifiziert – jetzt netzwerkweit
	var team_to_clear = team_of(active_player)
	if not is_offline():
		rpc("sync_clear_petrification", team_to_clear)
	else:
		var gm = get_node_or_null("../GridManager")
		if gm and gm.has_method("clear_petrification_for_team"):
			gm.clear_petrification_for_team(team_to_clear)

	active_player.is_active = false
	active_player = player_two if active_player == player_one else player_one
	active_player.is_active = true

	start_new_round()
	# Send AFTER start_new_round so the energy values already include
	# the ENERGY_PER_ROUND that was just added for the new active player.
	if not is_offline():
		rpc("sync_round_state",
			active_player == player_one,
			current_round_time,
			player_one.current_energy,
			player_two.current_energy)

# --- RPC NETWORK SYNCHRONIZATION ---
@rpc("any_peer", "call_local", "reliable")
func request_end_round():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	# sender_id ist 0 bei lokalem call_local-Aufruf auf dem Host selbst;
	# in dem Fall ist der Host per _on_bottomright_pressed schon geprüft.
	if sender_id != 0 and sender_id != active_player.peer_id:
		return   # falscher Spieler hat versucht, die Runde zu beenden
	end_current_round()

@rpc("authority", "call_remote", "reliable")
func sync_round_state(is_p1_active: bool, server_round_time: float,
		p1_energy: int, p2_energy: int):
	current_round_time = server_round_time
	active_player.is_active = false
	active_player = player_one if is_p1_active else player_two
	active_player.is_active = true
	player_one.current_energy = p1_energy
	player_two.current_energy = p2_energy
	_emit_energy()
	turn_changed.emit(active_player)
	# Reset movement flags on client — start_new_round() only runs on server
	var gm = get_node_or_null("../GridManager")
	if gm and gm.has_method("reset_all_movements"):
		gm.reset_all_movements()

@rpc("authority", "call_remote", "unreliable")
func sync_time_tick(is_p1_active: bool, server_round_time: float, server_total_time: float):
	if abs(current_round_time - server_round_time) > 0.5:
		current_round_time = server_round_time
	if is_p1_active:
		if abs(player_one.total_game_time - server_total_time) > 0.5:
			player_one.total_game_time = server_total_time
	else:
		if abs(player_two.total_game_time - server_total_time) > 0.5:
			player_two.total_game_time = server_total_time
			
@rpc("authority", "call_local", "reliable")
func sync_clear_petrification(team: int) -> void:
	var gm = get_node_or_null("../GridManager")
	if gm and gm.has_method("clear_petrification_for_team"):
		gm.clear_petrification_for_team(team)

# --- SIGNALEINGÄNGE ---
# Tries to auto-connect to the end-round button by common node names.
# This runs in _ready so the button works even if the editor signal was never wired.
func _connect_end_round_button():
	# Try common paths — adjust if your button has a different name
	var candidates = [
		"../GameUI/BottomRight",
		"../GameUI/BottomCenter/EndRoundButton",
		"../GameUI/EndRoundButton",
		"../GameUI/SkipButton",
		"%EndRoundButton",
		"%BottomRight",
		"%SkipButton",
	]
	for path in candidates:
		var btn = get_node_or_null(path)
		if btn and btn.has_signal("pressed"):
			if not btn.pressed.is_connected(_on_bottomright_pressed):
				btn.pressed.connect(_on_bottomright_pressed)
				print("[TurnManager] End round button connected: ", path)
			return
	print("[TurnManager] WARNING: End round button not found — wire it manually in the editor or add its path to _connect_end_round_button()")

func _on_bottomright_pressed() -> void:
	if not is_my_turn():
		return
	# Waehrend die Kamera zur anderen Seite ueberblendet, keine Runde beenden koennen.
	var cs = get_node_or_null("../CameraSwitcher")
	if cs and cs.is_transitioning():
		return
	end_current_round()
