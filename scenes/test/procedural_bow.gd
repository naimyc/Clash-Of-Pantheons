# procedural_bow.gd — Minecraft-style Recurve-Bow mit ziehbarer Sehne
extends Node3D
class_name ProceduralBow

# --- Farben ---
@export var wood_dark:    Color = Color(0.28, 0.16, 0.06)
@export var wood_light:   Color = Color(0.45, 0.28, 0.10)
@export var grip_color:   Color = Color(0.15, 0.08, 0.03)
@export var wrap_color:   Color = Color(0.80, 0.60, 0.15)
@export var string_color: Color = Color(0.92, 0.88, 0.72)
@export var arrow_wood:   Color = Color(0.50, 0.30, 0.12)
@export var arrow_tip:    Color = Color(0.78, 0.78, 0.82)
@export var arrow_fletch: Color = Color(0.85, 0.15, 0.15)

# --- Sehnen-Endpunkte ---
const UPPER_TIP_LOCAL: Vector3 = Vector3(-0.16, 0.55, 0)
const LOWER_TIP_LOCAL: Vector3 = Vector3(-0.16, -0.55, 0)

# --- Nock-Punkt ---
const NOCK_REST:  Vector3 = Vector3(-0.16, 0.0, 0.0)
const NOCK_DRAWN: Vector3 = Vector3(-0.42, 0.0, 0.0)

const STRING_BASE_LEN: float = 1.0

var _nock: Node3D
var _arrow: Node3D
var _upper_string: MeshInstance3D
var _lower_string: MeshInstance3D

# ---------------------------------------------------------------------------
func _ready() -> void:
	_build()
	set_draw(0.0)

	
# ---------------------------------------------------------------------------
# BAU
# ---------------------------------------------------------------------------
func _build() -> void:
	# Griff
	var grip = _make_box(Vector3(0.06, 0.26, 0.06), grip_color)
	grip.position = Vector3.ZERO
	add_child(grip)

	# Wicklungen
	for y in [-0.10, 0.0, 0.10]:
		var wrap = _make_box(Vector3(0.068, 0.022, 0.068), wrap_color)
		wrap.position = Vector3(0, y, 0)
		add_child(wrap)

	# Oberer Wurfarm (Recurve)
	_add_limb_segment(Vector3(-0.02, 0.19,  0), Vector3(0.045, 0.16, 0.055),  8.0, wood_dark)
	_add_limb_segment(Vector3(-0.06, 0.33,  0), Vector3(0.040, 0.14, 0.050), 18.0, wood_light)
	_add_limb_segment(Vector3(-0.11, 0.46,  0), Vector3(0.035, 0.12, 0.045), 30.0, wood_dark)
	_add_limb_segment(Vector3(-0.15, 0.55,  0), Vector3(0.028, 0.08, 0.038), 52.0, wood_light)

	# Unterer Wurfarm
	_add_limb_segment(Vector3(-0.02, -0.19, 0), Vector3(0.045, 0.16, 0.055),  -8.0, wood_dark)
	_add_limb_segment(Vector3(-0.06, -0.33, 0), Vector3(0.040, 0.14, 0.050), -18.0, wood_light)
	_add_limb_segment(Vector3(-0.11, -0.46, 0), Vector3(0.035, 0.12, 0.045), -30.0, wood_dark)
	_add_limb_segment(Vector3(-0.15, -0.55, 0), Vector3(0.028, 0.08, 0.038), -52.0, wood_light)

	# Sehnen-Segmente
	_upper_string = _make_box(Vector3(0.012, STRING_BASE_LEN, 0.012), string_color)
	add_child(_upper_string)
	_lower_string = _make_box(Vector3(0.012, STRING_BASE_LEN, 0.012), string_color)
	add_child(_lower_string)

	# Nock + Pfeil
	_nock = Node3D.new()
	_nock.name = "Nock"
	add_child(_nock)

	_arrow = Node3D.new()
	_arrow.name = "NockedArrow"
	_nock.add_child(_arrow)

	var shaft = _make_box(Vector3(0.55, 0.020, 0.020), arrow_wood)
	shaft.position = Vector3(0.25, 0, 0)
	_arrow.add_child(shaft)

	var tip = _make_box(Vector3(0.09, 0.030, 0.030), arrow_tip)
	tip.position = Vector3(0.56, 0, 0)
	_arrow.add_child(tip)

	for angle in [0.0, 90.0]:
		var fletch = _make_box(Vector3(0.06, 0.04, 0.005), arrow_fletch)
		fletch.position = Vector3(-0.02, 0, 0)
		fletch.rotation_degrees.x = angle
		_arrow.add_child(fletch)

	_arrow.visible = false

func _add_limb_segment(pos: Vector3, size: Vector3, z_rot: float, color: Color) -> void:
	var seg = _make_box(size, color)
	seg.position = pos
	seg.rotation_degrees.z = z_rot
	add_child(seg)

# ---------------------------------------------------------------------------
# SEHNE ZIEHEN — 0.0 = Ruhe, 1.0 = voll gezogen
# ---------------------------------------------------------------------------
func set_draw(amount: float) -> void:
	amount = clamp(amount, -0.3, 1.0)
	var nock_pos = NOCK_REST.lerp(NOCK_DRAWN, amount)
	_nock.position = nock_pos
	_arrow.visible = amount > 0.05
	_orient_string(_upper_string, UPPER_TIP_LOCAL, nock_pos)
	_orient_string(_lower_string, LOWER_TIP_LOCAL, nock_pos)

func _orient_string(seg: MeshInstance3D, from_pt: Vector3, to_pt: Vector3) -> void:
	var mid = (from_pt + to_pt) * 0.5
	var dx = to_pt.x - from_pt.x
	var dy = to_pt.y - from_pt.y
	var length = sqrt(dx * dx + dy * dy)
	if length < 0.001:
		return
	seg.position = mid
	seg.rotation = Vector3(0, 0, atan2(-dx, dy))
	seg.scale = Vector3(1.0, length / STRING_BASE_LEN, 1.0)

# ---------------------------------------------------------------------------
# ZIEH-SEQUENZ — synchron zur Animation
# draw_end_percent:  Frame X wo voll gezogen (0.0-1.0)
# release_percent:   Frame Y wo Pfeil abgefeuert (0.0-1.0)
# ---------------------------------------------------------------------------
func play_draw_and_release(anim_length: float, draw_end_percent: float, release_percent: float) -> void:
	var draw_time = anim_length * draw_end_percent
	var hold_time = anim_length * (release_percent - draw_end_percent)

	var tw = create_tween()

	# 1) Ziehen — beschleunigend (Character zieht mit Kraft)
	tw.tween_method(set_draw, 0.0, 1.0, draw_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 2) Halten mit leichtem Zittern (Zielen unter Spannung)
	if hold_time > 0.03:
		# Kurze Vibration während des Haltens für Spannungs-Effekt
		var vibrate_steps = int(hold_time / 0.04)
		for i in vibrate_steps:
			tw.tween_method(set_draw, 1.0, 0.97, 0.02)\
				.set_trans(Tween.TRANS_SINE)
			tw.tween_method(set_draw, 0.97, 1.0, 0.02)\
				.set_trans(Tween.TRANS_SINE)

	# 3) Release — Sehne schnappt zurück mit Overshoot und Nachschwingen
	tw.tween_method(set_draw, 1.0, -0.25, 0.06)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(set_draw, -0.25, 0.10, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(set_draw, 0.10, 0.0, 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------------
func _make_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color   = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi
