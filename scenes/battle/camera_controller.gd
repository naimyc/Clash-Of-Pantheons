extends Camera3D

# ---------------------------------------------------------------------------
# BASE POSITIONS  (Y=5, Z=4.5 fills a 7×7 board at TILE_SIZE=1)
# ---------------------------------------------------------------------------
const BASE_OFFSET_MY_TURN    = Vector3(0, 5.0, 4.5)
const BASE_OFFSET_THEIR_TURN = Vector3(0, 5.8, 5.2)
const LOOK_BIAS              = Vector3(0, 0, -0.4)   # board centre target

# Attack drama
const ATTACK_PUSH_OFFSET = Vector3(0, 3.8, 3.2)

# Figure-selected framing
const SELECT_ENTER_T  = 0.45   # transition time into framed view
const MIN_HEIGHT      = 3.2    # never go closer than this
const MAX_HEIGHT      = 7.5    # never go further than this
# Camera FOV is read at runtime; fallback used if unavailable
const FOV_FALLBACK    = 75.0
# Extra padding factor around the bounding box (1.25 = 25% margin)
const FRAME_PADDING   = 1.30
# How far behind the bounding-box centre to sit (keeps figure in lower frame)
const BEHIND_BIAS     = 0.6

# Tween durations
const TWEEN_NORMAL  = 0.55
const TWEEN_ATTACK  = 0.18
const TWEEN_RECOVER = 0.9

var _my_team:       int   = 1
var _is_my_turn:    bool  = false
var _current_tween: Tween = null

# ---------------------------------------------------------------------------
# INIT
# ---------------------------------------------------------------------------
func _ready():
	await get_tree().process_frame
	_init_camera()

func _init_camera():
	var tm = get_node_or_null("%TurnManager")
	if tm:
		_my_team    = tm.get_my_team()
		_is_my_turn = tm.is_my_turn()
		tm.turn_changed.connect(_on_turn_changed)

	var sign_z = 1.0 if _my_team == 1 else -1.0
	_snap_to(BASE_OFFSET_MY_TURN * Vector3(1, 1, sign_z))

# ---------------------------------------------------------------------------
# TURN CHANGES
# ---------------------------------------------------------------------------
func _on_turn_changed(_active_player):
	var tm = get_node_or_null("%TurnManager")
	if tm == null: return
	_is_my_turn = tm.is_my_turn()
	var sign_z  = 1.0 if _my_team == 1 else -1.0
	var offset  = BASE_OFFSET_MY_TURN if _is_my_turn else BASE_OFFSET_THEIR_TURN
	_tween_to(offset * Vector3(1, 1, sign_z), TWEEN_NORMAL)

# ---------------------------------------------------------------------------
# FIGURE SELECTED — centre on figure Z, pull back enough to see full board.
# X never moves. Y-axis rotation stays fixed (always frontal).
# ---------------------------------------------------------------------------
func on_figure_selected(figure_pos: Vector3, _move_positions: Array):
	var sign_z = 1.0 if _my_team == 1 else -1.0

	# Height that fits the full 7×7 board in view (half-board = 3.5 tiles).
	# Using base height + a small pull-back so the whole field is always visible.
	var board_half = 3.5   # half of GRID_SIZE
	var fov_rad    = deg_to_rad(fov if fov > 0.0 else FOV_FALLBACK)
	var full_board_h = board_half / tan(fov_rad * 0.5)
	var target_h     = clampf(full_board_h, MIN_HEIGHT, MAX_HEIGHT)

	# Z: sit behind the figure's Z position (on our team's side).
	# Clamp so the camera never crosses the board centre (LOOK_BIAS.z) —
	# crossing it flips the look_at forward vector and inverts the view.
	var raw_z    = figure_pos.z + sign_z * BEHIND_BIAS
	# Team 1 must stay positive Z, team 0 must stay negative Z
	var safe_z   = raw_z if sign(raw_z) == sign_z else sign_z * 0.5
	var target_pos = Vector3(0.0, target_h, safe_z)

	_tween_to(target_pos, SELECT_ENTER_T)

func on_figure_deselected():
	var sign_z = 1.0 if _my_team == 1 else -1.0
	var offset = BASE_OFFSET_MY_TURN if _is_my_turn else BASE_OFFSET_THEIR_TURN
	_tween_to(offset * Vector3(1, 1, sign_z), TWEEN_NORMAL)

# ---------------------------------------------------------------------------
# ATTACK DRAMA
# ---------------------------------------------------------------------------
func on_attack_fired(attacker_pos: Vector3, _defender_pos: Vector3):
	if _current_tween: _current_tween.kill()
	var sign_z  = 1.0 if _my_team == 1 else -1.0
	var lateral = clampf(attacker_pos.x * 0.15, -0.6, 0.6)
	var push    = ATTACK_PUSH_OFFSET + Vector3(lateral, 0, 0)

	_current_tween = create_tween()
	_current_tween.tween_method(_move_and_look, global_position,
		push * Vector3(1, 1, sign_z), TWEEN_ATTACK)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var recover = (BASE_OFFSET_MY_TURN if _is_my_turn else BASE_OFFSET_THEIR_TURN)\
		* Vector3(1, 1, sign_z)
	_current_tween.tween_method(_move_and_look,
		push * Vector3(1, 1, sign_z), recover, TWEEN_RECOVER)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)\
		.set_delay(0.25)

# ---------------------------------------------------------------------------
# HELPERS — _move_and_look keeps Y-axis rotation fixed by always pointing
# at LOOK_BIAS (the fixed board-centre target). This is the only look_at
# call in the file, so rotation never drifts.
# ---------------------------------------------------------------------------
func _snap_to(pos: Vector3):
	global_position = pos
	look_at(LOOK_BIAS, Vector3.UP)

func _tween_to(target_pos: Vector3, duration: float):
	if _current_tween: _current_tween.kill()
	_current_tween = create_tween()
	_current_tween.tween_method(_move_and_look, global_position, target_pos, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _move_and_look(pos: Vector3):
	global_position = pos
	look_at(LOOK_BIAS, Vector3.UP)
