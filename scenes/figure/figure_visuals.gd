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
