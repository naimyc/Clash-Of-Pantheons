# portrait_generator.gd — Einmal-Werkzeug: rendert fuer jede Einheit ein frontales
# Portraet aus dem vorhandenen Minecraft-Charaktermodell (model.gd/CharacterModel) und
# speichert es als PNG. Wird NICHT im laufenden Spiel verwendet, nur manuell ausgefuehrt.
extends Node3D

const OUTPUT_DIR := "res://resources/portraits/"
const ModelScene := preload("res://scenes/test/animated_model.tscn")
const ModelScript := preload("res://resources/models/model.gd")

const UNITS := {
	"Zeus": "res://resources/skins/1.png",
	"Knight": "res://resources/skins/2.png",
	"Hercules": "res://resources/skins/4.png",
	"Archer": "res://resources/skins/5.png",
	"Thanatos": "res://resources/skins/6.png",
	"Medusa": "res://resources/skins/7.png",
	"Apollo": "res://resources/skins/8.png",
}

@onready var _viewport: SubViewport = $SubViewport
@onready var _pivot: Node3D = $SubViewport/Pivot

var _queue: Array = []
var _current_model: Node3D = null


func _ready() -> void:
	print("[Portraits] _ready gestartet")
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_queue = UNITS.keys()
	_next()


func _next() -> void:
	if _queue.is_empty():
		print("[Portraits] Fertig.")
		get_tree().quit()
		return
	var unit_name: String = _queue.pop_front()
	_spawn_and_capture(unit_name)


func _spawn_and_capture(unit_name: String) -> void:
	if _current_model:
		_current_model.queue_free()
		_current_model = null

	print("[Portraits] Instanziiere Modell fuer ", unit_name)
	var model := ModelScene.instantiate()
	model.set_script(ModelScript)
	_pivot.add_child(model)
	_current_model = model
	print("[Portraits] Modell hinzugefuegt")

	# _ready() des Modells wartet selbst 1 Frame (Bogen-Setup) -> hier ebenfalls abwarten.
	await get_tree().process_frame
	print("[Portraits] Frame 1 ok")
	if model.has_method("apply_skin"):
		model.apply_skin(UNITS[unit_name])
	print("[Portraits] Skin angewendet")
	if model.has_method("play_idle"):
		model.play_idle()

	# Ein paar Frames warten, damit Skin/Animation/Skeleton sich stabilisieren, dann rendern.
	for i in 4:
		await get_tree().process_frame
	print("[Portraits] Frames abgewartet, rendere...")

	var img := _viewport.get_texture().get_image()
	print("[Portraits] Bild geholt, Groesse: ", img.get_size())
	img.save_png(OUTPUT_DIR + unit_name + ".png")
	print("[Portraits] Gespeichert: ", unit_name)

	_next()
