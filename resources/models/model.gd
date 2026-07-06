extends Node3D
class_name CharacterModel

# --- ANIMATION NAMEN ---
const ANIM_IDLE:        String = "Idle02"
const ANIM_BOW:         String = "Bow"
const ANIM_FIGHT_LEFT:  String = "FightLeft"
const ANIM_FIGHT_RIGHT: String = "FightRight"
const ANIM_DEATH:       String = "Death"

# --- BOW TIMING (35-Frame Animation @ 60 FPS) ---
const BOW_DRAW_END:       float = 0.685
const BOW_RELEASE_TIMING: float = 1.0
const MELEE_HIT_TIMING:   float = 0.4
const BOW_LINGER_TIME:    float = 0.20

# --- Petrify Timing (15% langsamer für sichtbareren Übergang) ---
const PETRIFY_WAVE_DURATION: float = 2.0  # war 0.70
const PETRIFY_FIGURE_HEIGHT: float = 1.80
const PETRIFY_ANIM_SLOWDOWN: float = 1.0 # war 0.55

# --- Petrify Farben ---
const PETRIFY_ALBEDO:   Color = Color(0.52, 0.52, 0.58)
const PETRIFY_EMISSION: Color = Color(0.15, 0.20, 0.35)   # kaltes Blau-Grau Glow

const SKIP_SKIN_MESHES = ["Bow", "Arrow 3D", "Arrow3D", "Arrow"]
const BOW_TEST_MODE: bool = false

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal attack_hit_frame
signal death_finished
signal skill_hit_frame

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
@onready var animation_player: AnimationPlayer = find_animation_player(self)

var _arrow_template: MeshInstance3D = null
var _bow_mesh:       MeshInstance3D = null
var _proc_bow:       ProceduralBow = null
var _bow_attachment: BoneAttachment3D = null
var _is_ranged:      bool = false

# Petrify State (persistent!)
var _is_petrified_visual: bool = false
var _petrify_wave_node: Node3D = null      # Der wandernde Stein-Ring
var _petrify_tween: Tween = null
var _petrify_material_backup: Array = []   # [{material, orig_albedo, orig_emission_enabled, orig_emission, orig_mult}]

# ---------------------------------------------------------------------------
func _ready() -> void:
	_arrow_template = _find_mesh_by_name(self, ["Arrow 3D", "Arrow3D", "Arrow"])
	_bow_mesh       = _find_mesh_by_name(self, ["Bow"])
	if _arrow_template: _arrow_template.visible = false
	if _bow_mesh:       _bow_mesh.visible = false

	_setup_animation(ANIM_IDLE, Animation.LOOP_LINEAR)
	_setup_procedural_bow()

func set_ranged(value: bool) -> void:
	_is_ranged = value
	if _bow_mesh: _bow_mesh.visible = false

# ---------------------------------------------------------------------------
# ANIMATION API
# ---------------------------------------------------------------------------
func play_idle() -> void:
	if animation_player and animation_player.has_animation(ANIM_IDLE):
		animation_player.play(ANIM_IDLE)

func play_attack(is_ranged: bool, target_world_pos: Vector3) -> void:
	if _is_petrified_visual:
		attack_hit_frame.emit()
		return
	if animation_player == null:
		attack_hit_frame.emit()
		return

	var anim_name: String
	if is_ranged:
		anim_name = ANIM_BOW
	else:
		anim_name = _pick_melee_side(target_world_pos)

	if not animation_player.has_animation(anim_name):
		attack_hit_frame.emit()
		return

	var anim: Animation = animation_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_NONE
	animation_player.play(anim_name)

	var length = anim.length

	if is_ranged:
		_show_bow()
		if _proc_bow:
			_proc_bow.play_draw_and_release(length, BOW_DRAW_END, BOW_RELEASE_TIMING)
		get_tree().create_timer(length * BOW_RELEASE_TIMING).timeout.connect(
			func(): _fire_arrow(target_world_pos))
		get_tree().create_timer(length + BOW_LINGER_TIME).timeout.connect(
			func():
				_hide_bow()
				play_idle())
	else:
		get_tree().create_timer(length * MELEE_HIT_TIMING).timeout.connect(
			func(): attack_hit_frame.emit())
		get_tree().create_timer(length + 0.05).timeout.connect(
			func(): play_idle())

