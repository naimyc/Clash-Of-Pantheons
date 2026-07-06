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

@onready var _battle: BattleRpc = $"../GridManager/BattleRpc"

# Name labels — created in code if not already in the scene
var top_left_name_label:  Label = null
var top_right_name_label: Label = null

# Right skill panel — created in code
var _skill_panel:     PanelContainer = null
var _skill_name_lbl:  Label          = null
var _skill_desc_lbl:  Label          = null
var _skill_cost_lbl:  Label          = null
var _skill_btn:       Button         = null
var _skill_panel_fig: Figure         = null  # figure currently shown in panel

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
	_setup_skill_panel()

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

# ---------------------------------------------------------------------------
# RECHTE SKILL-LEISTE  (komplett per Code erstellt)
# ---------------------------------------------------------------------------
func _setup_skill_panel() -> void:
	_skill_panel = PanelContainer.new()
	_skill_panel.name    = "RightSkillPanel"
	_skill_panel.visible = false

	# Größe und Position werden in _process angepasst (Viewport-abhängig)
	_skill_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skill_panel.custom_minimum_size = Vector2(240, 0)

	var bg = StyleBoxFlat.new()
	bg.bg_color                   = Color(0.06, 0.03, 0.14, 0.93)
	bg.corner_radius_top_left     = 12
	bg.corner_radius_top_right    = 12
	bg.corner_radius_bottom_left  = 12
	bg.corner_radius_bottom_right = 12
	bg.border_width_left   = 2
	bg.border_width_right  = 2
	bg.border_width_top    = 2
	bg.border_width_bottom = 2
	bg.border_color = Color(0.55, 0.10, 0.95, 0.85)
	_skill_panel.add_theme_stylebox_override("panel", bg)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_skill_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# ── Skill-Name ──
	_skill_name_lbl = Label.new()
	_skill_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_name_lbl.add_theme_font_size_override("font_size", 18)
	_skill_name_lbl.add_theme_color_override("font_color", Color(0.88, 0.55, 1.0))
	vbox.add_child(_skill_name_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# ── Beschreibung ──
	_skill_desc_lbl = Label.new()
	_skill_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_desc_lbl.add_theme_font_size_override("font_size", 13)
	_skill_desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	vbox.add_child(_skill_desc_lbl)

	# ── Kosten ──
	_skill_cost_lbl = Label.new()
	_skill_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_cost_lbl.add_theme_font_size_override("font_size", 14)
	_skill_cost_lbl.add_theme_color_override("font_color", Color(0.40, 0.90, 1.00))
	vbox.add_child(_skill_cost_lbl)

	# ── Button ──
	_skill_btn = Button.new()
	_skill_btn.text = "✦ SKILL EINSETZEN"
	_skill_btn.add_theme_font_size_override("font_size", 14)
	_skill_btn.custom_minimum_size = Vector2(0, 40)
	_skill_btn.pressed.connect(_on_skill_button_pressed)
	vbox.add_child(_skill_btn)

	add_child(_skill_panel)
	# Initiale Position nach dem ersten Frame setzen (Viewport-Größe bekannt)
	# _skill_panel.call_deferred("_notification", NOTIFICATION_RESIZED)

func _on_skill_button_pressed():
	if _battle: _battle.toggle_skill_mode()

# Zeigt/aktualisiert das rechte Skill-Panel für die gewählte Figur.
func update_skill_panel(figure: Figure) -> void:
	_skill_panel_fig = figure
	if _skill_panel == null: return

	if figure == null or figure.stats == null or figure.stats.class_data == null \
			or figure.stats.skill_name == "" \
			or figure.stats.class_data.elixir_cost_skill <= 0:
		_skill_panel.visible = false
		return

	_skill_panel.visible = true
	_skill_name_lbl.text = "⚡  " + figure.stats.skill_name
	_skill_desc_lbl.text = _skill_description(figure.stats.skill_name)
	_skill_cost_lbl.text = "Kosten:  🔮 " + str(figure.stats.class_data.elixir_cost_skill)
	_refresh_skill_button()

# Passt den Button-Zustand an (Energie, bereits genutzt, Skill-Modus aktiv).
func _refresh_skill_button() -> void:
	if _skill_btn == null or _skill_panel_fig == null: return
	var fig  = _skill_panel_fig
	var tm   = get_node_or_null("%TurnManager")
	var cost = fig.stats.class_data.elixir_cost_skill if (fig.stats and fig.stats.class_data) else 99
	var is_my_turn   = tm != null and tm.is_my_turn()
	var enough_mana  = tm != null and tm.active_player.current_energy >= cost
	var skill_active = _battle != null and _battle.skill_mode

	if fig.has_used_skill_this_round:
		_skill_btn.text     = "✦ SKILL GENUTZT"
		_skill_btn.disabled = true
		_skill_btn.modulate = Color(0.45, 0.45, 0.45)
	elif skill_active:
		_skill_btn.text     = "✦ SKILL AKTIV …"
		_skill_btn.disabled = false
		_skill_btn.modulate = Color(0.90, 0.40, 1.00)
	elif not is_my_turn or not enough_mana or not fig.can_act():
		_skill_btn.text     = "✦ SKILL EINSETZEN"
		_skill_btn.disabled = true
		_skill_btn.modulate = Color(0.55, 0.55, 0.55)
	else:
		_skill_btn.text     = "✦ SKILL EINSETZEN"
		_skill_btn.disabled = false
		_skill_btn.modulate = Color(1.00, 1.00, 1.00)

# Wird von BattleRpc nach toggle_skill_mode aufgerufen.
func set_skill_mode_visual(_active: bool) -> void:
	_refresh_skill_button()

func _skill_description(skill_name: String) -> String:
	match skill_name:
		"petrification":
			return "Versteinert einen Gegner.\nDieser kann 1 Zug lang\nkeine Aktionen ausführen."
		_:
			return ""

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

	# Skill-Panel rechts mittig positionieren (Viewport-adaptiv)
	if _skill_panel and _skill_panel.visible:
		var vp   = get_viewport()
		var vsz  = vp.get_visible_rect().size if vp else Vector2(1280, 720)
		var pw   = max(240.0, vsz.x * 0.17)   # 17 % der Breite, min 240 px
		var ph   = _skill_panel.size.y
		_skill_panel.size    = Vector2(pw, ph)
		_skill_panel.position = Vector2(vsz.x - pw - 14, (vsz.y - ph) * 0.5)

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func format_time(s: float) -> String:
	var t = max(0, int(s))
	return "%02d:%02d" % [t / 60, t % 60]

func display_figure_stats(figure: Figure):
	if figure == null or figure.stats == null:
		if left_stats_panel: left_stats_panel.visible = false
		update_skill_panel(null)
		return

	if left_stats_panel: left_stats_panel.visible = true
	var s = figure.stats
	var c = s.class_data

	if unit_name_label: unit_name_label.text = s.unit_name
	if atk_label:       atk_label.text       = "ATK: " + str(s.atk)
	if hp_label:        hp_label.text        = "HP: %d / %d" % [figure.current_hp, s.hp]
	if def_label:       def_label.visible    = false

	# Statuseffekte anzeigen
	var status_label = left_stats_panel.get_node_or_null("VBoxContainer/StatusLabel")
	if status_label == null:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.add_theme_font_size_override("font_size", 13)
		status_label.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
		var vbox = left_stats_panel.get_node_or_null("VBoxContainer")
		if vbox:
			vbox.add_child(status_label)
			vbox.move_child(status_label, 1)  # direkt unter dem Namen
	if status_label:
		if figure.is_petrified:
			status_label.text    = "🪨  VERSTEINERT"
			status_label.visible = true
		else:
			status_label.visible = false

	var move_range_label = left_stats_panel.get_node_or_null("VBoxContainer/MoveRangeLabel")
	if move_range_label: move_range_label.text = "Bewegungs-Reichweite: " + str(s.move_range)

	var attack_range_label = left_stats_panel.get_node_or_null("VBoxContainer/atkRangeLabel")
	if attack_range_label: attack_range_label.text = "Angriffs-Reichweite: " + str(s.attack_range)

	if c:
		var type_name_label = left_stats_panel.get_node_or_null("VBoxContainer/TypeNameLabel")
		if type_name_label: type_name_label.text = "Kategorie: " + str(c.typ_name)

		if move_cost_label:   move_cost_label.text   = "Kosten Bewegung: " + str(c.elixir_cost_move)
		if attack_cost_label: attack_cost_label.text = "Kosten Angriff: "  + str(c.elixir_cost_atk)

		# Skill-Info im linken Panel ausblenden (übernimmt rechtes Panel)
		var skill_container = left_stats_panel.get_node_or_null("VBoxContainer/SkillContainer")
		if skill_container: skill_container.visible = false
		if skill_cost_label: skill_cost_label.visible = false

	# Rechtes Skill-Panel aktualisieren
	update_skill_panel(figure)

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
	_refresh_skill_button()

func _on_turn_changed(active_player_ref):
	var tm = get_node_or_null("%TurnManager")
	if tm == null: return
	_update_turn_banner(tm.is_my_turn())
	# Bei Rundenwechsel Skill-Panel zurücksetzen
	if _battle and _battle.skill_mode:
		_battle.skill_mode = false
	update_skill_panel(null)
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
