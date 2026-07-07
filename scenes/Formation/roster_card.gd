# roster_card.gd — eine Karte in der Roster-Leiste der Formation-Szene.
# Ist als Drag-Quelle nutzbar (eine Einheit kann mehrfach auf Laos-Slots gezogen werden,
# das Roster wird beim Ziehen NICHT "verbraucht").
extends PanelContainer
class_name RosterCard

signal level_up_pressed(unit_name: String)

# In der Lobby (Formation nur positionieren, kein Leveln) wird der Button ausgeblendet.
@export var show_level_up_button: bool = true

var unit_name: String = ""

@onready var _texture: TextureRect = $VBox/Texture
@onready var _name_label: Label = $VBox/NameLabel
@onready var _level_label: Label = $VBox/LevelLabel
@onready var _cards_label: Label = $VBox/CardsLabel
@onready var _energy_label: Label = $VBox/EnergyLabel
@onready var _level_up_button: Button = $VBox/LevelUpButton


func setup(p_unit_name: String) -> void:
	unit_name = p_unit_name
	_level_up_button.pressed.connect(func(): level_up_pressed.emit(unit_name))
	refresh()


func refresh() -> void:
	var stats: UnitStats = PlayerData.get_unit_stats(unit_name)
	if stats:
		_texture.texture = stats.portrait_texture if stats.portrait_texture else stats.unit_texture
		_name_label.text = stats.unit_name

	var level: int = PlayerData.get_level(unit_name)
	_level_label.text = "Level %d/%d" % [level, PlayerData.MAX_LEVEL]

	var needed_cards: int = PlayerData.cards_needed_for_next_level(unit_name)
	if needed_cards > 0:
		_cards_label.text = "Karten: %d/%d" % [PlayerData.get_cards(unit_name), needed_cards]
		var needed_energy: int = PlayerData.energy_needed_for_next_level(unit_name)
		_energy_label.text = "Energie: %d/%d" % [PlayerData.energy_points, needed_energy]
		_energy_label.visible = true
	else:
		_cards_label.text = "MAX LEVEL"
		_energy_label.visible = false

	_level_up_button.visible = show_level_up_button and level < PlayerData.MAX_LEVEL
	_level_up_button.disabled = not PlayerData.can_level_up(unit_name)


func _get_drag_data(_pos: Vector2):
	if unit_name == "":
		return null
	var preview := TextureRect.new()
	if _texture.texture:
		preview.texture = _texture.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	# from_slot = null -> Ziel-Slot weiss, dass die Quelle das Roster ist (kein Slot wird geleert)
	return {"unit_name": unit_name, "from_slot": null}