func play_death() -> void:
	# Wenn petrifiziert: erst aufheben damit Animation wieder abläuft
	if _is_petrified_visual:
		_reset_petrify_state_immediate()

	if animation_player == null or not animation_player.has_animation(ANIM_DEATH):
		get_tree().create_timer(0.3).timeout.connect(func(): death_finished.emit())
		return
	var anim: Animation = animation_player.get_animation(ANIM_DEATH)
	anim.loop_mode = Animation.LOOP_NONE
	animation_player.play(ANIM_DEATH)
	get_tree().create_timer(anim.length).timeout.connect(
		func(): death_finished.emit())

# ---------------------------------------------------------------------------
# SKILL CAST — Medusa castet Versteinerung
# (Keine Body-Animation — Idle bleibt aktiv, nur der Strahl fliegt)
# ---------------------------------------------------------------------------
func play_skill(target_world_pos: Vector3) -> void:
	# Lila-magischer Emission-Puls am Caster (Medusa-Vibe)
	_flash_caster_glow(Color(0.35, 0.55, 1.0), 0.69)

	# Strahl sofort abfeuern — kein Warten auf Body-Animation
	_fire_petrify_beam(target_world_pos)

# Sichtbarer Strahl vom Caster zum Ziel — signalisiert Hit erst am Ziel
func _fire_petrify_beam(target_world_pos: Vector3) -> void:
	var start = global_position + Vector3(0, 1.3, 0)   # ~Kopfhöhe des Casters
	var end   = target_world_pos + Vector3(0, 1.0, 0)  # ~Brusthöhe des Ziels
	var beam_time: float = 0.4025

	# --- 1. Ladeball am Caster ---
	var charge = _make_glow_sphere(Color(0.35, 0.55, 1.0), 0.35)
	get_tree().current_scene.add_child(charge)
	charge.global_position = start
	charge.scale = Vector3(0.2, 0.2, 0.2)

	var charge_tw = charge.create_tween()
	charge_tw.tween_property(charge, "scale", Vector3(1.0, 1.0, 1.0), 0.138)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	charge_tw.tween_callback(func(): if is_instance_valid(charge): charge.queue_free())

	# --- 2. Haupt-Strahl (dicker Kern) ---
	var core_albedo = Color(PETRIFY_ALBEDO.r, PETRIFY_ALBEDO.g, PETRIFY_ALBEDO.b, 0.90)
	var core_emission = Color(0.35, 0.55, 1.0)
	_spawn_beam_segment(start, end, beam_time,
		core_albedo, core_emission, 0.08, 4.5, 0.0)

	# --- 3. Neben-Strahlen — 4 dünnere die verstreut drumherum tanzen ---
	var side_beam_count = 4
	for i in side_beam_count:
		var angle = (float(i) / side_beam_count) * TAU + randf() * 0.8
		var radius = 0.10 + randf() * 0.12    # Streuung 0.10–0.22 units um den Kern
		_spawn_scattered_side_beam(start, end, beam_time, angle, radius, i * 0.015)

	# --- 4. Funken die aus dem Strahl rausspringen ---
	for i in 8:
		_spawn_scatter_spark(start, end, beam_time)

	# --- 5. Impact-Flash am Ziel ---
	get_tree().create_timer(beam_time * 0.5).timeout.connect(func():
		_spawn_impact_flash(end))

	# --- 6. Hit-Frame ---
	get_tree().create_timer(beam_time * 0.5).timeout.connect(func():
		skill_hit_frame.emit())

