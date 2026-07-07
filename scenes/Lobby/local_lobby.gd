# local_lobby.gd — Splitscreen-Lobby fuer das lokale Spiel (ein Fenster, zwei Haelften).
# Beide Seiten teilen sich denselben Charakter-Pool (derselbe lokale Account), duerfen
# ihre Aufstellung aber unabhaengig positionieren. Charaktere koennen hier nicht gekauft
# oder gelevelt werden — nur ihre Position wird festgelegt. Start erst wenn beide "Bereit" sind.
extends Control

const FormationSlotScene := preload("res://scenes/Formation/formation_slot.tscn")
const RosterCardScene := preload("res://scenes/Formation/roster_card.tscn")

class Side:
	var grid: GridContainer
	var validation_label: Label
	var roster_box: HBoxContainer
	var bereit_button: Button
	var slots: Array = []
	var formation: Array = []
	var ready_state: bool = false

var _left := Side.new()
var _right := Side.new()

@onready var _status_label: Label = $VBox/StatusLabel


func _ready() -> void:
	_setup_side(_left, $VBox/HBoxSplit/LeftSide)
	_setup_side(_right, $VBox/HBoxSplit/RightSide)
	_update_status()


func _setup_side(side, root: Control) -> void:
	side.grid = root.get_node("GridArea/GridContainer")
	side.validation_label = root.get_node("ValidationLabel")
	side.roster_box = root.get_node("RosterScroll/RosterTray")
	side.bereit_button = root.get_node("BereitButton")
	side.formation = PlayerData.formation.duplicate()

	for row in PlayerData.FORMATION_ROWS:
		for col in PlayerData.FORMATION_COLS:
			var slot: FormationSlot = FormationSlotScene.instantiate()
			side.grid.add_child(slot)
			slot.setup(col, row)
			slot.set_occupant(side.formation[row * PlayerData.FORMATION_COLS + col])
			slot.changed.connect(_on_side_changed.bind(side))
			side.slots.append(slot)

	for unit_name in PlayerData.get_all_unit_stats().keys():
		var card: RosterCard = RosterCardScene.instantiate()
		card.show_level_up_button = false
		side.roster_box.add_child(card)
		card.setup(unit_name)

	side.bereit_button.toggled.connect(_on_bereit_toggled.bind(side))
	_revalidate_side(side)


func _on_side_changed(side) -> void:
	# Eine Aenderung an der Aufstellung macht "Bereit" rueckgaengig.
	if side.bereit_button.button_pressed:
		side.bereit_button.button_pressed = false
	_revalidate_side(side)


func _read_side_formation(side) -> Array:
	var arr := []
	arr.resize(PlayerData.FORMATION_SIZE)
	for slot in side.slots:
		arr[slot.row * PlayerData.FORMATION_COLS + slot.col] = slot.occupant
	return arr


func _revalidate_side(side) -> void:
	var candidate := _read_side_formation(side)
	var result: Dictionary = PlayerData.validate_formation(candidate)
	side.validation_label.visible = not result["valid"]
	side.validation_label.text = result["error"]
	side.bereit_button.disabled = not result["valid"]


func _on_bereit_toggled(pressed: bool, side) -> void:
	side.ready_state = pressed
	if pressed:
		side.formation = _read_side_formation(side)
	for slot in side.slots:
		slot.interactive = not pressed
	_update_status()
	_maybe_start_match()


func _update_status() -> void:
	if _left.ready_state and _right.ready_state:
		_status_label.text = "Beide Seiten bereit — die Partie beginnt..."
	elif _left.ready_state:
		_status_label.text = "Host ist bereit — warte auf Client."
	elif _right.ready_state:
		_status_label.text = "Client ist bereit — warte auf Host."
	else:
		_status_label.text = "Beide Spieler waehlen ihre Aufstellung und druecken Bereit."


func _maybe_start_match() -> void:
	if not (_left.ready_state and _right.ready_state):
		return
	PlayerData.battle_formation_left = _left.formation
	PlayerData.battle_formation_right = _right.formation
	PlayerData.last_match_mode = "local"
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
