extends CanvasLayer

@onready var left_stats_panel    = $LeftStatsPanel
@onready var unit_name_label     = $LeftStatsPanel/VBoxContainer/UnitName
@onready var hp_label            = $LeftStatsPanel/VBoxContainer/HPLabel
@onready var atk_label           = $LeftStatsPanel/VBoxContainer/ATKLabel
@onready var def_label           = $LeftStatsPanel/VBoxContainer/DEFLabel
@onready var move_cost_label     = $LeftStatsPanel/VBoxContainer/MoveCostLabel
@onready var attack_cost_label   = $LeftStatsPanel/VBoxContainer/AttackCostLabel
@onready var skill_cost_label    = $LeftStatsPanel/VBoxContainer/SkillCostLabel

@onready var top_left_panel      = $TopLeft
@onready var top_left_game_time  = $TopLeft/EnemyGameTimeLabel
@onready var top_left_round_time = $TopLeft/EnemyRoundTimeLabel

@onready var top_right_panel     = $TopRight
@onready var top_right_game_time = $TopRight/GameTimeLabel
@onready var top_right_round_time= $TopRight/RoundTimeLabel

@onready var energy_bar  = $BottomCenter/ProgressBar
@onready var energy_text = $BottomCenter/ProgressBar/Label

# Name labels — created in code if not already in the scene
var top_left_name_label:  Label = null
var top_right_name_label: Label = null

# "Your Turn" banner — created in code
var _your_turn_banner: Control  = null
var _banner_tween:     Tween    = null
var _pulse_tween:      Tween    = null

# Split timer bar: one centred bar, left half = opponent, right half = me
# Implemented as two ProgressBars that share the same track, mirrored.
var _my_time_bar:      ProgressBar  = null
var _my_time_style:    StyleBoxFlat = null
var _opp_time_bar:     ProgressBar  = null
var _opp_time_style:   StyleBoxFlat = null
var _max_round_time:   float = 10.0   # synced from TurnManager.BASE_ROUND_TIME

func _ready():
	if left_stats_panel: left_stats_panel.visible = false
	if energy_bar:
		energy_bar.min_value = 0
		energy_bar.max_value = 10
		energy_bar.value     = 0

	_setup_name_labels()
	_setup_your_turn_banner()
	_setup_time_bars()

	var tm = get_node_or_null("%TurnManager")
	if tm:
		tm.turn_changed.connect(_on_turn_changed)
		tm.energy_updated.connect(_on_energy_updated)
		tm._emit_energy()
		_apply_player_names(tm)
		# Set initial banner state
		_update_turn_banner(tm.is_my_turn())
		_max_round_time = tm.BASE_ROUND_TIME

# ---------------------------------------------------------------------------
# NAME LABELS
# ---------------------------------------------------------------------------
func _setup_name_labels():
	# Try to find labels already placed in the scene editor first.
	# If missing, create them in code so nothing breaks either way.
	top_left_name_label  = top_left_panel.get_node_or_null("PlayerNameLabel")
	top_right_name_label = top_right_panel.get_node_or_null("PlayerNameLabel")

	if top_left_name_label == null:
		top_left_name_label = Label.new()
		top_left_name_label.name = "PlayerNameLabel"
		top_left_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_left_panel.add_child(top_left_name_label)
		top_left_panel.move_child(top_left_name_label, 0)   # put above timers

	if top_right_name_label == null:
		top_right_name_label = Label.new()
		top_right_name_label.name = "PlayerNameLabel"
		top_right_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top_right_panel.add_child(top_right_name_label)
		top_right_panel.move_child(top_right_name_label, 0)

func _apply_player_names(tm):
	# "My" panel is always top-right; opponent is top-left.
	var i_am_p1 = (tm.get_my_team() == 1)

	var my_name       = "Player 1 (Host)"   if i_am_p1 else "Player 2 (Client)"
	var opponent_name = "Player 2 (Client)" if i_am_p1 else "Player 1 (Host)"

	if top_right_name_label: top_right_name_label.text = my_name
	if top_left_name_label:  top_left_name_label.text  = opponent_name

