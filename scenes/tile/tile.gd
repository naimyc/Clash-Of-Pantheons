extends Node3D
class_name Tile

# --- SIGNALE ---
# Signale für die Kommunikation mit dem InputManager
signal hovered(tile_ref)
signal unhovered(tile_ref)
signal clicked(tile_ref)

# --- GRID-KOORDINATEN ---
# Die logische Position auf dem Spielfeld (wird vom GridManager gesetzt)
var grid_position: Vector2i

# --- BELEGUNGS-STATUS ---
# Speicher für die Logik, ob sich eine Figur auf diesem Feld befindet
var occupied := false
var occupying_unit = null

# --- INITIALISIERUNG ---
func _ready():
	# Wenn du die Signale bereits im Editor (Node-Tab) verbunden hast,
	# dürfen sie hier im Code NICHT noch einmal mit .connect() aufgerufen werden!
	# Wir behalten nur die Referenzprüfung für den Debugger.
	var body = $StaticBody3D
	if body == null:
		print("WARNUNG: StaticBody3D wurde auf dem Feld nicht gefunden!")

# --- INTERNE EVENT-METHODEN ---
# Wird aufgerufen, wenn der Mauszeiger das Feld betritt
func _on_mouse_entered():
	hovered.emit(self)

# Wird aufgerufen, wenn der Mauszeiger das Feld verlässt
func _on_mouse_exited():
	unhovered.emit(self)

# Verarbeitet Klicks auf das Feld und filtert nach der linken Maustaste
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)

# --- VISUELLE METHODEN ---
# Schaltet das Highlight-Netz (Aufsatz-Quadrat) ein oder aus (für Hover-Effekte)
func set_highlight(value: bool):
	if has_node("HighlightMesh"):
		$HighlightMesh.visible = value

# Setzt den visuellen Auswahlstatus des Feldes
func set_selected(value: bool):
	if has_node("HighlightMesh"):
		$HighlightMesh.visible = value
# In tile.gd
func set_color_mode(mode: String):
	var mesh = $MeshInstance3D
	var material = StandardMaterial3D.new()
	
	match mode:
		"normal": material.albedo_color = Color(0.2, 0.2, 0.2) if (grid_position.x + grid_position.y) % 2 != 0 else Color(0.8, 0.8, 0.8)
		"move_target": material.albedo_color = Color(0.0, 0.5, 1.0) # blau für bewegung
		"attack_target": material.albedo_color= Color(1.0,1.0,0) # für angrefien 
	mesh.material_override = material
