extends Node

# Signale für die Kommunikation mit der UI
signal turn_changed(active_player_ref)
signal energy_updated(player_one_energy)

class PlayerState:
	var total_game_time: float = 300.0 # 5 Minuten Gesamtzeit in Sekunden
	var current_energy: int = 0        # Aktuelle Energie (Elixier)
	var time_bonus: float = 0.0        # Gespeicherter Bonus für die nächste Runde
	var is_active: bool = false

# Variablen-Namen bleiben auf Englisch
var player_one = PlayerState.new()
var player_two = PlayerState.new()
var active_player: PlayerState

const MAX_ENERGY: int = 10
const ENERGY_PER_ROUND: int = 2
const BASE_ROUND_TIME: float = 10.0

var current_round_time: float = 0.0

func _ready():
	# Initialisierung des Spielstarts
	active_player = player_one
	player_one.is_active = true
	start_new_round()

func _process(delta: float):
	# Ablauf der Zeit nur für den aktiven Spieler
	if active_player.total_game_time > 0 and current_round_time > 0:
		current_round_time -= delta
		active_player.total_game_time -= delta
		
		# Automatisches Rundenende bei Zeitablauf
		if current_round_time <= 0:
			end_current_round()

func start_new_round():
	# Berechnung der Rundenzeit: Basis (10s) + 50% der übrig gebliebenen Zeit
	current_round_time = BASE_ROUND_TIME + active_player.time_bonus
	active_player.time_bonus = 0.0 # Bonus zurücksetzen nach Anwendung
	
	# Energie-Regeneration (maximal 10 Einheiten)
	active_player.current_energy = clampi(active_player.current_energy + ENERGY_PER_ROUND, 0, MAX_ENERGY)
	
	# UI Signale senden
	emit_signal("energy_updated", player_one.current_energy)
	emit_signal("turn_changed", active_player)

func end_current_round():
	# 50% der verbleibenden Zeit als Bonus für den nächsten Zug speichern
	var remaining_time = max(0, current_round_time)
	active_player.time_bonus = remaining_time * 0.5
	
	# Spielerwechsel-Logik
	active_player.is_active = false
	if active_player == player_one:
		active_player = player_two
	else:
		active_player = player_one
	active_player.is_active = true
	
	start_new_round()

func _on_bottomright_pressed() -> void:
	# Nur beenden, wenn Spieler 1 (der Mensch) aktiv ist
	if active_player == player_one:
		end_current_round()