# Ein einzelnes Strahl-Segment zwischen zwei Punkten
func _spawn_beam_segment(start: Vector3, end: Vector3, beam_time: float,
		albedo: Color, emission: Color, thickness: float, energy: float, start_delay: float) -> void:
	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = thickness
	cyl.bottom_radius = thickness
	cyl.height = start.distance_to(end)
	cyl.radial_segments = 12
	beam.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = mat

	get_tree().current_scene.add_child(beam)
	beam.global_position = (start + end) * 0.5
	var dir = (end - start).normalized()
	if dir.length() > 0.001:
		var up = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		beam.look_at(end, up)
		beam.rotate_object_local(Vector3.RIGHT, PI / 2)

	beam.scale = Vector3(1.0, 0.0, 1.0)

	var tw = beam.create_tween()
	tw.set_parallel(true)
	# Delay über den Property-Delay einbauen (funktioniert mit parallel tween)
	tw.tween_property(beam, "scale:y", 1.0, beam_time * 0.5)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)\
		.set_delay(start_delay)
	tw.tween_property(beam, "scale:x", 1.6, beam_time * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\
		.set_delay(start_delay + beam_time * 0.5)
	tw.tween_property(beam, "scale:z", 1.6, beam_time * 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\
		.set_delay(start_delay + beam_time * 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, beam_time * 0.4)\
		.set_delay(start_delay + beam_time * 0.5)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, beam_time * 0.4)\
		.set_delay(start_delay + beam_time * 0.5)

	# Cleanup nach allem
	get_tree().create_timer(start_delay + beam_time * 0.95).timeout.connect(func():
		if is_instance_valid(beam): beam.queue_free())

# Ein versetzter Neben-Strahl der neben dem Kern liegt
func _spawn_scattered_side_beam(start: Vector3, end: Vector3, beam_time: float,
		angle: float, radius: float, delay: float) -> void:
	var dir = (end - start).normalized()
	var arbitrary = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var perp1 = dir.cross(arbitrary).normalized()
	var perp2 = dir.cross(perp1).normalized()

	# Offset im Kreis um die Hauptachse
	var offset = perp1 * cos(angle) * radius + perp2 * sin(angle) * radius

	# Start näher am Kern, Ende weiter außen — Aufsplittern zum Ziel hin
	var side_start = start + offset * 0.3
	var side_end   = end   + offset * 1.4

	_spawn_beam_segment(side_start, side_end, beam_time * 0.85,
		Color(0.65, 0.80, 1.0, 0.55), Color(0.5, 0.7, 1.0),
		0.025, 3.0, delay)

# Kleiner Funken der aus dem Strahl rausspringt und dann fadet
func _spawn_scatter_spark(start: Vector3, end: Vector3, beam_time: float) -> void:
	var t_on_beam = randf_range(0.15, 0.85)
	var spawn_pos = start.lerp(end, t_on_beam)

	var dir = (end - start).normalized()
	var arbitrary = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var perp1 = dir.cross(arbitrary).normalized()
	var perp2 = dir.cross(perp1).normalized()
	var random_angle = randf() * TAU
	var out_dir = perp1 * cos(random_angle) + perp2 * sin(random_angle)

	var spark = _make_glow_sphere(Color(0.75, 0.85, 1.0), 0.04)
	get_tree().current_scene.add_child(spark)
	spark.global_position = spawn_pos

	var travel_dist = randf_range(0.3, 0.7)
	var final_pos = spawn_pos + out_dir * travel_dist + Vector3(0, randf_range(-0.15, 0.15), 0)
	var life = randf_range(0.25, 0.45)
	var start_delay = randf_range(0.0, beam_time * 0.4)

	var mat = spark.material_override as StandardMaterial3D
	var tw = spark.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spark, "global_position", final_pos, life)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)\
		.set_delay(start_delay)
	if mat:
		tw.tween_property(mat, "albedo_color:a", 0.0, life)\
			.set_delay(start_delay)
		tw.tween_property(mat, "emission_energy_multiplier", 0.0, life)\
			.set_delay(start_delay)

	get_tree().create_timer(start_delay + life + 0.05).timeout.connect(func():
		if is_instance_valid(spark): spark.queue_free())

func _make_glow_sphere(color: Color, radius: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	mi.mesh = sph
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

func _spawn_impact_flash(world_pos: Vector3) -> void:
	var flash = _make_glow_sphere(Color(0.5, 0.70, 1.0), 0.5)
	get_tree().current_scene.add_child(flash)
	flash.global_position = world_pos
	flash.scale = Vector3(0.3, 0.3, 0.3)

	var tw = flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.253)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var mat = flash.material_override as StandardMaterial3D
	if mat:
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.253)
		tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.253)
	tw.chain().tween_callback(func():
		if is_instance_valid(flash): flash.queue_free())

# ---------------------------------------------------------------------------
# PETRIFY — Das Ziel wird zu Stein (skript-basierte Animation!)
# ---------------------------------------------------------------------------
func set_petrified(value: bool) -> void:
	if _is_petrified_visual == value:
		return
	_is_petrified_visual = value

	# Vorherigen Tween abbrechen falls einer läuft
	if _petrify_tween and _petrify_tween.is_valid():
		_petrify_tween.kill()

	if value:
		_start_petrify_wave()
	else:
		_start_unpetrify_wave()

