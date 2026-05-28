extends CanvasLayer

# --- REFERENZEN AUF UI-ELEMENTE ---
# Linkes Panel für Figurendetails
@onready var left_stats_panel = $LeftStatsPanel
@onready var unit_name_label = $LeftStatsPanel/VBoxContainer/UnitName
@onready var hp_label = $LeftStatsPanel/VBoxContainer/HPLabel
@onready var atk_label = $LeftStatsPanel/VBoxContainer/ATKLabel
@onready var def_label = $LeftStatsPanel/VBoxContainer/DEFLabel

# Kosten-Anzeigen im UI
@onready var move_cost_label = $LeftStatsPanel/VBoxContainer/MoveCostLabel
@onready var attack_cost_label = $LeftStatsPanel/VBoxContainer/AttackCostLabel
@onready var skill_cost_label = $LeftStatsPanel/VBoxContainer/SkillCostLabel

# Top-Panels für Zeit und Runden
@onready var top_left_game_time = $TopLeft/EnemyGameTimeLabel
@onready var top_left_round_time = $TopLeft/EnemyRoundTimeLabel
@onready var top_right_game_time = $TopRight/GameTimeLabel
@onready var top_right_round_time = $TopRight/RoundTimeLabel

# Unteres Panel für Energie (Elixier)
@onready var energy_bar = $BottomCenter/ProgressBar
@onready var energy_text = $BottomCenter/ProgressBar/Label

# --- INITIALISIERUNG ---
func _ready():
	# Verstecht das Statistik-Panel zu Spielbeginn, da keine Figur ausgewählt ist
	if left_stats_panel:
		left_stats_panel.visible = false
		
	# Konfiguriert die Basiswerte für die Energieanzeige (Elixier-Balken) im UI
	if energy_bar:
		energy_bar.min_value = 0
		energy_bar.max_value = 10
		energy_bar.value = 0
		
	# Holt den TurnManager über den eindeutigen Szenennamen (%)
	var turn_manager = get_node_or_null("%TurnManager")
	if turn_manager:
		turn_manager.turn_changed.connect(_on_turn_changed)
		turn_manager.energy_updated.connect(_on_energy_updated)
		
		# Holt die aktuellen Elixier-Daten von Spieler 1, sobald das UI bereit ist
		if turn_manager.player_one:
			_on_energy_updated(turn_manager.player_one.current_energy)

# --- ENGINE-UPDATE-SCHLEIFE ---
# Aktualisiert die Zeitanzeigen auf den Schachuhren in jedem Frame
func _process(_delta):
	var turn_manager = get_node_or_null("../TurnManager")
	if turn_manager == null or turn_manager.active_player == null: return
	
	# Formatiert die verbleibende Zeit des aktiven Spielers
	var round_str = format_time(turn_manager.current_round_time)
	var total_str = format_time(turn_manager.active_player.total_game_time)
	
	# Aktualisiert das UI basierend darauf, wer gerade am Zug ist
	if turn_manager.active_player == turn_manager.player_one:
		if top_right_round_time: top_right_round_time.text = round_str
		if top_right_game_time: top_right_game_time.text = total_str
	else:
		if top_left_round_time: top_left_round_time.text = round_str
		if top_left_game_time: top_left_game_time.text = total_str

# --- LOGIK-METHODEN ---
# Formatiert Sekunden in eine lesbare "MM:SS"-Zeichenkette
func format_time(time_in_seconds: float) -> String:
	var total_secs = max(0, int(time_in_seconds))
	var minutes = total_secs / 60
	var seconds = total_secs % 60
	return "%02d:%02d" % [minutes, seconds]

# Aktualisiert die Anzeige des linken Statistik-Panels mit den korrekten Ressourcendaten
func display_figure_stats(figure: Figure):
	if figure == null or figure.stats == null:
		if left_stats_panel: left_stats_panel.visible = false
		return
		
	if left_stats_panel: left_stats_panel.visible = true
	var s = figure.stats
	var c = s.class_data # Verbindung zu den UnitClassData (Kategorie)
	
	# --- BASISDATEN AUS UNIT_STATS ---
	if unit_name_label: unit_name_label.text = s.unit_name
	if atk_label: atk_label.text = "ATK: " + str(s.atk)
	if hp_label: hp_label.text = "HP: " + str(figure.current_hp) + " / " + str(s.hp)
	if def_label: def_label.visible = false # Deaktiviert, da keine Verteidigung genutzt wird
	
	# Reichweiten aus UnitStats auslesen und anzeigen
	var move_range_label = left_stats_panel.get_node_or_null("VBoxContainer/MoveRangeLabel")
	if move_range_label: move_range_label.text = "Bewegungs-Reichweite: " + str(s.move_range)
	
	var attack_range_label = left_stats_panel.get_node_or_null("VBoxContainer/atkRangeLabel")
	if attack_range_label: attack_range_label.text = "Angriffs-Reichweite: " + str(s.attack_range)
	
	# --- KATEGORIEDATEN AUS UNIT_CLASS_DATA ---
	if c:
		# Zeigt das Kürzel der Kategorie an (K, G, M, P)
		var type_name_label = left_stats_panel.get_node_or_null("VBoxContainer/TypeNameLabel")
		if type_name_label: type_name_label.text = "Kategorie: " + str(c.typ_name)
		
		# EXAKTER FIX: Nutzt die korrekten Elixier-Variablennamen aus deiner Ressource
		if move_cost_label: move_cost_label.text = "Kosten Bewegung: " + str(c.elixir_cost_move)
		if attack_cost_label: attack_cost_label.text = "Kosten Angriff: " + str(c.elixir_cost_atk)
		if skill_cost_label: skill_cost_label.text = "Kosten Skill: " + str(c.elixir_cost_skill)
		
		# Skill-Anzeige umschalten: Wird nur eingeblendet, wenn die Skill-Kosten > 0 sind
		var has_skill = c.elixir_cost_skill > 0
		var skill_container = left_stats_panel.get_node_or_null("VBoxContainer/SkillContainer")
		var skill_name_label = left_stats_panel.get_node_or_null("VBoxContainer/SkillName")
		var skill_dmg_label = left_stats_panel.get_node_or_null("VBoxContainer/SkillDMG")
		
		if skill_container: skill_container.visible = has_skill
		if skill_cost_label: skill_cost_label.visible = has_skill
		
		if has_skill:
			if skill_name_label: skill_name_label.text = "Skill: " + s.skill_name
			if skill_dmg_label: skill_dmg_label.text = "Skill-Schaden: " + str(s.skill_damage)
# Wird aufgerufen, wenn die Energie von Spieler 1 im TurnManager aktualisiert wird
func _on_energy_updated(current_energy: int):
	if energy_bar:
		energy_bar.value = current_energy
	if energy_text:
		energy_text.text = "%d / 10" % current_energy

# Wird aufgerufen, wenn der Rundenwechsel stattfindet
func _on_turn_changed(active_player_ref):
	var turn_manager = get_node_or_null("../TurnManager")
	if turn_manager == null: return
	
	# Setzt die Timer des inaktiven Spielers visuell zurück
	if active_player_ref == turn_manager.player_one:
		if top_left_round_time: top_left_round_time.text = "00:00"
	else:
		if top_right_round_time: top_right_round_time.text = "00:00"