# ---------------------------------------------------------------------------
# PROCESS — clock display
# ---------------------------------------------------------------------------
func _process(_delta):
	var tm = get_node_or_null("%TurnManager")
	if tm == null or tm.active_player == null: return

	var round_str = format_time(tm.current_round_time)
	var total_str = format_time(tm.active_player.total_game_time)
	var i_am_p1   = (tm.get_my_team() == 1)

	# Active player's clock goes on the side that matches their perspective.
	# My clock → right panel. Opponent's clock → left panel.
	if tm.active_player == tm.player_one:
		if i_am_p1:
			if top_right_round_time: top_right_round_time.text = round_str
			if top_right_game_time:  top_right_game_time.text  = total_str
		else:
			if top_left_round_time: top_left_round_time.text = round_str
			if top_left_game_time:  top_left_game_time.text  = total_str
	else:
		if i_am_p1:
			if top_left_round_time: top_left_round_time.text = round_str
			if top_left_game_time:  top_left_game_time.text  = total_str
		else:
			if top_right_round_time: top_right_round_time.text = round_str
			if top_right_game_time:  top_right_game_time.text  = total_str

	_update_split_bar(tm)

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func format_time(s: float) -> String:
	var t = max(0, int(s))
	return "%02d:%02d" % [t / 60, t % 60]

func display_figure_stats(figure: Figure):
	if figure == null or figure.stats == null:
		if left_stats_panel: left_stats_panel.visible = false
		return

	if left_stats_panel: left_stats_panel.visible = true
	var s = figure.stats
	var c = s.class_data

	if unit_name_label: unit_name_label.text = s.unit_name
	if atk_label:       atk_label.text       = "ATK: " + str(s.atk)
	if hp_label:        hp_label.text        = "HP: %d / %d" % [figure.current_hp, s.hp]
	if def_label:       def_label.visible    = false

	var move_range_label = left_stats_panel.get_node_or_null("VBoxContainer/MoveRangeLabel")
	if move_range_label: move_range_label.text = "Bewegungs-Reichweite: " + str(s.move_range)

	var attack_range_label = left_stats_panel.get_node_or_null("VBoxContainer/atkRangeLabel")
	if attack_range_label: attack_range_label.text = "Angriffs-Reichweite: " + str(s.attack_range)

	if c:
		var type_name_label = left_stats_panel.get_node_or_null("VBoxContainer/TypeNameLabel")
		if type_name_label: type_name_label.text = "Kategorie: " + str(c.typ_name)

		if move_cost_label:   move_cost_label.text   = "Kosten Bewegung: " + str(c.elixir_cost_move)
		if attack_cost_label: attack_cost_label.text = "Kosten Angriff: "  + str(c.elixir_cost_atk)
		if skill_cost_label:  skill_cost_label.text  = "Kosten Skill: "    + str(c.elixir_cost_skill)

		var has_skill        = c.elixir_cost_skill > 0
		var skill_container  = left_stats_panel.get_node_or_null("VBoxContainer/SkillContainer")
		var skill_name_label = left_stats_panel.get_node_or_null("VBoxContainer/SkillName")
		var skill_dmg_label  = left_stats_panel.get_node_or_null("VBoxContainer/SkillDMG")

		if skill_container:  skill_container.visible  = has_skill
		if skill_cost_label: skill_cost_label.visible = has_skill
		if has_skill:
			if skill_name_label: skill_name_label.text = "Skill: " + s.skill_name
			if skill_dmg_label:  skill_dmg_label.text  = "Skill-Schaden: " + str(s.skill_damage)

