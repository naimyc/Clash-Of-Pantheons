extends CanvasLayer

# Referenz zum TurnManager (Stelle sicher, dass der Pfad stimmt!)
@onready var turn_manager = get_node("../TurnManager")

func _process(_delta: float):
	# Spieler 1 UI (Oben Rechts)
	$Topright/GameTimeLabel.text = "Game: " + format_time(turn_manager.player_one.total_game_time)
	
	# Spieler 2 UI (Oben Links)
	$Topleft/EnemyGameTimeLabel.text = "Enemy: " + format_time(turn_manager.player_two.total_game_time)
	
	# Rundenzeit-Anzeige (Nur beim aktiven Spieler)
	if turn_manager.active_player == turn_manager.player_one:
		$Topright/RoundTimeLabel.text = "Round: " + str(int(turn_manager.current_round_time))
		$Topleft/EnemyRoundTimeLabel.text = "Round: --"
	else:
		$Topleft/EnemyRoundTimeLabel.text = "Round: " + str(int(turn_manager.current_round_time))
		$Topright/RoundTimeLabel.text = "Round: --"

	# Elixir/Energie-Leiste
	$Bottomcenter.value = turn_manager.player_one.current_energy

# --- HIER DIE FUNKTION EINFÜGEN ---
func format_time(seconds: float) -> String:
	if seconds < 0: seconds = 0
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]
