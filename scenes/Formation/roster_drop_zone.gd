# roster_drop_zone.gd — an der Roster-Leiste angehaengt: ein Feld, das man hierher
# zurueckzieht, wird aus der Formation entfernt (zusaetzlich zum Rechtsklick auf das Feld).
extends HBoxContainer


func _can_drop_data(_pos: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("from_slot") != null


func _drop_data(_pos: Vector2, data) -> void:
	var from_slot = data.get("from_slot")
	if from_slot:
		from_slot.set_occupant("")
		from_slot.changed.emit()
