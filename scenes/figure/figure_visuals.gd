# figure_visuals.gd — attach to Figure node as child named "Visuals"
# Owns all tween effects: selection pop, attack pulse, damage flash, death.
extends Node

var figure: Figure

func _ready():
	figure = get_parent()

func play_selected(is_selected: bool):
	var tw = figure.create_tween().set_parallel(true)
	if is_selected:
		tw.tween_property(figure, "scale",      Vector3(1.2, 1.2, 1.2), 0.2).set_trans(Tween.TRANS_ELASTIC)
		tw.tween_property(figure, "position:y", 0.15,                   0.2).set_trans(Tween.TRANS_SINE)
	else:
		tw.tween_property(figure, "scale",      Vector3(1.0, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(figure, "position:y", 0.0,                    0.15).set_trans(Tween.TRANS_QUAD)

var _pulse_tween: Tween = null

func play_attack_pulse(active: bool):
	if _pulse_tween: _pulse_tween.kill(); _pulse_tween = null
	if active:
		_pulse_tween = figure.create_tween().set_loops()
		_pulse_tween.tween_property(figure, "scale", Vector3(1.1, 1.15, 1.1), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(figure, "scale", Vector3(1.0, 1.0,  1.0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		set_emissive(Color(1.0, 0.1, 0.1), 0.6)
	else:
		if not figure.is_currently_selected:
			figure.create_tween().tween_property(figure, "scale", Vector3(1,1,1), 0.15)
		set_emissive(Color.BLACK, 0.0)

func play_damage_flash(is_attack_target: bool):
	var tw = figure.create_tween().set_parallel(true)
	tw.tween_property(figure, "position:x", figure.position.x + 0.12, 0.05)
	tw.chain().tween_property(figure, "position:x", figure.position.x - 0.12, 0.05)
	tw.chain().tween_property(figure, "position:x", figure.position.x, 0.05)
	set_emissive(Color.WHITE, 2.0)
	get_tree().create_timer(0.15).timeout.connect(func():
		set_emissive(Color(1.0,0.1,0.1), 0.6) if is_attack_target else set_emissive(Color.BLACK, 0.0))

func play_death() -> Signal:
	var tw = figure.create_tween().set_parallel(true)
	tw.tween_property(figure, "scale",      Vector3(0,0,0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(figure, "position:y", -0.5,           0.4).set_trans(Tween.TRANS_QUAD)
	return tw.finished

func set_emissive(color: Color, energy: float):
	var body = figure.get_node_or_null("FigureBody")
	if not body: return
	for child in body.get_children():
		if not child is MeshInstance3D: continue
		for i in child.get_surface_override_material_count():
			var mat = child.get_surface_override_material(i)
			if mat == null: mat = child.mesh.surface_get_material(i)
			if not mat: continue
			var dup = mat.duplicate()
			dup.emission_enabled          = energy > 0.0
			dup.emission                  = color
			dup.emission_energy_multiplier = energy
			child.set_surface_override_material(i, dup)
# --- PETRIFIZIERUNG ---
var _petrify_tween: Tween = null
var _original_materials: Dictionary = {}
var _is_petrified_visual: bool = false

func play_petrify(active: bool) -> void:
	if _is_petrified_visual == active: return
	_is_petrified_visual = active

	if _petrify_tween: _petrify_tween.kill(); _petrify_tween = null

	var body = figure.get_node_or_null("FigureBody")
	if not body: return

	if active:
		_petrify_meshes(body)
		_petrify_tween = figure.create_tween()
		_petrify_tween.tween_property(figure, "scale", Vector3(0.95, 0.95, 0.95), 0.25)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		_unpetrify_meshes(body)
		_petrify_tween = figure.create_tween()
		_petrify_tween.tween_property(figure, "scale", Vector3(1.0, 1.0, 1.0), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _petrify_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh = child.mesh
			if mesh:
				for i in mesh.get_surface_count():
					var current = child.get_surface_override_material(i)
					if current == null:
						current = mesh.surface_get_material(i)
					if current == null: continue
					var key = str(child.get_instance_id()) + "_" + str(i)
					if not _original_materials.has(key):
						_original_materials[key] = current
					var stone = StandardMaterial3D.new()
					stone.albedo_color = Color(0.55, 0.55, 0.60)
					stone.roughness    = 0.9
					stone.emission_enabled           = true
					stone.emission                   = Color(0.30, 0.25, 0.45)
					stone.emission_energy_multiplier = 0.35
					stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					child.set_surface_override_material(i, stone)
		_petrify_meshes(child)

func _unpetrify_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh = child.mesh
			if mesh:
				for i in mesh.get_surface_count():
					var key = str(child.get_instance_id()) + "_" + str(i)
					if _original_materials.has(key):
						child.set_surface_override_material(i, _original_materials[key])
	_original_materials.clear()
