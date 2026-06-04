# figure.gd — data and coordination only.
# Visuals delegated to child "Visuals" (figure_visuals.gd).
extends Node3D
class_name Figure

var stats: UnitStats
var current_hp: int = 0
var grid_position: Vector2i
var grid_manager   = null
var current_tile   = null
var team: int      = 0

var is_currently_selected:    bool = false
var has_moved_this_round:     bool = false
var has_attacked_this_round:  bool = false
var _is_attack_target:        bool = false

@onready var visual: Node3D      = $FigureBody
@onready var _vis:   Node        = $Visuals   # figure_visuals.gd

func _ready():
	var body = $FigureBody
	if body:
		body.input_event.connect(_on_input)
		body.mouse_entered.connect(func(): if _is_attack_target: Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
		body.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
	if team == 1: visual.rotation_degrees.y = 180
	if stats:
		current_hp = stats.hp
		var model = get_node_or_null("FigureBody/model")
		if model and model.has_method("apply_skin") and stats.unit_texture:
			model.apply_skin(stats.unit_texture)

func set_selected(value: bool):
	if is_currently_selected == value: return
	is_currently_selected = value
	_vis.play_selected(value)

func set_attack_target(value: bool):
	if _is_attack_target == value: return
	_is_attack_target = value
	_vis.play_attack_pulse(value)

func move_to(tile, force: bool = false):
	if tile == null: return
	if not force and tile.occupied: return
	if current_tile and is_instance_valid(current_tile):
		current_tile.occupied       = false
		current_tile.occupying_unit = null
	if force and tile.occupied and is_instance_valid(tile.occupying_unit):
		if tile.occupying_unit != self:
			tile.occupying_unit.current_tile = null
	current_tile      = tile
	grid_position     = tile.grid_position
	tile.occupied     = true
	tile.occupying_unit = self
	create_tween().tween_property(self, "global_position",
		tile.global_position + Vector3(0, 0.15 if is_currently_selected else 0, 0),
		0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func take_damage(amount: int):
	current_hp -= amount
	_vis.play_damage_flash(_is_attack_target)
	if current_hp <= 0:
		current_hp = 0
		die()

func die():
	if current_tile:
		current_tile.occupied       = false
		current_tile.occupying_unit = null
	var sig = _vis.play_death()
	sig.connect(queue_free)

func _on_input(_cam, event, _pos, _norm, _idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if grid_manager: grid_manager.select_figure(self)
