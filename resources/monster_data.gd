class_name MonsterData
extends Resource

@export var monster_name: String = ""
@export var starting_space_id: int = 0
@export var frenzy_number: int = 1
@export var dial_max: int = 0
@export var can_move_through_water: bool = false
var current_space_id: int = 0
var dial_value: int = 0
var task_complete: bool = false