# Sichtbare Steinwelle die von unten nach oben wandert
func _start_petrify_wave() -> void:
	# 1. Material-Backup anlegen (nur wenn noch nicht vorhanden)
	if _petrify_material_backup.is_empty():
		_backup_materials()

	# 2. Steinring erzeugen und positionieren
	_spawn_petrify_wave_ring()

	# 3. Kombinierte Animation: Ring wandert hoch + Farbe wird graduell Stein + Anim verlangsamt
	_petrify_tween = create_tween()
	_petrify_tween.set_parallel(true)

	# 3a. Ring von Boden nach Kopf-Höhe wandern
	if _petrify_wave_node:
		_petrify_tween.tween_property(
			_petrify_wave_node, "position:y",
			PETRIFY_FIGURE_HEIGHT, PETRIFY_WAVE_DURATION
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 3b. Materialien zu Stein tweenen
	_petrify_tween.tween_method(
		_apply_petrify_tint_blend,
		0.0, 1.0, PETRIFY_WAVE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3c. Animation verlangsamen bis Stopp
	if animation_player:
		_petrify_tween.tween_method(
			_set_anim_speed,
			1.0, 0.0, PETRIFY_ANIM_SLOWDOWN
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# 3d. Nach Welle: Ring in "Poof" auflösen
	_petrify_tween.chain().tween_callback(_end_petrify_wave)

# Umgekehrte Steinwelle: von oben nach unten
func _start_unpetrify_wave() -> void:
	_spawn_petrify_wave_ring(true)   # Start oben

	_petrify_tween = create_tween()
	_petrify_tween.set_parallel(true)

	# Ring wandert nach unten
	if _petrify_wave_node:
		_petrify_tween.tween_property(
			_petrify_wave_node, "position:y",
			0.0, PETRIFY_WAVE_DURATION
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Materialien wieder auf Original blenden
	_petrify_tween.tween_method(
		_apply_petrify_tint_blend,
		1.0, 0.0, PETRIFY_WAVE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Animation wieder starten (Speed hoch)
	if animation_player:
		# Animation muss laufen bevor speed_scale wirkt
		if not animation_player.is_playing():
			play_idle()
		_petrify_tween.tween_method(
			_set_anim_speed,
			0.0, 1.0, PETRIFY_ANIM_SLOWDOWN
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Nach Welle: aufräumen
	_petrify_tween.chain().tween_callback(_end_unpetrify_wave)

# Sofortiges Zurücksetzen (z.B. beim Tod einer petrifizierten Figur)
func _reset_petrify_state_immediate() -> void:
	_is_petrified_visual = false
	if _petrify_tween and _petrify_tween.is_valid():
		_petrify_tween.kill()
	if _petrify_wave_node and is_instance_valid(_petrify_wave_node):
		_petrify_wave_node.queue_free()
		_petrify_wave_node = null
	_apply_petrify_tint_blend(0.0)
	_restore_materials_from_backup()
	_set_anim_speed(1.0)

# ---------------------------------------------------------------------------
# PETRIFY HELPERS
# ---------------------------------------------------------------------------
func _spawn_petrify_wave_ring(start_at_top: bool = false) -> void:
	if _petrify_wave_node and is_instance_valid(_petrify_wave_node):
		_petrify_wave_node.queue_free()

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.55
	torus.rings = 24
	torus.ring_segments = 10
	ring.mesh = torus

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.55, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat

	add_child(ring)
	ring.position = Vector3(0, PETRIFY_FIGURE_HEIGHT if start_at_top else 0.0, 0)
	_petrify_wave_node = ring

	# Ring spinnt permanent während Welle läuft
	var spin_tw = ring.create_tween().set_loops()
	spin_tw.tween_property(ring, "rotation_degrees:y", 360.0, 0.8)\
		.set_trans(Tween.TRANS_LINEAR)

func _end_petrify_wave() -> void:
	if _petrify_wave_node == null or not is_instance_valid(_petrify_wave_node):
		return
	# Poof-Effekt: Ring expandiert und wird transparent
	var ring = _petrify_wave_node
	var tw = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.2, 2.2, 2.2), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var mat = ring.material_override as StandardMaterial3D
	if mat:
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.25)
	tw.chain().tween_callback(func():
		if is_instance_valid(ring): ring.queue_free()
		if _petrify_wave_node == ring: _petrify_wave_node = null)

func _end_unpetrify_wave() -> void:
	if _petrify_wave_node and is_instance_valid(_petrify_wave_node):
		_petrify_wave_node.queue_free()
		_petrify_wave_node = null
	_restore_materials_from_backup()
	# Animation garantiert wieder auf normale Speed
	_set_anim_speed(1.0)
	if animation_player and not animation_player.is_playing():
		play_idle()

# Blend-Wert 0.0 = original, 1.0 = komplett Stein
func _apply_petrify_tint_blend(t: float) -> void:
	for entry in _petrify_material_backup:
		var mat = entry.material as StandardMaterial3D
		if mat == null: continue
		mat.albedo_color = entry.orig_albedo.lerp(PETRIFY_ALBEDO, t)
		if t > 0.02:
			mat.emission_enabled = true
			var emission_target = PETRIFY_EMISSION
			mat.emission = entry.orig_emission.lerp(emission_target, t)
			mat.emission_energy_multiplier = lerp(entry.orig_mult, 0.6, t)
		else:
			mat.emission_enabled = entry.orig_emission_enabled
			mat.emission = entry.orig_emission
			mat.emission_energy_multiplier = entry.orig_mult

func _set_anim_speed(speed: float) -> void:
	if animation_player:
		animation_player.speed_scale = speed
		# Speed 0 = quasi paused
		if speed <= 0.001 and animation_player.is_playing():
			animation_player.pause()
		elif speed > 0.001 and not animation_player.is_playing():
			animation_player.play()

func _backup_materials() -> void:
	_petrify_material_backup.clear()
	var skeleton = find_skeleton(self)
	if skeleton == null: return
	_collect_body_materials_backup(skeleton)

func _collect_body_materials_backup(node: Node) -> void:
	for child in node.get_children():
		if child.name in SKIP_SKIN_MESHES: continue
		if child is MeshInstance3D:
			var mat = child.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				_petrify_material_backup.append({
					"material": mat,
					"orig_albedo": mat.albedo_color,
					"orig_emission_enabled": mat.emission_enabled,
					"orig_emission": mat.emission,
					"orig_mult": mat.emission_energy_multiplier,
				})
		_collect_body_materials_backup(child)

func _restore_materials_from_backup() -> void:
	for entry in _petrify_material_backup:
		var mat = entry.material as StandardMaterial3D
		if mat == null: continue
		mat.albedo_color = entry.orig_albedo
		mat.emission_enabled = entry.orig_emission_enabled
		mat.emission = entry.orig_emission
		mat.emission_energy_multiplier = entry.orig_mult
	_petrify_material_backup.clear()

# Grüner Emission-Puls am Caster
func _flash_caster_glow(color: Color, duration: float) -> void:
	var skeleton = find_skeleton(self)
	if skeleton == null: return
	var affected_mats: Array = []
	_collect_body_materials_flat(skeleton, affected_mats)
	for mat in affected_mats:
		if not mat is StandardMaterial3D: continue
		var orig_enabled = mat.emission_enabled
		var orig_emission = mat.emission
		var orig_mult = mat.emission_energy_multiplier
		mat.emission_enabled = true
		var tw = create_tween()
		tw.tween_property(mat, "emission", color, duration * 0.4)
		tw.tween_property(mat, "emission_energy_multiplier", 1.8, duration * 0.4)
		tw.tween_property(mat, "emission", orig_emission, duration * 0.6)
		tw.tween_property(mat, "emission_energy_multiplier", orig_mult, duration * 0.6)
		tw.tween_callback(func(): mat.emission_enabled = orig_enabled)

func _collect_body_materials_flat(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child.name in SKIP_SKIN_MESHES: continue
		if child is MeshInstance3D:
			var m = child.get_surface_override_material(0)
			if m: out.append(m)
		_collect_body_materials_flat(child, out)

# ---------------------------------------------------------------------------
# MELEE / RANGED HELPERS
# ---------------------------------------------------------------------------
func _pick_melee_side(target_world_pos: Vector3) -> String:
	var forward = -global_transform.basis.z
	var to_target = target_world_pos - global_position
	var side = forward.cross(to_target.normalized()).y
	if side > 0.0:
		return ANIM_FIGHT_LEFT if animation_player.has_animation(ANIM_FIGHT_LEFT) else ANIM_FIGHT_RIGHT
	else:
		return ANIM_FIGHT_RIGHT if animation_player.has_animation(ANIM_FIGHT_RIGHT) else ANIM_FIGHT_LEFT

func _fire_arrow(target_world_pos: Vector3) -> void:
	if _arrow_template == null:
		attack_hit_frame.emit()
		return
	var arrow: MeshInstance3D = _arrow_template.duplicate()
	arrow.visible = true
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = _arrow_template.global_position
	arrow.look_at(target_world_pos + Vector3(0, 0.4, 0), Vector3.UP)

	var distance = arrow.global_position.distance_to(target_world_pos)
	var flight_time = clamp(distance / 12.0, 0.2, 0.5)

	var tw = arrow.create_tween()
	tw.tween_property(arrow, "global_position",
		target_world_pos + Vector3(0, 0.4, 0), flight_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		attack_hit_frame.emit()
		arrow.queue_free())

# ---------------------------------------------------------------------------
# SETUP / DISCOVERY
# ---------------------------------------------------------------------------
func _setup_animation(anim_name: String, loop_mode: int) -> void:
	if animation_player == null: return
	var anim := animation_player.get_animation(anim_name)
	if anim == null: return
	anim.loop_mode = loop_mode
	animation_player.play(anim_name)

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var r := find_animation_player(child)
		if r: return r
	return null

func _find_mesh_by_name(node: Node, names: Array) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D and child.name in names:
			return child
		var r = _find_mesh_by_name(child, names)
		if r: return r
	return null

# ---------------------------------------------------------------------------
# PROCEDURAL BOW
# ---------------------------------------------------------------------------
func _setup_procedural_bow() -> void:
	await get_tree().process_frame
	var skeleton = find_skeleton(self)
	if skeleton == null: return

	var bone_idx = _find_hand_bone(skeleton)
	if bone_idx < 0:
		_proc_bow = ProceduralBow.new()
		_proc_bow.position = Vector3(0.3, 0.5, 0)
		_proc_bow.scale = Vector3.ZERO
		_proc_bow.visible = false
		skeleton.get_parent().add_child(_proc_bow)
		return

	_bow_attachment = BoneAttachment3D.new()
	_bow_attachment.name = "BowAttachment"
	_bow_attachment.bone_name = skeleton.get_bone_name(bone_idx)
	skeleton.add_child(_bow_attachment)
	_bow_attachment.bone_idx = bone_idx

	_proc_bow = ProceduralBow.new()
	_proc_bow.name = "ProceduralBow"
	_proc_bow.position = Vector3(0.05, 0.0, 0.0)
	_proc_bow.rotation_degrees = Vector3(0, 90, 0)
	if BOW_TEST_MODE:
		_proc_bow.scale = Vector3.ONE
		_proc_bow.visible = true
	else:
		_proc_bow.scale = Vector3.ZERO
		_proc_bow.visible = false
	_bow_attachment.add_child(_proc_bow)

func _find_hand_bone(skeleton: Skeleton3D) -> int:
	var candidates = ["Hand_Right", "Right_Hand", "RightHand",
		"Arm_Right_Lower", "Arm_Right", "Right_Arm", "Arm_Rig", "arm_right"]
	for name in candidates:
		var idx = skeleton.find_bone(name)
		if idx >= 0: return idx
	for i in skeleton.get_bone_count():
		var n = skeleton.get_bone_name(i).to_lower()
		if "right" in n or "rig" in n: return i
	return -1

func _show_bow() -> void:
	if _proc_bow == null: return
	_proc_bow.set_draw(0.0)
	_proc_bow.visible = true
	var tw = create_tween()
	tw.tween_property(_proc_bow, "scale", Vector3.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_bow() -> void:
	if _proc_bow == null or BOW_TEST_MODE: return
	var tw = create_tween()
	tw.tween_property(_proc_bow, "scale", Vector3.ZERO, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_proc_bow.visible = false
		_proc_bow.set_draw(0.0))

# ---------------------------------------------------------------------------
# SKIN
# ---------------------------------------------------------------------------
func apply_skin(texture_data) -> void:
	var tex: Texture2D = null
	if texture_data is String:
		tex = load(texture_data) as Texture2D
	elif texture_data is Texture2D:
		tex = texture_data
	if tex == null: return
	var skeleton := find_skeleton(self)
	_apply_materials(skeleton if skeleton else self, tex)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var r := find_skeleton(child)
		if r: return r
	return null

func _apply_materials(node: Node, tex: Texture2D) -> void:
	for child in node.get_children():
		if child.name in SKIP_SKIN_MESHES:
			continue
		if child is MeshInstance3D:
			var mesh: Mesh = child.mesh
			if mesh:
				var existing := child.get_surface_override_material(0) as StandardMaterial3D
				var mat: StandardMaterial3D
				if existing:
					mat = existing.duplicate()
				elif mesh.surface_get_material(0):
					mat = mesh.surface_get_material(0).duplicate() as StandardMaterial3D
				else:
					mat = StandardMaterial3D.new()
				mat.albedo_texture = tex
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
				child.set_surface_override_material(0, mat)
		_apply_materials(child, tex)
