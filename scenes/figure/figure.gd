# figure.gd — data and coordination only.
# Visuals delegated to child "Visuals" (figure_visuals.gd) + Model (CharacterModel).
extends Node3D
class_name Figure

var stats: UnitStats
var current_hp: int = 0
var grid_position: Vector2i
var grid_manager = null
var current_tile = null
var team: int = 0

var is_currently_selected: bool = false
var has_moved_this_round: bool = false
var has_attacked_this_round: bool = false
var has_used_skill_this_round: bool = false
var _is_attack_target: bool = false

# --- STATUS EFFECTS ---
var is_petrified: bool = false

@onready var visual: Node3D = $FigureBody
@onready var _vis: Node = $Visuals   # figure_visuals.gd


func _ready():
	var body = $FigureBody
	if body:
		body.input_event.connect(_on_input)
		body.mouse_entered.connect(func():
			if _is_attack_target:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
		body.mouse_exited.connect(func():
			Input.set_default_cursor_shape(Input.CURSOR_ARROW))

	if team == 1:
		visual.rotation_degrees.y = 180

	if stats:
		current_hp = stats.hp
		var model = find_model(self)
		if model and model.has_method("apply_skin") and stats.unit_texture:
			model.apply_skin(stats.unit_texture)
		if model and model.has_method("set_ranged"):
			model.set_ranged(stats.attack_range > 1)

# ---------------------------------------------------------------------------
# MODEL SEARCH — bevorzugt animiertes CharacterModel (mit play_attack)
# ---------------------------------------------------------------------------
func find_model(node: Node) -> Node:
	if node == null:
		return null
	var animated = _find_animated_model(node)
	if animated:
		return animated
	return _find_any_skin_model(node)

func _find_animated_model(node: Node) -> Node:
	if node.has_method("play_attack") and node.has_signal("attack_hit_frame"):
		return node
	for child in node.get_children():
		var r = _find_animated_model(child)
		if r: return r
	return null

func _find_any_skin_model(node: Node) -> Node:
	if node != self and node.has_method("apply_skin"):
		return node
	for child in node.get_children():
		var r = _find_any_skin_model(child)
		if r: return r
	return null

# ---------------------------------------------------------------------------
# STATUS: PETRIFICATION
# ---------------------------------------------------------------------------
func can_act() -> bool:
	return not is_petrified

func set_petrified(value: bool):
	if is_petrified == value: return
	is_petrified = value

	# Petrify-Animation (Stein-Welle, Farbe, Anim-Freeze) — allein im Modell,
	# es gab frueher zusaetzlich einen figure_visuals-Overlay der dasselbe Material-
	# Objekt referenzierte und damit race-bedingt eine falsche (graue) Endfarbe erzeugte.
	var model = find_model(self)
	if model and model.has_method("set_petrified"):
		model.set_petrified(value)

# ---------------------------------------------------------------------------
# ATTACK ANIMATION — gibt Signal zurück, feuert am Hit-Frame
# is_ranged wird vom Aufrufer anhand der TATSAECHLICHEN Distanz zum Ziel bestimmt,
# nicht anhand der maximalen Reichweite der Einheit — ein Bogenschuetze auf ein
# direkt benachbartes Feld schlaegt zu, statt aus der Naehe zu schiessen.
# ---------------------------------------------------------------------------
func play_attack_animation(target_world_pos: Vector3, is_ranged: bool) -> Signal:
	var model = find_model(self)
	if model == null or not model.has_signal("attack_hit_frame"):
		return get_tree().create_timer(0.01).timeout
	model.play_attack(is_ranged, target_world_pos)
	return model.attack_hit_frame

# ---------------------------------------------------------------------------
# SKILL ANIMATION — gibt Signal zurück, feuert am Skill-Hit-Frame
# ---------------------------------------------------------------------------
func play_skill_animation(target_world_pos: Vector3) -> Signal:
	var model = find_model(self)
	if model == null or not model.has_signal("skill_hit_frame"):
		return get_tree().create_timer(0.01).timeout
	model.play_skill(target_world_pos)
	return model.skill_hit_frame

# ---------------------------------------------------------------------------
# SELECTION / TARGETING
# ---------------------------------------------------------------------------
func set_selected(value: bool):
	if is_currently_selected == value: return
	is_currently_selected = value
	_vis.play_selected(value)

func set_attack_target(value: bool):
	if _is_attack_target == value: return
	_is_attack_target = value
	_vis.play_attack_pulse(value)

# ---------------------------------------------------------------------------
# MOVEMENT
# ---------------------------------------------------------------------------
func move_to(tile, force: bool = false):
	if tile == null: return
	if not force and tile.occupied: return
	if current_tile and is_instance_valid(current_tile):
		current_tile.occupied = false
		current_tile.occupying_unit = null
	if force and tile.occupied and is_instance_valid(tile.occupying_unit):
		if tile.occupying_unit != self:
			tile.occupying_unit.current_tile = null
	current_tile = tile
	grid_position = tile.grid_position
	tile.occupied = true
	tile.occupying_unit = self
	create_tween().tween_property(self, "global_position",
		tile.global_position + Vector3(0, 0.15 if is_currently_selected else 0, 0),
		0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# DAMAGE / DEATH
# ---------------------------------------------------------------------------
func take_damage(amount: int):
	current_hp -= amount
	_vis.play_damage_flash(_is_attack_target)
	if current_hp <= 0:
		current_hp = 0
		die()

func die():
	if current_tile:
		current_tile.occupied = false
		current_tile.occupying_unit = null
	var model = find_model(self)
	if model and model.has_method("play_death") and model.has_signal("death_finished"):
		model.death_finished.connect(queue_free, CONNECT_ONE_SHOT)
		model.play_death()
	else:
		var sig = _vis.play_death()
		sig.connect(queue_free)

	if grid_manager and grid_manager.has_method("check_win_condition"):
		grid_manager.call_deferred("check_win_condition")

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _on_input(_cam, event, _pos, _norm, _idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if grid_manager:
			grid_manager.select_figure(self)
