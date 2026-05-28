extends Node3D
class_name Figure

# --- SIGNALE ---
# Wird abgefeuert, wenn die Figur direkt angeklickt wird
signal clicked(figure_ref)

# --- DATEN UND ZUSTAND ---
# Hier speichern wir die Ressource (.tres Datei), die vom GridManager übergeben wird
var stats: UnitStats
# Aktuelle Lebenspunkte der Figur im Spiel (sinkt bei Schaden)
var current_hp: int = 0

var grid_position: Vector2i
var grid_manager = null
var current_tile = null
var is_currently_selected = false

var selected := false
var team := 0
var has_moved_this_round: bool = false
var has_attacked_this_round: bool = false

# --- REFERENZEN ---
@onready var visual: Node3D = $FigureBody

# --- INITIALISIERUNG ---
func _ready():
	# Input-Event verbinden, damit Klicks registriert werden
	var body = $FigureBody 
	if body:
		body.input_event.connect(_on_figure_input_event)
		
	# Richtet das Team-Aussehen (Drehung) beim Start ein
	update_team_visual()
	
	# Stats initialisieren (HP setzen und Skin laden)
	if stats:
		# Figur bekommt beim Spawnen ihre vollen Lebenspunkte aus der Ressource
		current_hp = stats.hp
		
		# Skin anwenden (Dein Minecraft-Style Skript)
		var model = get_node_or_null("FigureBody/model")
		if model and model.has_method("apply_skin") and stats.unit_texture:
			model.apply_skin(stats.unit_texture)

# --- SETTER-METHODEN ---
func set_team(value: int):
	team = value
	if is_node_ready():
		update_team_visual()

# --- VISUELLE METHODEN ---
# Dreht die Figuren des Spielers (Team 1) um 180 Grad, damit sie nach oben schauen
func update_team_visual():
	if team == 1:
		visual.rotation_degrees.y = 180
	else:
		visual.rotation_degrees.y = 0

# Aktiviert oder deaktiviert den visuellen Auswahlring und den Tween-Effekt
func set_selected(is_selected: bool):
	# Verhindert, dass die Animation bei jedem Klick neu startet
	if is_currently_selected == is_selected:
		return
	
	is_currently_selected = is_selected
	
	var tween = create_tween()
	if is_selected:
		# Figur wird auf 120% vergrößert (1.2, 1.2, 1.2)
		tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.2).set_trans(Tween.TRANS_ELASTIC)
	else:
		# Figur kehrt zur Normalgröße zurück
		tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD)

func reset_visual():
	var t = create_tween()
	t.tween_property(self, "scale", Vector3(1, 1, 1), 0.1)

# --- BEWEGUNG ---
# Setzt die Figur EXAKT in die Mitte des Feldes
func move_to(tile):
	if tile == null or tile.occupied:
		return
		
	# Löst die Figur vom alten Feld
	if current_tile:
		current_tile.occupied = false
		current_tile.occupying_unit = null

	# Verknüpft die Figur mit dem neuen Feld
	current_tile = tile
	grid_position = tile.grid_position

	tile.occupied = true
	tile.occupying_unit = self
	
	# Das Modell steht nun mathematisch perfekt im Zentrum des Quadrats
	global_position = tile.global_position

# --- KAMPFSYSTEM (HP & SCHADEN) ---
# Wird aufgerufen, wenn diese Figur eine andere angreift
func atk_target(target: Figure):
	if target == null or stats == null:
		return
		
	# Ruft die Schadensberechnung auf dem Ziel auf
	if target.has_method("take_damage"):
		target.take_damage(stats.atk)
		print(stats.unit_name + " greift " + target.stats.unit_name + " an und macht " + str(stats.atk) + " Schaden!")

# Diese Funktion wird aufgerufen, wenn DIESE Figur angegriffen wird
func take_damage(amount: int):
	current_hp -= amount
	print(stats.unit_name + " verliert " + str(amount) + " HP! Verbleibend: " + str(current_hp))
	
	# Prüfen, ob die Figur gestorben ist
	if current_hp <= 0:
		current_hp = 0
		die()

# Entfernt die Figur aus dem Spiel, wenn die HP auf 0 fallen
func die():
	print(stats.unit_name + " ist gestorben!")
	if current_tile:
		current_tile.occupied = false
		current_tile.occupying_unit = null
	
	# Figur vom Spielfeld entfernen
	queue_free()

# --- INPUT-EVENT ---
func _on_figure_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Hier sagen wir dem Manager: "Ich wurde angeklickt!"
		if grid_manager:
			grid_manager.select_figure(self)
