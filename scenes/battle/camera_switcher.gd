# camera_switcher.gd — schaltet zwischen Host- und Client-Kamera um, sobald der Zug
# wechselt (siehe turn_manager.gd -> turn_changed). Blendet dabei kurz auf Schwarz ab
# und wieder auf, damit der Seitenwechsel nicht abrupt/verwirrend wirkt.
# Waehrend der Animation ist is_transitioning() true — BattleRpc blockiert solange
# jede Spielereingabe, damit eine Runde erst beginnt, wenn die Kamera fertig ist.
extends Node

signal camera_ready

const FADE_DURATION := 0.28

@onready var _cam_host: Camera3D = $"../CameraHost"
@onready var _cam_client: Camera3D = $"../CameraClient"
@onready var _fade: ColorRect = $"../CameraFadeLayer/Fade"

var _active_team: int = 0
var _transitioning: bool = false


func _ready() -> void:
	await get_tree().process_frame
	var tm = get_node_or_null("%TurnManager")
	_active_team = tm.get_my_team() if tm else 0
	_show_camera_instant(_active_team)
	if tm:
		tm.turn_changed.connect(_on_turn_changed)


func is_transitioning() -> bool:
	return _transitioning


func _show_camera_instant(team: int) -> void:
	_cam_host.current = (team == 0)
	_cam_client.current = (team == 1)


func _on_turn_changed(_active_player) -> void:
	var tm = get_node_or_null("%TurnManager")
	if tm == null:
		return
	var new_team: int = tm.get_my_team()
	if new_team == _active_team:
		return
	_active_team = new_team
	_transition_to(new_team)


func _transition_to(team: int) -> void:
	_transitioning = true
	_fade.visible = true
	_fade.color.a = 0.0

	var tween_in := create_tween()
	tween_in.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	await tween_in.finished

	_show_camera_instant(team)

	var tween_out := create_tween()
	tween_out.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	await tween_out.finished

	_fade.visible = false
	_transitioning = false
	camera_ready.emit()
