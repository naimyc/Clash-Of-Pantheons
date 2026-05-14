extends Node
class_name Stats

@onready var figure = $"../FigureBody/model";

func _ready():
	apply_type()

enum UnitType {
	BASILEUS,  # 👑 K
	THEOI,     # ✨ G
	MYTHOS,    # 🐉 M
	LAOS       # ⚔️ P
}

@export var unit_type: UnitType

@export var max_hp := 10
@export var hp := 10

@export var attack := 3
@export var defense := 1

@export var movement_range := 3



func apply_type():

	match unit_type:

		UnitType.BASILEUS:
			max_hp = 20
			hp = 20
			attack = 5
			defense = 3
			movement_range = 3
			figure.apply_skin("res://resources/skins/1.png")

		UnitType.THEOI:
			max_hp = 12
			hp = 12
			attack = 6
			defense = 2
			movement_range = 4
			figure.apply_skin("res://resources/skins/2.png")

		UnitType.MYTHOS:
			max_hp = 25
			hp = 25
			attack = 8
			defense = 4
			movement_range = 2

		UnitType.LAOS:
			max_hp = 6
			hp = 6
			attack = 2
			defense = 1
			movement_range = 3
			
func take_damage(amount: int):

	var real_damage = max(amount - defense, 1)

	hp -= real_damage

	return real_damage
