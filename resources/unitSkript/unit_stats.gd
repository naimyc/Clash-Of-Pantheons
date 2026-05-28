# unit_stats.gd (Ressource für die Figuren wie Zeus, Hercules, etc.)
extends Resource
class_name UnitStats

@export var unit_name: String
@export var hp: int
@export var atk: int
@export var move_range: int
@export var attack_range: int
@export var skill_name: String
@export var skill_damage: int
@export var unit_texture: Texture2D
@export var class_data: UnitClassData # Verweis auf die Kategorie
