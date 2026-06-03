extends Node3D
class_name Tile

# --- SIGNALE ---
signal hovered(tile_ref)
signal unhovered(tile_ref)
signal clicked(tile_ref)

# --- GRID-KOORDINATEN ---
var grid_position: Vector2i

# --- BELEGUNGS-STATUS ---
var occupied := false
var occupying_unit = null

# --- INITIALISIERUNG ---
func _ready():
	var body = $StaticBody3D
	if body == null:
		print("WARNUNG: StaticBody3D wurde auf dem Feld nicht gefunden!")

# --- INTERNE EVENT-METHODEN ---
func _on_mouse_entered():
	hovered.emit(self)

func _on_mouse_exited():
	unhovered.emit(self)

func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)

# --- VISUELLE METHODEN ---
func set_highlight(value: bool):
	if has_node("HighlightMesh"):
		$HighlightMesh.visible = value

func set_selected(value: bool):
	if has_node("HighlightMesh"):
		$HighlightMesh.visible = value

# set_color_mode kept for API compatibility — tile coloring is now handled
# by spawned dot/ring meshes in GridManager._spawn_move_dot / _spawn_attack_ring.
# Tiles themselves stay visually neutral.
func set_color_mode(_mode: String) -> void:
	pass
