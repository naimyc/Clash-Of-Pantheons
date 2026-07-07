# game_over_overlay.gd — Sieg-Anzeige am Ende einer Partie.
# Zeigt explizit, WER gewonnen hat (Host/Client), mit Eintritts-Animation, und bietet
# "Zurueck zum Menue", "Nochmal [aktueller Modus] spielen" und "[anderer Modus] spielen" an.
extends CanvasLayer

@onready var panel             : PanelContainer = $Panel
@onready var result_label      : Label           = $Panel/VBox/ResultLabel
@onready var menu_button       : Button          = $Panel/VBox/MenuButton
@onready var replay_button     : Button          = $Panel/VBox/ReplayButton
@onready var other_mode_button : Button          = $Panel/VBox/OtherModeButton
@onready var other_mode_info   : Label           = $Panel/VBox/OtherModeInfo


func _ready() -> void:
	panel.visible = false
	other_mode_info.visible = false

	await get_tree().process_frame
	panel.pivot_offset = panel.size / 2.0

	var gm = get_node_or_null("%GridManager")
	if gm:
		gm.team_defeated.connect(_on_team_defeated)

	menu_button.pressed.connect(_on_menu_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	other_mode_button.pressed.connect(_on_other_mode_pressed)
	_setup_mode_buttons()


func _setup_mode_buttons() -> void:
	if PlayerData.last_match_mode == "local":
		replay_button.text     = "Nochmal lokal spielen"
		other_mode_button.text = "Multiplayer spielen"
	else:
		replay_button.text     = "Nochmal Multiplayer spielen"
		other_mode_button.text = "Lokal spielen"


func _on_team_defeated(losing_team: int) -> void:
	# Team 0 = Host, Team 1 = Client (siehe figure_spawner.gd / local_lobby.gd).
	var winner_name = "HOST" if losing_team == 1 else "CLIENT"
	result_label.text = winner_name + " GEWINNT!"

	# Team 0 = der lokale Spieler fuer die Belohnungen (Spiegel-Match ohne echten Server-Gegner).
	if losing_team == 1:
		PlayerData.add_match_rewards()

	panel.visible = true
	_play_entrance_animation()


func _play_entrance_animation() -> void:
	panel.scale = Vector2(0.4, 0.4)
	panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.35)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu/menu.tscn")


func _on_replay_pressed() -> void:
	if PlayerData.last_match_mode == "local":
		get_tree().change_scene_to_file("res://scenes/Lobby/local_lobby.tscn")
	else:
		# Multiplayer ist (noch) nicht implementiert.
		get_tree().change_scene_to_file("res://scenes/Menu/menu.tscn")


func _on_other_mode_pressed() -> void:
	if PlayerData.last_match_mode == "local":
		# Der "andere" Modus waere Multiplayer — absichtlich funktionslos, kein Server vorhanden.
		other_mode_info.text = "Multiplayer nicht verfuegbar - kein Server"
		other_mode_info.visible = true
	else:
		get_tree().change_scene_to_file("res://scenes/Lobby/local_lobby.tscn")
