# formation_slot.gd — eine Zelle im 7x3 Formation-Raster.
# Wird auch (mit interactive=false) als reine Vorschau in der lokalen Lobby verwendet.
extends PanelContainer
class_name FormationSlot

signal changed

@export var interactive: bool = true

var col: int = 0
var row: int = 0
var occupant: String = ""

@onready var _texture: TextureRect = $Content/Texture
@onready var _label: Label = $Content/LevelLabel


func setup(p_col: int, p_row: int) -> void:
	col = p_col
	row = p_row


func set_occupant(unit_name: String) -> void:
	occupant = unit_name
	_refresh()


func _refresh() -> void:
	if occupant == "":
		_texture.texture = null
		_label.text = ""
		return
	var stats: UnitStats = PlayerData.get_unit_stats(occupant)
	if stats:
		_texture.texture = stats.portrait_texture if stats.portrait_texture else stats.unit_texture
		_label.text = "Lv.%d" % PlayerData.get_level(occupant)


func _get_drag_data(_pos: Vector2):
	if not interactive or occupant == "":
		return null
	var preview := TextureRect.new()
	if _texture.texture:
		preview.texture = _texture.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"unit_name": occupant, "from_slot": self}


func _can_drop_data(_pos: Vector2, data) -> bool:
	return interactive and typeof(data) == TYPE_DICTIONARY and data.has("unit_name")


func _drop_data(_pos: Vector2, data) -> void:
	var incoming: String = data["unit_name"]
	var from_slot = data.get("from_slot", null)
	if from_slot == self:
		return
	# Nur den Zielinhalt zuruecktauschen wenn die Quelle ein anderer Slot war (nicht die Rosterleiste).
	if occupant != "" and from_slot != null:
		from_slot.set_occupant(occupant)
	elif from_slot != null:
		from_slot.set_occupant("")
	set_occupant(incoming)
	changed.emit()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if occupant != "":
			set_occupant("")
			changed.emit()