# ---------------------------------------------------------------------------
# SPLIT TIMER BAR  (top centre)
#   ←  opponent  |  me  →
# Left half fills leftward, right half fills rightward, both drain green→red.
# ---------------------------------------------------------------------------
func _make_half_bar(flip: bool) -> Array:
	var bar = ProgressBar.new()
	bar.min_value       = 0.0
	bar.max_value       = 1.0
	bar.value           = 1.0
	bar.show_percentage = false
	# fill_mode 3 = right-to-left (opponent side mirrors inward)
	if flip:
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN

	var bg = StyleBoxFlat.new()
	bg.bg_color                   = Color(0.07, 0.07, 0.07, 0.88)
	bg.corner_radius_top_left     = 6
	bg.corner_radius_top_right    = 6
	bg.corner_radius_bottom_left  = 6
	bg.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color                  = Color(0.2, 0.85, 0.2)
	fill.corner_radius_top_left     = 6
	fill.corner_radius_top_right    = 6
	fill.corner_radius_bottom_left  = 6
	fill.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("fill", fill)

	return [bar, fill]

func _setup_time_bars() -> void:
	# LEFT half — MY time (Player 1 / host = left side), fills left→right normally
	var my   = _make_half_bar(false)
	_my_time_bar   = my[0]
	_my_time_style = my[1]
	_my_time_bar.anchor_left   = 0.16
	_my_time_bar.anchor_right  = 0.5
	_my_time_bar.anchor_top    = 0.0
	_my_time_bar.anchor_bottom = 0.0
	_my_time_bar.offset_top    = 8
	_my_time_bar.offset_bottom = 24
	_my_time_bar.offset_left   = 0
	_my_time_bar.offset_right  = -2
	add_child(_my_time_bar)

	# RIGHT half — OPPONENT time, fills right→left (drains inward from right edge)
	var opp  = _make_half_bar(true)
	_opp_time_bar   = opp[0]
	_opp_time_style = opp[1]
	_opp_time_bar.anchor_left   = 0.5
	_opp_time_bar.anchor_right  = 0.84
	_opp_time_bar.anchor_top    = 0.0
	_opp_time_bar.anchor_bottom = 0.0
	_opp_time_bar.offset_top    = 8
	_opp_time_bar.offset_bottom = 24
	_opp_time_bar.offset_left   = 2
	_opp_time_bar.offset_right  = 0
	add_child(_opp_time_bar)

func _update_split_bar(tm) -> void:
	if tm == null: return
	var ratio     = clampf(tm.current_round_time / _max_round_time, 0.0, 1.0)
	var i_am_p1   = (tm.get_my_team() == 1)
	var p1_active = (tm.active_player == tm.player_one)
	# Drain the bar of whoever is currently spending their turn time.
	# My bar drains when it's my turn; opponent's bar drains when it's their turn.
	var my_active = (i_am_p1 == p1_active)
	_apply_half(_my_time_bar,  _my_time_style,  ratio if my_active  else 1.0)
	_apply_half(_opp_time_bar, _opp_time_style, ratio if not my_active else 1.0)

func _apply_half(bar: ProgressBar, style: StyleBoxFlat, ratio: float) -> void:
	if bar == null or style == null: return
	bar.value = ratio

	var col: Color
	if ratio > 0.5:
		col = Color(0.15, 0.85, 0.15).lerp(Color(0.95, 0.82, 0.05), (1.0 - ratio) * 2.0)
	else:
		col = Color(0.95, 0.82, 0.05).lerp(Color(0.95, 0.1, 0.05), (0.5 - ratio) * 2.0)
	style.bg_color = col

	if ratio < 0.30:
		style.shadow_color = col
		style.shadow_size  = int(lerp(0.0, 6.0, 1.0 - ratio / 0.3))
	else:
		style.shadow_size  = 0

# ---------------------------------------------------------------------------
# YOUR TURN BANNER
# ---------------------------------------------------------------------------
func _setup_your_turn_banner():
	# Outer panel — sits at bottom centre, above the energy bar
	var panel = PanelContainer.new()
	panel.name = "YourTurnBanner"
	# Anchor to bottom-centre
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.anchor_bottom = 1.0
	panel.anchor_top    = 1.0
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.offset_top    = -170
	panel.offset_bottom = -118
	panel.offset_left   = -160
	panel.offset_right  =  160

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color         = Color(0.05, 0.05, 0.05, 0.0)  # start transparent
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

	# Label inside
	var lbl = Label.new()
	lbl.name = "BannerLabel"
	lbl.text = "YOUR TURN"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
	panel.add_child(lbl)
	add_child(panel)
	_your_turn_banner = panel

