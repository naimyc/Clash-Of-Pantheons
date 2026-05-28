extends Node

# --- SIGNALE ---
# Signale für die Kommunikation mit der Benutzeroberfläche (UI)
signal turn_changed(active_player_ref)
signal energy_updated(player_one_energy) # Signal fixiert auf Spieler 1

# --- INTERNE KLASSEN ---
# Speicherstruktur für den Zustand des jeweiligen Spielers
class PlayerState:
	var total_game_time: float = 300.0 # 5 Minuten Gesamtzeit auf der Schachuhr
	var current_energy: int = 0        # Aktuelles Elixier für Bewegungen/Aktionen
	var time_bonus: float = 0.0        # Zeitgutschrift für den nächsten Zug
	var is_active: bool = false

# --- VARIABLEN UND CONFIG ---
var player_one = PlayerState.new()
var player_two = PlayerState.new()
var active_player: PlayerState

const MAX_ENERGY: int = 10
const ENERGY_PER_ROUND: int = 2
const BASE_ROUND_TIME: float = 10.0

var current_round_time: float = 0.0

# --- INITIALISIERUNG ---
func _ready():
	# Spieler 1 (Mensch) startet das Spiel
	active_player = player_one
	player_one.is_active = true
	start_new_round()

# --- PROZESS-SCHLEIFE ---
# Aktualisiert die Timer in jedem Frame (nur für den aktiven Spieler)
func _process(delta: float):
	if active_player.total_game_time > 0 and current_round_time > 0:
		current_round_time -= delta
		active_player.total_game_time -= delta
		
		# Automatischer Rundenwechsel bei Zeitablauf
		if current_round_time <= 0:
			end_current_round()

# --- ELIXIER VERBRAUCHEN ---
# Zieht Elixier ab und beendet die Runde automatisch, wenn das Elixier leer ist
func spend_energy(amount: int):
	if active_player == null: return
	
	# Energie für den aktuell aktiven Spieler abziehen
	active_player.current_energy = max(0, active_player.current_energy - amount)
	
	# WICHTIGER FIX: Sendet IMMER NUR das Elixier von Spieler 1 (Mensch) an die UI!
	# Wenn der Gegner Energie verbraucht, bleibt deine Anzeige auf dem Bildschirm unverändert.
	energy_updated.emit(player_one.current_energy)
	
	# Wenn das Elixier des aktiven Spielers (egal ob Spieler oder Gegner) 0 erreicht, Runde beenden
	if active_player.current_energy <= 0:
		call_deferred("end_current_round")

# --- RUNDEN-LOGIK ---
# Startet den Zug des neuen aktiven Spielers und regeneriert Ressourcen
func start_new_round():
	# Berechnet die Rundenzeit: Basiszeit (10s) + 50% der gesparten Restzeit
	current_round_time = BASE_ROUND_TIME + active_player.time_bonus
	active_player.time_bonus = 0.0 # Bonus nach Anwendung zurücksetzen
	
	# Elixier-Regeneration für den aktiven Spieler
	active_player.current_energy = clampi(active_player.current_energy + ENERGY_PER_ROUND, 0, MAX_ENERGY)
	
	# WICHTIGER FIX: Auch beim Rundenwechsel wird der UI IMMER NUR das Elixier von Spieler 1 übergeben.
	# Dadurch wird deine Bar niemals mit den Werten des Gegners überschrieben.
	energy_updated.emit(player_one.current_energy)
	turn_changed.emit(active_player)
	
	# Setzt die Bewegungsrechte aller Figuren auf dem Spielfeld zurück
	var grid_manager = get_node_or_null("../GridManager")
	if grid_manager and grid_manager.has_method("reset_all_movements"):
		grid_manager.reset_all_movements()

# Beendet den aktuellen Zug und berechnet Zeitboni für Schnelligkeit
func end_current_round():
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

# --- SIGNALEINGÄNGE ---
# Wird aufgerufen, wenn der Spieler manuell auf den "End Turn"-Button klickt
func _on_bottomright_pressed() -> void:
	# Verhindert, dass der Spieler den Zug des Gegners (KI) abbrechen kann
	if active_player == player_one:
		end_current_round()
