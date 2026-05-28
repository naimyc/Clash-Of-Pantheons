# unit_class_data.gd (Ressource für die 4 Kategorien)
extends Resource
class_name UnitClassData

@export var typ_name: String # K, G, M oder P
@export var elixir_cost_move: int
@export var elixir_cost_atk: int
@export var elixir_cost_skill: int
@export var movement_type: String # "Orthogonal" oder "all"