func _update_turn_banner(is_my_turn: bool):
	if _your_turn_banner == null: return
	var style = _your_turn_banner.get_theme_stylebox("panel") as StyleBoxFlat
	var lbl   = _your_turn_banner.get_node_or_null("BannerLabel") as Label
	if style == null or lbl == null: return

	# Kill any running tweens
	if _banner_tween: _banner_tween.kill()
	if _pulse_tween:  _pulse_tween.kill()

	if is_my_turn:
		# ── Flash in ──────────────────────────────────────────────────────────
		_banner_tween = create_tween()
		_banner_tween.set_parallel(true)
		# Panel bg: flash bright gold then settle to a subtle glow
		_banner_tween.tween_method(
			func(c): style.bg_color = c,
			Color(0.05, 0.05, 0.05, 0.0),
			Color(1.0, 0.82, 0.1, 0.95), 0.18
		).set_trans(Tween.TRANS_QUAD)
		_banner_tween.chain().tween_method(
			func(c): style.bg_color = c,
			Color(1.0, 0.82, 0.1, 0.95),
			Color(0.18, 0.14, 0.02, 0.82), 0.5
		).set_trans(Tween.TRANS_CUBIC)
		# Label: fade in white
		_banner_tween.tween_method(
			func(c): lbl.add_theme_color_override("font_color", c),
			Color(1, 1, 1, 0), Color(1, 1, 1, 1.0), 0.2
		).set_trans(Tween.TRANS_QUAD)

		# ── Persistent pulse after the flash ─────────────────────────────────
		_banner_tween.finished.connect(func():
			_pulse_tween = create_tween()
			_pulse_tween.set_loops()
			_pulse_tween.tween_method(
				func(c): style.bg_color = c,
				Color(0.18, 0.14, 0.02, 0.82),
				Color(0.55, 0.42, 0.04, 0.92), 0.7
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_pulse_tween.tween_method(
				func(c): style.bg_color = c,
				Color(0.55, 0.42, 0.04, 0.92),
				Color(0.18, 0.14, 0.02, 0.82), 0.7
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		, CONNECT_ONE_SHOT)
	else:
		# ── Fade out ──────────────────────────────────────────────────────────
		_banner_tween = create_tween()
		_banner_tween.set_parallel(true)
		_banner_tween.tween_method(
			func(c): style.bg_color = c,
			style.bg_color, Color(0.05, 0.05, 0.05, 0.0), 0.4
		).set_trans(Tween.TRANS_QUAD)
		_banner_tween.tween_method(
			func(c): lbl.add_theme_color_override("font_color", c),
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.0), 0.3
		).set_trans(Tween.TRANS_QUAD)

# energy_updated carries (my_energy, opponent_energy)
func _on_energy_updated(my_energy: int, _opponent_energy: int):
	if energy_bar:  energy_bar.value = my_energy
	if energy_text: energy_text.text = "%d / 10" % my_energy

func _on_turn_changed(active_player_ref):
	var tm = get_node_or_null("%TurnManager")
	if tm == null: return
	_update_turn_banner(tm.is_my_turn())
	var i_am_p1 = (tm.get_my_team() == 1)

	# Zero the clock of the player whose turn just ENDED (the inactive side)
	if active_player_ref == tm.player_one:
		# p1 just became active → p2's turn ended → clear p2's side
		if i_am_p1:
			if top_left_round_time: top_left_round_time.text = "00:00"
		else:
			if top_right_round_time: top_right_round_time.text = "00:00"
	else:
		if i_am_p1:
			if top_right_round_time: top_right_round_time.text = "00:00"
		else:
			if top_left_round_time: top_left_round_time.text = "00:00"
