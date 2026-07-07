# formation_scene.gd — 7x3 Formation-Editor mit Drag&Drop.
# Aenderungen wirken erst auf PlayerData.formation, wenn "Zurueck" eine gueltige
# Formation bestaetigt (commit_formation) — ungueltige Zwischenstaende gehen nie verloren.
extends Control

const FormationSlotScene := preload("res://scenes/Formation/formation_slot.tscn")
const RosterCardScene := preload("res://scenes/Formation/roster_card.tscn")

@onready var _grid: GridContainer = $VBox/GridArea/GridContainer
@onready var _validation_label: Label = $VBox/ValidationLabel
@onready var _roster_box: HBoxContainer = $VBox/RosterScroll/RosterTray
@onready var _back_button: Button = $VBox/BackButton
@onready var _muenzen_label: Label = $VBox/RessourcenLeiste/MuenzenLabel
@onready var _energie_label: Label = $VBox/RessourcenLeiste/EnergieLabel

var _slots: Array = []  # 21 FormationSlot, row-major, gleiche Reihenfolge wie PlayerData


func _ready() -> void:
	_build_grid()
	_build_roster()
	_back_button.pressed.connect(_on_back_pressed)
	_revalidate()
	_ressourcen_aktualisieren()


func _ressourcen_aktualisieren() -> void:
	_muenzen_label.text = "Muenzen: " + str(PlayerData.coins)
	_energie_label.text = "Energie: " + str(PlayerData.energy_points)


func _build_grid() -> void:
	_slots.clear()
	for row in PlayerData.FORMATION_ROWS:
		for col in PlayerData.FORMATION_COLS:
			var slot: FormationSlot = FormationSlotScene.instantiate()
			_grid.add_child(slot)
			slot.setup(col, row)
			slot.set_occupant(PlayerData.get_formation_cell(col, row))
			slot.changed.connect(_revalidate)
			_slots.append(slot)


func _build_roster() -> void:
	for kind in _roster_box.get_children():
		kind.queue_free()
	for unit_name in PlayerData.get_all_unit_stats().keys():
		var card: RosterCard = RosterCardScene.instantiate()
		_roster_box.add_child(card)
		card.setup(unit_name)
		card.level_up_pressed.connect(_on_level_up_pressed)


func _on_level_up_pressed(unit_name: String) -> void:
	if not PlayerData.level_up(unit_name):
		return
	_ressourcen_aktualisieren()
	for card in _roster_box.get_children():
		if card is RosterCard and card.unit_name == unit_name:
			card.refresh()
	for slot in _slots:
		if slot.occupant == unit_name:
			slot.set_occupant(unit_name)  # erzwingt Refresh des Level-Badges


func _read_slots_into_array() -> Array:
	var arr := []
	arr.resize(PlayerData.FORMATION_SIZE)
	for slot in _slots:
		arr[slot.row * PlayerData.FORMATION_COLS + slot.col] = slot.occupant
	return arr


func _revalidate() -> void:
	var candidate := _read_slots_into_array()
	var result: Dictionary = PlayerData.validate_formation(candidate)
	_validation_label.visible = not result["valid"]
	_validation_label.text = result["error"]


func _on_back_pressed() -> void:
	var candidate := _read_slots_into_array()
	if PlayerData.commit_formation(candidate):
		get_tree().change_scene_to_file("res://scenes/Menu/menu.tscn")
	else:
		var result: Dictionary = PlayerData.validate_formation(candidate)
		_validation_label.visible = true
		_validation_label.text = result["error"]
